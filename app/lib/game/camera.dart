import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 대전장 카메라(2026-10-11 형 「돌의 움직임에 따라 화면 구성과 카메라 앵글의 전환」 · 설계서 §16.16).
///
/// 판정에는 손대지 않는다 — 그리기 위에 화면 변환 하나를 얹을 뿐이다.
/// - 쏘는 순간: 쏜 돌 쪽으로 밀고 들어가며(줌) 판을 눕힌다(내려다보던 눈이 낮아짐).
/// - 움직이는 동안: 빠른 돌들의 무게중심을 따라가고, 돌들이 퍼진 만큼만 당긴다.
/// - 센 충돌: 순간 확 당겼다 풀림(펀치) + 살짝 기울어짐(롤).
/// - 멈추면: 천천히 판 전체(처음 모습)로 돌아온다 — 겨누기·돌 고르기는 늘 처음 모습에서.
class BattleCamera {
  /// 꺼지면(설정 「카메라 연출」) 늘 처음 모습.
  bool enabled = true;

  double zoom = 1;

  /// 판을 눕힌 각(라디안, 0 = 위에서 내려다봄).
  double tilt = 0;

  /// 화면 기울기(라디안).
  double roll = 0;

  /// 화면 가운데에 둘 판 좌표(cm).
  Offset focus = Offset.zero;

  /// 위아래 검은 띠(0~1) — 큰 장면에서 영화처럼.
  double letterbox = 0;

  double _punch = 0;
  double _rollKick = 0;
  double _drama = 0;
  double _shotHold = 0;
  Offset _shotAt = Offset.zero;

  /// 판 반쪽 + 여백(cm) — 처음 모습에서 화면에 보이는 반 너비.
  static const double halfView = 25 + 1.6;

  static const double maxZoom = 1.6;
  static const double maxTilt = 0.42;

  /// 거의 처음 모습인가(돌 고르기·겨누기를 해도 되는가).
  bool get settled =>
      (zoom - 1).abs() < 0.01 &&
      tilt.abs() < 0.005 &&
      roll.abs() < 0.003 &&
      focus.distance < 0.05 &&
      _punch < 0.003;

  /// 한 수를 쏜 순간. [big] = 회심·내공·궁극기.
  void onShot(Offset at, {bool big = false}) {
    if (!enabled) return;
    _shotAt = at;
    _shotHold = 0.35;
    if (big) _drama = 1;
  }

  /// 충돌(빠르기 cm/s).
  void onImpact(Offset at, double speed) {
    if (!enabled || speed < 25) return;
    final k = ((speed - 25) / 95).clamp(0.0, 1.0);
    _punch = math.max(_punch, 0.04 + 0.1 * k);
    _rollKick = (at.dx >= focus.dx ? 1 : -1) * 0.025 * k;
    if (k > 0.6) _drama = math.max(_drama, 0.7);
  }

  /// 장외: 그쪽을 잠깐 본다.
  void onOut(Offset at) {
    if (!enabled) return;
    _punch = math.max(_punch, 0.06);
  }

  /// [moving] = 움직이는 돌 (자리 cm, 빠르기 cm/s).
  void update(double dt, List<(Offset, double)> moving) {
    final d = dt.clamp(0.0, 0.1);
    var zT = 1.0, tT = 0.0;
    var fT = Offset.zero;
    var follow = 2.6;
    if (enabled && (moving.isNotEmpty || _shotHold > 0)) {
      if (_shotHold > 0) {
        // 쏜 순간: 쏜 돌로 밀고 들어감.
        _shotHold -= d;
        zT = 1.32;
        tT = maxTilt * 0.75;
        fT = _shotAt;
        follow = 6;
      } else {
        var w = 0.0, top = 0.0;
        var c = Offset.zero;
        for (final (p, v) in moving) {
          final ww = math.max(v, 1.0);
          c += p * ww;
          w += ww;
          top = math.max(top, v);
        }
        c /= w;
        var spread = 0.0;
        for (final (p, _) in moving) {
          spread = math.max(spread, (p - c).distance);
        }
        // 퍼진 돌이 모두 보일 만큼만 당긴다(가장자리 8cm 여유).
        zT = (halfView / (spread + 9)).clamp(1.0, maxZoom);
        tT = maxTilt * (top / 110).clamp(0.0, 1.0);
        fT = c;
        follow = 4;
      }
    }
    // 판 밖이 너무 보이지 않게 가운데를 묶는다.
    final lim = halfView - halfView / zT;
    fT = Offset(fT.dx.clamp(-lim, lim), fT.dy.clamp(-lim, lim));
    double ease(double k) => 1 - math.exp(-d * k);
    zoom += (zT - zoom) * ease(follow);
    tilt += (tT - tilt) * ease(follow * 0.8);
    focus += (fT - focus) * ease(follow);
    _punch *= math.exp(-d * 7);
    _rollKick *= math.exp(-d * 5);
    roll = _rollKick;
    _drama = math.max(0, _drama - d * 0.9);
    final lbT = enabled ? (_drama > 0 ? 1.0 : 0.0) : 0.0;
    letterbox += (lbT - letterbox) * ease(8);
    if (!enabled) {
      zoom = 1;
      tilt = 0;
      roll = 0;
      focus = Offset.zero;
      _punch = 0;
    }
  }

  /// 화면 변환: [origin] = 판 가운데의 화면 자리, [scale] = cm 당 화소.
  Matrix4 matrix(Offset origin, double scale) {
    final z = zoom * (1 + _punch);
    final f = origin + focus * scale;
    return Matrix4.identity()
      ..translateByDouble(origin.dx, origin.dy, 0, 1)
      ..setEntry(3, 2, 0.0011)
      ..rotateX(tilt)
      ..rotateZ(roll)
      ..scaleByDouble(z, z, 1, 1)
      ..translateByDouble(-f.dx, -f.dy, 0, 1);
  }

  /// 화면 자리 → 카메라 없을 때의 화면 자리(판 평면 z=0 위에서 정확히 거꾸로).
  static Offset unproject(Matrix4 m, Offset p) {
    final s = m.storage; // 열 우선
    // 판 평면(z=0) 위의 점은 (x, y, 1) → (x', y', w') 3×3 사상이다.
    final a = s[0], b = s[4], c = s[12];
    final d = s[1], e = s[5], f = s[13];
    final g = s[3], h = s[7], i = s[15];
    final det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
    if (det.abs() < 1e-12) return p;
    final x = p.dx, y = p.dy;
    final ix = (e * i - f * h) * x + (c * h - b * i) * y + (b * f - c * e);
    final iy = (f * g - d * i) * x + (a * i - c * g) * y + (c * d - a * f);
    final iw = (d * h - e * g) * x + (b * g - a * h) * y + (a * e - b * d);
    return Offset(ix / iw, iy / iw);
  }
}
