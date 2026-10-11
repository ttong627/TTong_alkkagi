import 'dart:math' as math;
import 'dart:ui';

import 'match.dart';

/// 손가락 위치 한 점(화면 좌표, 초).
///
/// [area] 는 손끝이 화면에 닿은 넓이를 나타내는 값(폰이 알려 주는 접촉 크기). 폰마다 단위가
/// 달라 [TouchProfile] 이 그 폰의 평소 값과 견주어 쓴다. 모르면 null.
class FlickSample {
  const FlickSample(this.pos, this.t, {this.area});
  final Offset pos;
  final double t;
  final double? area;
}

/// 이 폰에서 손끝이 화면에 닿는 넓이의 평소 범위. 앱 안의 모든 손대기를 모은다.
///
/// 돌을 칠 때 평소보다 **넓게** 닿았으면(손끝을 눕혀 낮게 밀었으면) 돌 아래를 친 것,
/// **좁게** 닿았으면(손끝만 세워 스쳤으면) 돌 위를 친 것으로 본다.
class TouchProfile {
  TouchProfile({this.keep = 400, this.minSamples = 30});

  /// 앱 전체가 함께 쓰는 하나.
  static final shared = TouchProfile();

  /// 위아래 타격점을 끈 설정: 넓이를 받아도 판단하지 않는다.
  static final off = TouchProfile(keep: 0, minSamples: 1 << 30);

  final int keep;
  final int minSamples;
  final _areas = <double>[];

  int get count => _areas.length;

  /// 모은 넓이(저장용).
  List<double> get areas => List.unmodifiable(_areas);

  /// 저장해 둔 넓이를 되살린다.
  void restore(Iterable<double> v) {
    _areas
      ..clear()
      ..addAll(v.where((a) => a.isFinite && a > 0));
    while (_areas.length > keep) {
      _areas.removeAt(0);
    }
  }

  void clear() => _areas.clear();

  void add(double? area) {
    if (keep <= 0 || area == null || !area.isFinite || area <= 0) return;
    _areas.add(area);
    if (_areas.length > keep) _areas.removeAt(0);
  }

  /// (아래 10%, 가운데, 위 10%). 자료가 모자라거나 폰이 넓이를 늘 같게 알려 주면 null.
  (double, double, double)? get range {
    if (_areas.length < minSamples) return null;
    final s = [..._areas]..sort();
    double at(double q) => s[((s.length - 1) * q).round()];
    final lo = at(0.1), mid = at(0.5), hi = at(0.9);
    if (mid <= 0 || (hi - lo) / mid < 0.08) return null;
    return (lo, mid, hi);
  }

  /// 닿은 넓이 → 위아래 타격점 −1(아래)~+1(위). 판단할 수 없으면 null.
  double? hitFor(double area) {
    final r = range;
    if (r == null) return null;
    final (lo, mid, hi) = r;
    if (area >= mid) return -((area - mid) / (hi - mid)).clamp(0.0, 1.0);
    return ((mid - area) / (mid - lo)).clamp(0.0, 1.0);
  }
}

/// 가까이 보기 화면에 위에서 내려다본 돌(화면 좌표).
///
/// 폰을 바닥에 눕혀 놓고 그 위에 돌이 있다고 본다. 손끝은 화면 위를 미끄러지다 돌 가장자리에
/// 부딪힌다. 손끝도 크기가 있으므로 [fingerRadius] 만큼 두툼한 원으로 본다.
class StoneDisc {
  const StoneDisc(
    this.center,
    this.radius, {
    this.tune = StrikeTuning.standard,
    this.mass = referenceMass,
  });
  final Offset center;
  final double radius;
  final StrikeTuning tune;

  /// 돌 무게(재질 밀도 × 모양 부피, 상대값). 무거울수록 같은 손끝에 덜 나간다([massFactor]).
  final double mass;

  /// 손끝 반지름(화면 길이).
  double get fingerRadius => radius * tune.fingerRatio;

  /// 손끝 중심이 이 거리 안에 들면 돌에 닿은 것이다.
  double get reach => radius + fingerRadius;

  bool touches(Offset p) => (p - center).distance <= reach;
}

/// 손끝이 돌을 쳐 내지 못한 까닭.
enum FlickMiss {
  /// 손끝이 돌에 닿지 않았다.
  missed('검지로 돌을 향해 튕겨 보세요'),

