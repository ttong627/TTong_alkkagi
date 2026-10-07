import 'dart:math' as math;
import 'dart:ui';

import 'package:alkkagi_physics/alkkagi_physics.dart';

import 'match.dart';

/// 손가락 위치 한 점(화면 좌표, 초).
class FlickSample {
  const FlickSample(this.pos, this.t);
  final Offset pos;
  final double t;
}

/// 가까이 보기 화면에 그린 입체 돌의 모양(화면 좌표).
///
/// 뒤쪽 비스듬한 위에서 본 돌: 윗면 타원 + 옆면 두께 + 아랫면 타원.
/// 구형 돌은 두께 없이 둥근 원으로 본다.
class StoneFace {
  const StoneFace({
    required this.center,
    required this.rx,
    required this.ry,
    required this.thickness,
  });

  /// 모양별 비율로 만든다. [radius] 는 화면에서 돌 반지름.
  factory StoneFace.of(StoneShape shape, Offset center, double radius) {
    final (ryk, tk) = switch (shape) {
      StoneShape.flat => (0.42, 0.20),
      StoneShape.round => (0.48, 0.34),
      StoneShape.sphere => (1.0, 0.0),
    };
    // 두께 절반만큼 올려 그려 전체가 [center] 중심에 오게 한다.
    final thickness = radius * tk;
    return StoneFace(
      center: center.translate(0, -thickness / 2),
      rx: radius,
      ry: radius * ryk,
      thickness: thickness,
    );
  }

  /// 윗면 타원 중심.
  final Offset center;
  final double rx;
  final double ry;

  /// 옆면 두께(화면 길이).
  final double thickness;

  /// 돌 실루엣 맨 위·맨 아래(화면 y).
  double get top => center.dy - ry;
  double get bottom => center.dy + thickness + ry;

  bool _inEllipse(Offset p, Offset c) {
    final dx = (p.dx - c.dx) / rx, dy = (p.dy - c.dy) / ry;
    return dx * dx + dy * dy <= 1;
  }

  /// 손가락이 돌에 닿았는가(실루엣 안).
  bool contains(Offset p) =>
      _inEllipse(p, center) ||
      _inEllipse(p, center.translate(0, thickness)) ||
      ((p.dx - center.dx).abs() <= rx &&
          p.dy >= center.dy &&
          p.dy <= center.dy + thickness);

  /// 닿은 높이 → 타격점. 맨 위 +1(상·밀어치기) ~ 가운데 0(중) ~ 맨 아래 −1(하·끌어치기).
  double hitAt(Offset p) =>
      (1 - 2 * (p.dy - top) / (bottom - top)).clamp(-1.0, 1.0);
}

/// 튕기기가 쏘기로 이어지지 못한 까닭.
enum FlickMiss {
  /// 손가락이 돌에 닿지 않았다.
  missed('돌을 손끝으로 맞혀 튕기세요'),

  /// 너무 느렸다.
  tooWeak('조금 더 빠르게 튕기세요');

  const FlickMiss(this.hint);
  final String hint;
}

/// 튕기기를 읽은 결과.
class FlickShot {
  const FlickShot({
    required this.angle,
    required this.speed,
    required this.hit,
    required this.power,
    required this.contact,
  });

  /// 판 위 방향(라디안). 화면 위쪽 = 판 위쪽.
  final double angle;

  /// 처음 속도(cm/s).
  final double speed;

  /// 타격점 −1~+1.
  final double hit;

  /// 내공(세기) 0~1.
  final double power;

  /// 처음 닿은 점(화면 좌표).
  final Offset contact;
}

/// 튕기기 → 세기 환산 기준(논리 화소/초). 실기기 손맛을 보며 조정한다.
abstract final class FlickTuning {
  /// 이보다 느리면 쏘지 않는다.
  static const double minPxPerSec = 300;

  /// 이 빠르기면 내공 100%.
  static const double fullPxPerSec = 3200;

  /// 내공 0% 일 때도 나가는 최소 속도(cm/s).
  static const double minShotSpeed = 12;

  /// 손 뗄 때 빠르기를 잴 구간(초).
  static const double releaseWindow = 0.08;

  /// 마지막 움직임 뒤 이만큼 멈췄다가 떼면 튕긴 것이 아니라 멈춘 것으로 본다(초).
  static const double stopGap = 0.1;
}

/// 지금까지의 손가락 움직임에서 방향과 빠르기(화소/초)를 잰다.
/// 마지막 [FlickTuning.releaseWindow] 초 동안의 움직임을 쓴다.
(Offset velocity, double pxPerSec)? flickVelocity(List<FlickSample> s) {
  if (s.length < 2) return null;
  final last = s.last;
  // 바로 앞 점은 늘 쓰고, 그보다 앞 점은 구간 안에 들 때만 쓴다.
  var i = s.length - 2;
  while (i > 0 && last.t - s[i - 1].t <= FlickTuning.releaseWindow + 1e-9) {
    i--;
  }
  final dt = last.t - s[i].t;
  if (dt <= 0) return null;
  final v = (last.pos - s[i].pos) / dt;
  return (v, v.distance);
}

/// 빠르기(화소/초) → 내공 0~1.
double flickPower(double pxPerSec) =>
    ((pxPerSec - FlickTuning.minPxPerSec) /
            (FlickTuning.fullPxPerSec - FlickTuning.minPxPerSec))
        .clamp(0.0, 1.0);

/// 내공 0~1 → 처음 속도(cm/s).
double powerToSpeed(double power) =>
    FlickTuning.minShotSpeed +
    (baseMaxSpeed - FlickTuning.minShotSpeed) * power;

/// 손가락 길이 [s] 에서 돌에 처음 닿은 점. 점 사이가 멀면 선을 잘게 나눠 본다.
Offset? firstContact(List<FlickSample> s, StoneFace face) {
  for (var i = 0; i < s.length; i++) {
    if (i > 0) {
      final a = s[i - 1].pos, b = s[i].pos;
      final steps = math.max(1, ((b - a).distance / 4).ceil());
      for (var k = 1; k < steps; k++) {
        final p = Offset.lerp(a, b, k / steps)!;
        if (face.contains(p)) return p;
      }
    }
    if (face.contains(s[i].pos)) return s[i].pos;
  }
  return null;
}

/// 손을 뗀 뒤 튕기기 전체를 읽는다. 쏠 수 있으면 [FlickShot], 아니면 [FlickMiss].
///
/// [s] 는 손가락이 **움직인** 점들(누른 점 + 움직인 점, 시각은 이벤트가 일어난 시각).
/// [releaseAt] 은 손을 뗀 시각. 마지막 움직임 뒤 [FlickTuning.stopGap] 넘게 멈췄다가
/// 떼면 튕기지 않은 것으로 본다.
Object readFlick(List<FlickSample> s, StoneFace face, {double? releaseAt}) {
  final contact = firstContact(s, face);
  if (contact == null) return FlickMiss.missed;
  if (releaseAt != null &&
      s.isNotEmpty &&
      releaseAt - s.last.t > FlickTuning.stopGap) {
    return FlickMiss.tooWeak;
  }
  final vel = flickVelocity(s);
  if (vel == null || vel.$2 < FlickTuning.minPxPerSec) return FlickMiss.tooWeak;
  final power = flickPower(vel.$2);
  return FlickShot(
    angle: math.atan2(vel.$1.dy, vel.$1.dx),
    speed: powerToSpeed(power),
    hit: face.hitAt(contact),
    power: power,
    contact: contact,
  );
}
