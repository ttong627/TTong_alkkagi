// 묘수풀이가 풀리는지 가상으로 찾아본다(손으로 칠 수 있는 범위: 처음 속도 30~120cm/s, 가운데 타격).
//
// 실행: flutter test tool/puzzle_sim.dart
// 찾은 풀이는 test/puzzle_test.dart 에 적어 두고, 그 시험이 매번 다시 확인한다.
import 'dart:math' as math;

import 'package:alkkagi/game/arena.dart';
import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/story/puzzles.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Shot = ({double angle, double speed});

/// [stones] 상태에서 내 돌로 한 번 쳐 본다. (떨어진 표적 수, 내 돌이 남았나, 다음 상태).
(int, bool, List<Placement>) trial(List<Placement> stones, Shot s) {
  // 묘수풀이 대전장(거북 장터 돌바닥: 바닥 배수 1.0 · 네모 판)과 같게.
  final t = Table(floorFactor: Arena.turtleMarket.floorFactor);
  for (final p in stones) {
    t.addStone(p.x, p.y, team: p.team, material: p.material, shape: p.shape);
  }
  t.shoot(t.stones[0], s.angle, s.speed, 0);
  t.runTurn();
  var out = 0;
  final next = <Placement>[];
  for (var i = 0; i < t.stones.length; i++) {
    final st = t.stones[i];
    if (st.out) {
      if (st.team == 1) out++;
      continue;
    }
    next.add(Placement(st.position.x, st.position.y, team: st.team));
  }
  final mineLeft = !t.stones[0].out;
  t.dispose();
  return (out, mineLeft, next);
}

List<Shot> candidates(List<Placement> stones) {
  final me = stones.first;
  final out = <Shot>[];
  for (final tg in stones.skip(1)) {
    final base = math.atan2(tg.y - me.y, tg.x - me.x);
    for (var d = -8.0; d <= 8.0; d += 0.5) {
      for (var sp = 30.0; sp <= 120; sp += 10) {
        out.add((angle: base + d * math.pi / 180, speed: sp));
      }
    }
  }
  return out;
}

List<Shot>? solve(Puzzle p) {
  final targets = p.layout.where((x) => x.team == 1).length;
  // 한 수씩 깊이 우선: 첫 수는 많이 떨어뜨리고 내 돌이 남는 것부터.
  List<Shot>? go(List<Placement> stones, int left, int need) {
    final scored = <(int, Shot, List<Placement>, bool)>[];
    for (final c in candidates(stones)) {
      final (out, mine, next) = trial(stones, c);
      if (out >= need) return [c];
      if (left > 1 && mine) scored.add((out, c, next, mine));
    }
    if (left <= 1) return null;
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (out, c, next, _) in scored.take(25)) {
      final rest = go(next, left - 1, need - out);
      if (rest != null) return [c, ...rest];
    }
    return null;
  }

  return go(p.layout, p.shots, targets);
}

void main() {
  setUpAll(initializePhysics);
  test('묘수풀이 풀이 찾기', () {
    for (final p in [...puzzles, hermitPuzzle]) {
      final sol = solve(p);
      // ignore: avoid_print
      print(
        '${p.id} ${p.title}: ${sol == null ? '못 찾음' : sol.map((s) => '(${s.angle}, ${s.speed.toStringAsFixed(0)})').join(' → ')}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