  /// 돌에 대기만 하고 밀지 않았다.
  tooWeak('조금 더 세게 튕겨 보세요');

  const FlickMiss(this.hint);
  final String hint;
}

/// 손끝이 돌을 친 결과.
class FlickShot {
  const FlickShot({
    this.flick = false,
    required this.angle,
    required this.speed,
    required this.hit,
    required this.power,
    required this.contact,
    this.offset = 0,
    this.curl = 0,
    this.critical = false,
  });

  /// 비껴 맞은 정도 0(한가운데)~1(끝을 스침).
  final double offset;

  /// 손끝이 돌 옆을 쓸고 간 방향과 세기 −1~+1(태극이 휘는 방향).
  final double curl;

  /// 회심 일격(크리티컬): 한가운데를 알맞은 세기로 맞혔다([CriticalRule]).
  final bool critical;

  /// 판 위 방향(라디안). 화면 위쪽 = 판 위쪽.
  final double angle;

  /// 처음 속도(cm/s).
  final double speed;

  /// 위아래 타격점 −1(아래)~+1(위). 손끝이 화면에 닿은 넓이로 정한다([TouchProfile]).
  /// 아래 끝이면 돌이 떠서 날고, 위 끝이면 바닥에 눌렸다 튀어 오른다.
  final double hit;

  /// 내공(세기) 0~1.
  final double power;

  /// 손끝이 돌에 닿은 점(손끝 원과 돌 원이 맞닿은 곳, 화면 좌표).
  final Offset contact;

  /// 튕기기: 손을 뗀 뒤 날아간 손끝이 돌을 맞혔다(화면에 안 닿은 채 맞음 → 위쪽).
  final bool flick;
}

/// 맞히기 → 방향·세기 환산 기준. 기본값은 가상 시험(tool/flick_sim.dart)으로 골랐다.
///
/// 2026-10-11 가상 시험(구성 180개 × 손 흉내 7종): 손끝을 점(0)으로 보고, 마찰 0.3 · 옮김 1 ·
/// 빠르기 구간 0.1초가 겨눈 방향과 나간 방향의 차이(90%)가 가장 작으면서 일부러 비껴 치면
/// 꺾인다(0.6 → 20°, 0.8 → 36°). 처음 값(0.5 · 0.3 · ⅓ · 0.04초)보다 90% 오차 8.32° → 7.12°,
/// 같은 손놀림의 내공 흔들림 24.6% → 12.2%.
class StrikeTuning {
  const StrikeTuning({
    this.fingerRatio = 0,
    this.friction = 0.3,
    this.stick = 1,
    this.velocityWindow = 0.1,
    this.minPxPerSec = 60,
    this.fullPxPerSec = 1500,
    this.minShotSpeed = 8,
    this.pushTravel = 0.3,
    this.pushMinPxPerSec = 450,
    this.flickReach = 2.5,
    this.flickMinPxPerSec = 300,
  });

  /// 지금 쓰는 값.
  static const standard = StrikeTuning();

  /// 손끝 반지름 ÷ 돌 반지름.
  final double fingerRatio;

  /// 손끝과 돌 사이 마찰. 비껴 맞을 때 돌이 손끝 움직임 쪽으로 끌려가는 정도의 한도.
  final double friction;

  /// 비껴 맞을 때 손끝 옆 움직임이 돌에 옮겨 가는 비율(마찰 한도 안에서).
  final double stick;

  /// 닿는 순간 빠르기를 잴 구간(초).
  final double velocityWindow;

  /// 이보다 느리게 닿으면 쳐 내지 않고 돌에 손을 댄 것으로 본다(화소/초).
  final double minPxPerSec;

  /// 돌이 이 빠르기로 밀려 나가면 내공 100%(화소/초).
  final double fullPxPerSec;

  /// 내공 0% 일 때도 나가는 최소 속도(cm/s).
  final double minShotSpeed;

  /// 돌에 손을 댄 채 밀 때, 이만큼(돌 반지름 비율) 움직여야 민 것으로 본다.
  /// 0.15 였을 때 손 떨림(약 17dp)만으로 약하게 나가 한 수를 잃었다 → 0.3(2026-10-11 점검).
  final double pushTravel;

  /// 돌에 손을 댄 채 밀 때 이보다 느리면 겨누는 중으로 본다(쏘지 않음 · 화소/초).
  /// 천천히 끌어도 바로 나가 — 새총처럼 뒤로 끌어 보다 제 돌을 뒤로 쏘곤 했다(2026-10-11 점검).
  final double pushMinPxPerSec;

