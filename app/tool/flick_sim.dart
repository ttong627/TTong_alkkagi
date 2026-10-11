// 손끝으로 돌 맞히기 — 가상 시험.
//
// 실행: flutter test tool/flick_sim.dart   (dart:ui 를 쓰므로 flutter test 로 돌린다)
//
// 사람 손을 흉내 내 화면 위를 미끄러지는 손끝을 수천 번 만들고, 구성(손끝 크기·마찰·빠르기 재는
// 구간)마다 겨눈 방향과 실제로 나간 방향이 얼마나 다른지, 일부러 비껴 쳤을 때 얼마나 꺾이는지,
// 살살 밀어도 나가는지를 잰다.
//
// 사람 손 흉내(가정 — 실기기 측정값이 아니다):
// - 화면의 돌 반지름 120 화소(논리 화소), 손가락 점은 1초에 120번, 점마다 ±1 화소 떨림
// - 돌 가운데를 겨누지만 옆으로 σb 만큼 빗나가고, 방향이 σa 만큼 틀어지고, 길이 σc 만큼 휜다
// - 돌 가장자리에서 20~250 화소 떨어진 곳에서 출발해 닿을 때까지 빨라지고, 닿은 뒤에도 지나간다
import 'dart:math' as math;

import 'package:alkkagi/game/flick.dart';
import 'package:flutter_test/flutter_test.dart';

const radius = 120.0;
final center = const Offset(200, 400);

class Noise {
  const Noise(this.sb, this.sa, this.sc);
  final double sb; // 옆 빗나감(화소)
  final double sa; // 방향 틀어짐(도)
  final double sc; // 휨(화소)
  @override
  String toString() => 'σb${sb.toInt()} σa${sa.toInt()}° σc${sc.toInt()}';
}

double gauss(math.Random r) {
  final u = 1 - r.nextDouble(), v = r.nextDouble();
  return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
}

double wrap(double a) {
  while (a > math.pi) {
    a -= 2 * math.pi;
  }
  while (a < -math.pi) {
    a += 2 * math.pi;
  }
  return a;
}

/// 손끝 길 하나. [phi] 겨눈 방향, [b] 옆 빗나감, [dir] 실제 방향, [vc] 닿을 때 빠르기.
List<FlickSample> swipe(
  math.Random r, {
  required double dir,
  required double b,
  required double bow,
  required double vc,
  double jitter = 1,
}) {
  final u = Offset(math.cos(dir), math.sin(dir));
  final perp = Offset(-u.dy, u.dx);
  final run = 20 + r.nextDouble() * 230 + radius * 1.5; // 출발 ~ 돌 가운데 줄
  final after = radius * 3;
  final total = run + after;
  const dt = 1 / 120;
  final pts = <FlickSample>[];
  var s = 0.0, t = 0.0;
  while (s <= total) {
    final along = -run + s;
    final lateral = b + bow * math.sin(math.pi * s / total);
    final p =
        center +
        u * along +
        perp * lateral +
        Offset(gauss(r) * jitter, gauss(r) * jitter);
    pts.add(FlickSample(p, t));
    // 닿기 전에는 고르게 빨라지고(v = vc·√(s/run)), 그 뒤로는 그대로.
    final v = s < run ? math.max(vc * 0.15, vc * math.sqrt(s / run)) : vc;
    s += v * dt;
    t += dt;
  }
  return pts;
}

FlickShot? play(StrikeTuning tune, List<FlickSample> pts) {
  final reader = StrikeReader(StoneDisc(center, radius, tune: tune));
  reader.down(pts.first);
  for (final p in pts.skip(1)) {
    final s = reader.move(p);
    if (s != null) return s;
  }
  reader.up();
  return null;
}

class Score {
  double p50 = 0, p90 = 0, miss = 0, gentle = 0, powerCv = 0;
}

Score measure(StrikeTuning tune, Noise n, int count, int seed) {
  final r = math.Random(seed);
  final errs = <double>[];
  var miss = 0;
  for (var i = 0; i < count; i++) {
    final phi = r.nextDouble() * 2 * math.pi - math.pi;
    final pts = swipe(
      r,
      dir: phi + gauss(r) * n.sa * math.pi / 180,
      b: gauss(r) * n.sb,
      bow: gauss(r) * n.sc,
      vc: 300 + r.nextDouble() * 1700,
    );
    final shot = play(tune, pts);
    if (shot == null) {
      miss++;
      continue;
    }
    errs.add(wrap(shot.angle - phi).abs() * 180 / math.pi);
  }
  errs.sort();
  final s = Score()
    ..p50 = errs.isEmpty ? 999 : errs[errs.length ~/ 2]
    ..p90 = errs.isEmpty ? 999 : errs[(errs.length * 0.9).floor()]
    ..miss = miss / count;
  // 살살(150~400 화소/초) 밀어도 나가는가.
  var ok = 0;
  for (var i = 0; i < 300; i++) {
    final pts = swipe(
      r,
      dir: -math.pi / 2,
      b: gauss(r) * n.sb,
      bow: 0,
      vc: 150 + r.nextDouble() * 250,
    );
    if (play(tune, pts) != null) ok++;
  }
  s.gentle = ok / 300;
  // 같은 빠르기(900)로 같은 데를 겨눴을 때 내공이 얼마나 흔들리나(변동계수).
  final pw = <double>[];
  for (var i = 0; i < 300; i++) {
    final pts = swipe(
      r,
      dir: -math.pi / 2 + gauss(r) * n.sa * math.pi / 180,
      b: gauss(r) * n.sb,
      bow: gauss(r) * n.sc,
      vc: 900,
    );
    final shot = play(tune, pts);
    if (shot != null) pw.add(shot.power);
  }
  final mean = pw.reduce((a, b) => a + b) / pw.length;
  final sd = math.sqrt(
    pw.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / pw.length,
  );
  s.powerCv = sd / mean;
  return s;
}

