// 설계서 v2 §3 숫자를 Forge2D 로 다시 재는 스크립트 (planck.js 시험대 measure.js 와 같은 장면).
// 실행: dart run bin/measure.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart';

String f(num n, [int d = 1]) => n.toStringAsFixed(d);

Future<void> main() async {
  await initializePhysics();
  print(
    '# 측정 결과 (dart run bin/measure.dart) — ${DateTime.now().toUtc().toIso8601String()} · '
    'Dart ${Platform.version.split(' ').first} · forge2d 0.15.2',
  );

  print('## A. 타격점 상·중·하 (같은 재질·같은 무게, 정면 충돌, 20cm/s)');
  for (final (gap, label) in [(8.0, '가까운 표적 8cm'), (20.0, '먼 표적 20cm')]) {
    for (final (hit, name) in [
      (1.0, '상(밀어치기)'),
      (0.0, '중(강타)'),
      (-1.0, '하(끌어치기)'),
    ]) {
      final (me, tg) = Scenes.hitPoint(gap, hit);
      print('  $label $name: 내 돌 최종 x=${f(me)} · 표적 이동 ${f(tg)}cm');
    }
  }

  print('\n## B. 재질별 — 같은 힘(충격량 60)으로 혼자 굴림');
  for (final m in StoneMaterial.values) {
    final (d, sec) = Scenes.materialRoll(m);
    print(
      '  ${m.label}: ${d == null ? '판 밖으로 나감' : '거리 ${f(d)}cm'} · ${f(sec, 2)}초',
    );
  }

  print('\n## B2. 재질별 — 같은 속도(30cm/s)로 청옥 표적을 정면으로 침');
  for (final m in StoneMaterial.values) {
    final x = Scenes.materialPush(m);
    print('  ${m.label} → ${x == null ? '표적 판 밖으로' : '표적 이동 ${f(x)}cm'}');
  }

  print('\n## B3. 모양별 — 같은 속도(40cm/s), 혼자 굴림');
  for (final s in StoneShape.values) {
    print('  ${s.label}: ${f(Scenes.shapeRoll(s))}cm');
  }

  print('\n## C. 빙백한옥 감속 하한');
  for (final minD in [0.0, 0.15, 0.3]) {
    final t = Table(minDamping: minD);
    final s = t.addStone(
      0,
      0,
      material: StoneMaterial.ice,
      shape: StoneShape.sphere,
    );
    s.body.linearDamping = minD;
    t.shoot(s, 0, 1.2, 0);
    final r = t.runTurn();
    print(
      '  감속 $minD: ${r.timedOut ? '10초 안에 안 멈춤 → 강제 정지' : '${f(r.seconds, 2)}초에 멈춤'} (이동 ${f(s.position.x)}cm)',
    );
    t.dispose();
  }

  const n = 2000;
  print('\n## D. 한 수 계산 비용 (16알 판, 무작위 한 수 $n번)');
  double q(List<double> a, double p) =>
      (List.of(a)..sort())[(a.length * p).floor()];
  double avg(List<num> a) => a.fold<double>(0, (s, v) => s + v) / a.length;
  for (final minD in [0.15, 0.3, 0.5]) {
    final times = <double>[], secs = <double>[];
    var timedOut = 0, outs = 0;
    for (var i = 0; i < n; i++) {
      final (t, _) = Scenes.randomGame(1000 + i, minDamping: minD);
      final sw = Stopwatch()..start();
      final r = t.runTurn();
      sw.stop();
      times.add(sw.elapsedMicroseconds / 1000);
      secs.add(r.seconds);
      if (r.timedOut) timedOut++;
      outs += t.stones.where((s) => s.out).length;
      t.dispose();
    }
    print(
      '  감속 하한 $minD: 계산 평균 ${f(avg(times), 2)}ms · 중앙 ${f(q(times, 0.5), 2)}ms · '
      '95% ${f(q(times, 0.95), 2)}ms · 최대 ${f(times.reduce(math.max), 2)}ms · '
      '게임 속 평균 ${f(avg(secs), 2)}초 · 95% ${f(q(secs, 0.95), 2)}초 · 10초 강제정지 $timedOut번 · '
      '한 수당 장외 ${f(outs / n, 2)}알',
    );
  }

  print('\n## E. 결정성 — 같은 입력 200판을 두 번 계산');
  var same = 0;
  for (var i = 0; i < 200; i++) {
    String snap() {
      final (t, _) = Scenes.randomGame(5000 + i);
      t.runTurn();
      final s = t.stones
          .map((s) => '${s.position.x},${s.position.y},${s.out}')
          .join(';');
      t.dispose();
      return s;
    }

    if (snap() == snap()) same++;
  }
  print('  같은 결과 $same/200');
}