  /// 튕기기(2026-10-11 형 「검지로 가상의 돌을 튕기는 것」): 손을 뗀 뒤에도 손끝은 그 빠르기로
  /// 날아간다고 본다. 뗀 자리에서 돌 둘레까지 이 거리(돌 반지름 배수) 안이면 떠서 맞힌다. [가정]
  final double flickReach;

  /// 이보다 느리게 떼면 튕긴 것이 아니라 그냥 손을 뗀 것(화소/초).
  final double flickMinPxPerSec;
}

/// 마지막 [StrikeTuning.velocityWindow] 초 동안의 움직임으로 빠르기(화소/초)를 잰다.
Offset? velocityAt(
  List<FlickSample> s,
  Offset pos,
  double t, [
  StrikeTuning tune = StrikeTuning.standard,
]) {
  if (s.isEmpty) return null;
  var i = s.length - 1;
  while (i > 0 && t - s[i - 1].t <= tune.velocityWindow + 1e-9) {
    i--;
  }
  final dt = t - s[i].t;
  if (dt <= 0) return null;
  return (pos - s[i].pos) / dt;
}

/// 회심 일격(크리티컬) 규칙 (설계서 §3.9). 평타에서 터지면 내공 1칸이 찬다.
///
/// 한가운데(비껴 맞은 정도 ≤ [maxOffset])를 알맞은 세기([minPower]~[maxPower])로 맞혀야 한다 —
/// 너무 세게 치면 손이 흔들려 회심이 아니다. 값은 [가정], 가상 시험(tool/flick_sim.dart)에서 터지는
/// 비율을 재어 둔다.
abstract final class CriticalRule {
  static const double maxOffset = 0.15;
  static const double minPower = 0.5;
  static const double maxPower = 0.9;

  /// 회심이면 처음 속도 배수.
  static const double speedBonus = 1.15;

  static bool test(double offset, double power) =>
      offset <= maxOffset && power >= minPower && power <= maxPower;
}

/// 둥근 청옥 돌의 무게(기준).
const double referenceMass = 2.43;

/// 손끝의 유효 무게 ÷ 기준 돌 무게. [가정] 손끝(끝마디)이 돌보다 무겁다고 본 값.
const double fingerMassRatio = 3;

/// 무게 [mass] 인 돌이 기준 돌보다 몇 배 빠르게 나가나.
///
/// 손끝(무게 m_f)이 돌(m)에 부딪히면 돌이 받는 빠르기는 m_f / (m_f + m) 에 비례한다
/// (운동량 보존). 기준 돌에서 1 이 되게 나눈다: (m_f + m₀) / (m_f + m).
double massFactor(double mass) {
  const mf = fingerMassRatio * referenceMass;
  return (mf + referenceMass) / (mf + mass);
}

/// 빠르기(화소/초) → 내공 0~1.
double strikePower(
  double pxPerSec, [
  StrikeTuning tune = StrikeTuning.standard,
]) => ((pxPerSec - tune.minPxPerSec) / (tune.fullPxPerSec - tune.minPxPerSec))
    .clamp(0.0, 1.0);

/// 내공 0~1 → 처음 속도(cm/s).
double powerToSpeed(
  double power, [
  StrikeTuning tune = StrikeTuning.standard,
]) => tune.minShotSpeed + (baseMaxSpeed - tune.minShotSpeed) * power;

/// 손끝 중심이 [contact] 에 있을 때 빠르기 [v] 로 돌에 부딪히면 돌이 밀려 나가는 빠르기(화면).
///
/// 돌은 맞은 면에 수직(손끝 → 돌 중심)으로 밀려 나가고, 손끝이 옆으로 미끄러진 만큼 마찰로
/// 조금 끌려간다(마찰 한도 [StrikeTuning.friction]). 돌 가운데를 치면 손끝 방향 그대로,
/// 가장자리를 치면 비스듬히, 아주 끝을 스치면 약하게 나간다.
Offset? strikeVelocity(StoneDisc disc, Offset finger, Offset v) {
  final d = disc.center - finger;
  if (d.distance == 0) return v;
  final n = d / d.distance;
  final vn = v.dx * n.dx + v.dy * n.dy;
  if (vn <= 0) return null;
  final tg = Offset(-n.dy, n.dx);
  final vt = v.dx * tg.dx + v.dy * tg.dy;
  final lim = disc.tune.friction * vn;
  final ut = (vt * disc.tune.stick).clamp(-lim, lim);
  return n * vn + tg * ut;
}