/// 일부러 돌 가운데에서 [frac]×닿는 거리만큼 비껴 쳤을 때 꺾이는 각도(도). 떨림 없이.
double cut(StrikeTuning tune, double frac) {
  final reach = radius * (1 + tune.fingerRatio);
  final pts = swipe(
    math.Random(1),
    dir: -math.pi / 2,
    b: frac * reach,
    bow: 0,
    vc: 900,
    jitter: 0,
  );
  final s = play(tune, pts);
  if (s == null) return double.nan;
  return wrap(s.angle + math.pi / 2).abs() * 180 / math.pi;
}

void main() {
  test('회심 비율', criticalRate);
  test(
    '확인 시험: 상위 구성 다시 보기',
    confirm,
    timeout: const Timeout(Duration(minutes: 30)),
  );
  test('가상 시험: 구성 고르기', () {
    const noises = [
      Noise(6, 2, 0),
      Noise(6, 4, 3),
      Noise(12, 2, 3),
      Noise(12, 4, 3),
      Noise(12, 6, 6),
      Noise(18, 4, 3),
      Noise(18, 6, 6),
    ];
    final rows =
        <(StrikeTuning, double, double, double, double, double, double)>[];
    for (final fr in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      for (final mu in [0.0, 0.15, 0.3, 0.5, 1.0]) {
        for (final st in [1 / 3, 1.0]) {
          if (mu == 0 && st == 1.0) continue; // 마찰 0 이면 stick 은 상관없다.
          for (final w in [0.016, 0.03, 0.04, 0.06]) {
            final tune = StrikeTuning(
              fingerRatio: fr,
              friction: mu,
              stick: st,
              velocityWindow: w,
            );
            var p50 = 0.0, p90 = 0.0, miss = 0.0, gentle = 1.0, cv = 0.0;
            for (var k = 0; k < noises.length; k++) {
              final s = measure(tune, noises[k], 600, 1000 + k);
              p50 += s.p50 / noises.length;
              p90 += s.p90 / noises.length;
              miss += s.miss / noises.length;
              gentle = math.min(gentle, s.gentle);
              cv += s.powerCv / noises.length;
            }
            rows.add((tune, p50, p90, miss, gentle, cv, cut(tune, 0.6)));
          }
        }
      }
    }
    String fmt(
      (StrikeTuning, double, double, double, double, double, double) r,
    ) {
      final t = r.$1;
      return '손끝${t.fingerRatio.toStringAsFixed(2)} 마찰${t.friction.toStringAsFixed(2)} '
          '옮김${t.stick.toStringAsFixed(2)} 구간${(t.velocityWindow * 1000).round()}ms | '
          '오차 중앙 ${r.$2.toStringAsFixed(2)}° · 90% ${r.$3.toStringAsFixed(2)}° | '
          '헛손 ${(r.$4 * 100).toStringAsFixed(1)}% | 살살 ${(r.$5 * 100).toStringAsFixed(0)}% | '
          '내공흔들림 ${(r.$6 * 100).toStringAsFixed(1)}% | 비껴치기(0.6) ${r.$7.toStringAsFixed(1)}°';
    }

    // 고르는 규칙(결과를 보기 전에 정함):
    //  1) 살살 밀어도 100% 나간다  2) 일부러 0.6 만큼 비껴 치면 20° 이상 꺾인다(타점이 의미 있다)
    //  3) 그 안에서 90% 오차(여러 손 흉내 평균)가 가장 작은 것, 같으면 헛손이 적은 것.
    final ok = rows.where((r) => r.$5 >= 1 && r.$7 >= 20).toList()
      ..sort((a, b) {
        final c = a.$3.compareTo(b.$3);
        return c != 0 ? c : a.$4.compareTo(b.$4);
      });
    // ignore: avoid_print
    print(
      '구성 ${rows.length}개 × 손 흉내 ${noises.length}종 × 600번 + 살살 300 + 내공 300',
    );
    // ignore: avoid_print
    print('== 조건 통과 상위 10 ==');
    for (final r in ok.take(10)) {
      // ignore: avoid_print
      print(fmt(r));
    }
    // ignore: avoid_print
    print('== 참고: 조건 무시 90% 오차 상위 5 ==');
    final all = [...rows]..sort((a, b) => a.$3.compareTo(b.$3));
    for (final r in all.take(5)) {
      // ignore: avoid_print
      print(fmt(r));
    }
    // ignore: avoid_print
    print('== 지금 기본값 ==');
    for (final r in rows.where(
      (r) =>
          r.$1.fingerRatio == StrikeTuning.standard.fingerRatio &&
          r.$1.friction == StrikeTuning.standard.friction &&
          r.$1.stick == StrikeTuning.standard.stick &&
          r.$1.velocityWindow == StrikeTuning.standard.velocityWindow,
    )) {
      // ignore: avoid_print
      print(fmt(r));
    }
    // ignore: avoid_print
    print('== 손 흉내별(1위 구성) ==');
    if (ok.isNotEmpty) {
      final best = ok.first.$1;
      for (var k = 0; k < noises.length; k++) {
        final s = measure(best, noises[k], 2000, 5000 + k);
        // ignore: avoid_print
        print(
          '${noises[k]}: 중앙 ${s.p50.toStringAsFixed(2)}° 90% ${s.p90.toStringAsFixed(2)}° '
          '헛손 ${(s.miss * 100).toStringAsFixed(1)}%',
        );
      }
      for (final f in [0.2, 0.4, 0.6, 0.8, 0.95]) {
        // ignore: avoid_print
        print(
          '비껴치기 ${f.toStringAsFixed(2)} → ${cut(best, f).toStringAsFixed(1)}°',
        );
      }
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}

/// 1차 결과 상위 구성을 씨앗을 바꿔 더 많이 돌려 다시 본다.
void confirm() {
  const noises = [
    Noise(6, 2, 0),
    Noise(6, 4, 3),
    Noise(12, 2, 3),
    Noise(12, 4, 3),
    Noise(12, 6, 6),
    Noise(18, 4, 3),
    Noise(18, 6, 6),
  ];
  final cands = {
    'A 손끝0 마찰0.3 옮김1 60ms': const StrikeTuning(
      fingerRatio: 0,
      friction: 0.3,
      stick: 1,
      velocityWindow: 0.06,
    ),
    'A2 같은데 80ms': const StrikeTuning(
      fingerRatio: 0,
      friction: 0.3,
      stick: 1,
      velocityWindow: 0.08,
    ),
    'A3 같은데 100ms': const StrikeTuning(
      fingerRatio: 0,
      friction: 0.3,
      stick: 1,
      velocityWindow: 0.1,
    ),
    'B 손끝0.5 마찰0.15 옮김⅓ 60ms': const StrikeTuning(
      fingerRatio: 0.5,
      friction: 0.15,
      stick: 1 / 3,
      velocityWindow: 0.06,
    ),
    'C 손끝0.25 마찰0.15 옮김1 60ms': const StrikeTuning(
      fingerRatio: 0.25,
      friction: 0.15,
      stick: 1,
      velocityWindow: 0.06,
    ),
    'D 손끝0 마찰0.15 옮김1 60ms': const StrikeTuning(
      fingerRatio: 0,
      friction: 0.15,
      stick: 1,
      velocityWindow: 0.06,
    ),
    '처음 기본(손끝0.5 마찰0.3 옮김⅓ 40ms)': const StrikeTuning(),
  };
  for (final e in cands.entries) {
    var p50 = 0.0, p90 = 0.0, cv = 0.0;
    for (var seed = 0; seed < 3; seed++) {
      for (var k = 0; k < noises.length; k++) {
        final s = measure(e.value, noises[k], 2000, 90000 + seed * 100 + k);
        p50 += s.p50 / (3 * noises.length);
        p90 += s.p90 / (3 * noises.length);
        cv += s.powerCv / (3 * noises.length);
      }
    }
    // ignore: avoid_print
    print(
      '${e.key}: 오차 중앙 ${p50.toStringAsFixed(2)}° 90% ${p90.toStringAsFixed(2)}° '
      '내공흔들림 ${(cv * 100).toStringAsFixed(1)}% 비껴치기 0.6→${cut(e.value, 0.6).toStringAsFixed(1)}° 0.8→${cut(e.value, 0.8).toStringAsFixed(1)}°',
    );
  }
}

/// 회심 일격이 터지는 비율: 한가운데를 노리고 알맞은 세기(닿을 때 900~1,300화소/초)로 친다고 볼 때.
void criticalRate() {
  const noises = [Noise(6, 2, 0), Noise(12, 4, 3), Noise(18, 6, 6)];
  for (final n in noises) {
    final r = math.Random(4242);
    var crit = 0, shots = 0;
    for (var i = 0; i < 4000; i++) {
      final pts = swipe(
        r,
        dir: -math.pi / 2 + gauss(r) * n.sa * math.pi / 180,
        b: gauss(r) * n.sb,
        bow: gauss(r) * n.sc,
        vc: 900 + r.nextDouble() * 400,
      );
      final s = play(StrikeTuning.standard, pts);
      if (s == null) continue;
      shots++;
      if (s.critical) crit++;
    }
    // ignore: avoid_print
    print('$n: 회심 ${(crit / shots * 100).toStringAsFixed(1)}% ($crit/$shots)');
  }
}