/// 선분 a→b 위에서 손끝 중심이 돌에 처음 닿는 비율(0~1). 안 닿으면 null.
double? _enterAt(Offset a, Offset b, StoneDisc disc) {
  final d = b - a, f = a - disc.center;
  final aa = d.dx * d.dx + d.dy * d.dy;
  if (aa == 0) return null;
  final bb = 2 * (f.dx * d.dx + f.dy * d.dy);
  final cc = f.dx * f.dx + f.dy * f.dy - disc.reach * disc.reach;
  final disc2 = bb * bb - 4 * aa * cc;
  if (disc2 < 0) return null;
  final r = (-bb - math.sqrt(disc2)) / (2 * aa);
  return r >= 0 && r <= 1 ? r : null;
}

/// 손가락 움직임을 하나씩 받아, 돌에 닿는 순간 쳐 낸 결과를 낸다.
///
/// - 바깥에서 미끄러져 와 닿으면: 닿은 점과 그 순간 빠르기로 [strikeVelocity].
/// - 돌 위에서 손을 대고 시작했거나 너무 느리게 닿았으면: 손을 댄 채 미는 것으로 보고,
///   [StrikeTuning.pushTravel] 만큼 움직이면 그 방향·빠르기로 민다.
class StrikeReader {
  StrikeReader(this.disc, {TouchProfile? profile})
    : profile = profile ?? TouchProfile.shared;
  final StoneDisc disc;
  final TouchProfile profile;
  StrikeTuning get tune => disc.tune;
  final samples = <FlickSample>[];

  /// 손을 댄 채 미는 중이면 손을 댄 점.
  Offset? _pushFrom;
  bool _touched = false;
  FlickShot? _shot;

  /// 이미 쳐 냈으면 그 결과.
  FlickShot? get shot => _shot;

  /// 손끝이 돌에 한 번이라도 닿았는가.
  bool get touched => _touched;

  /// 손끝을 새로 댔다.
  FlickShot? down(FlickSample p) {
    samples
      ..clear()
      ..add(p);
    _shot = null;
    _touched = disc.touches(p.pos);
    _pushFrom = _touched ? p.pos : null;
    return null;
  }

  /// 손끝이 움직였다. 이번 움직임으로 쳐 냈으면 결과를 낸다(한 번만).
  FlickShot? move(FlickSample p) {
    if (_shot != null || samples.isEmpty) return null;
    final prev = samples.last;
    if (_pushFrom != null) {
      samples.add(p);
      if (!disc.touches(p.pos)) {
        // 손을 댄 채 밀다가 돌 밖으로 빠져나갔다 → 다시 바깥에서 오는 손끝으로 본다.
        _pushFrom = null;
        return null;
      }
      if ((p.pos - _pushFrom!).distance < disc.radius * tune.pushTravel) {
        return null;
      }
      final v = velocityAt(
        samples.sublist(0, samples.length - 1),
        p.pos,
        p.t,
        tune,
      );
      if (v == null || v.distance < tune.pushMinPxPerSec) return null;
      return _fire(v, p.pos, v, push: true);
    }
    final r = _enterAt(prev.pos, p.pos, disc);
    if (r == null) {
      samples.add(p);
      return null;
    }
    _touched = true;
    final at = Offset.lerp(prev.pos, p.pos, r)!;
    final tc = prev.t + (p.t - prev.t) * r;
    final v =
        velocityAt(samples, at, tc, tune) ??
        (p.pos - prev.pos) / math.max(1e-6, p.t - prev.t);
    samples.add(p);
    final u = strikeVelocity(disc, at, v);
    if (u == null || u.distance < tune.minPxPerSec) {
      // 살며시 닿았다 → 손을 댄 채 미는 것으로 이어 본다.
      _pushFrom = at;
      return null;
    }
    return _fire(u, at, v);
  }

  /// 손을 뗀 순간: 손끝이 그 빠르기로 계속 날아가 [StrikeTuning.flickReach] 안에서 돌을 맞히면
  /// 튕긴 것으로 쳐 낸다(검지로 튕기기 — 손끝이 화면을 스치다 돌 앞에서 떠도 맞는다).
  /// 화면에 안 닿은 채 맞으니 위아래 타격점은 뗀 뒤 날아간 거리만큼 위쪽: 반지름 하나면 +1(맨 위).
  FlickShot? release() {
    if (_shot != null || _pushFrom != null || samples.length < 2) return null;
    final p = samples.last;
    final v = velocityAt(
      samples.sublist(0, samples.length - 1),
      p.pos,
      p.t,
      tune,
    );
    if (v == null || v.distance < tune.flickMinPxPerSec) return null;
    final reach = disc.radius * tune.flickReach;
    final far = p.pos + v / v.distance * reach;
    final r = _enterAt(p.pos, far, disc);
    if (r == null) return null;
    final at = Offset.lerp(p.pos, far, r)!;
    final u = strikeVelocity(disc, at, v);
    if (u == null || u.distance < tune.minPxPerSec) return null;
    _touched = true;
    final gap = (at - p.pos).distance;
    return _fire(u, at, v, flickHit: (gap / disc.radius).clamp(0.0, 1.0));
  }

  /// 손을 뗐다. 쳐 내지 못했으면 그 까닭.
  FlickMiss? up() {
    if (_shot != null) return null;
    samples.clear();
    _pushFrom = null;
    return _touched ? FlickMiss.tooWeak : FlickMiss.missed;
  }

  /// 부딪힐 때 손끝이 화면에 닿은 넓이: 그 순간까지 [areaWindow] 초 안에서 가장 넓은 값.
  static const double areaWindow = 0.03;

  /// 마지막으로 쳐 낸 순간의 닿은 넓이(화면 안내용). 모르면 null.
  double? strikeArea;

  double? _areaNear(double t) {
    double? best;
    for (final p in samples) {
      final a = p.area;
      if (a == null || (p.t - t).abs() > areaWindow) continue;
      if (best == null || a > best) best = a;
    }
    return best;
  }

  /// [push] 면 돌에 손을 댄 채 민 것 — 맞힌 것이 아니라 회심이 없다.
  FlickShot _fire(
    Offset u,
    Offset fingerAt,
    Offset finger, {
    bool push = false,
    double? flickHit,
  }) {
    final power = strikePower(u.distance, tune);
    final d = disc.center - fingerAt;
    final contact = d.distance == 0
        ? fingerAt
        : fingerAt + d / d.distance * disc.fingerRadius;
    final area = strikeArea = _areaNear(samples.last.t);
    // 비껴 맞은 정도 = 손끝 방향과 (닿은 점 → 돌 중심) 사이 각의 사인. 부호는 쓸고 간 쪽.
    var cross = 0.0;
    if (d.distance > 0 && finger.distance > 0) {
      final n = d / d.distance, f = finger / finger.distance;
      cross = f.dx * n.dy - f.dy * n.dx;
    }
    final offset = cross.abs().clamp(0.0, 1.0);
    final critical = !push && CriticalRule.test(offset, power);
    return _shot = FlickShot(
      angle: math.atan2(u.dy, u.dx),
      speed:
          powerToSpeed(power, tune) *
          massFactor(disc.mass) *
          (critical ? CriticalRule.speedBonus : 1),
      hit: flickHit != null
          ? math.max(flickHit, area == null ? 0 : (profile.hitFor(area) ?? 0))
          : (area == null ? 0 : (profile.hitFor(area) ?? 0)),
      flick: flickHit != null,
      power: power,
      contact: contact,
      offset: offset,
      curl: (cross / 0.6).clamp(-1.0, 1.0),
      critical: critical,
    );
  }

  /// 손끝이 지금처럼 곧게 오면 어디로 얼마나 나갈지(겨누기 표시용). 안 닿을 길이면 null.
  (double angle, double power)? predict() {
    if (_shot != null || _pushFrom != null || samples.length < 2) return null;
    final p = samples.last;
    final v = velocityAt(
      samples.sublist(0, samples.length - 1),
      p.pos,
      p.t,
      tune,
    );
    if (v == null || v.distance < 1) return null;
    final far = p.pos + v / v.distance * (disc.reach * 4 + 2000);
    final r = _enterAt(p.pos, far, disc);
    if (r == null) return null;
    final at = Offset.lerp(p.pos, far, r)!;
    final u = strikeVelocity(disc, at, v);
    if (u == null) return null;
    return (math.atan2(u.dy, u.dx), strikePower(u.distance, tune));
  }
}
