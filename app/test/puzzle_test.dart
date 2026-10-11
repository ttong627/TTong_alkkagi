import 'dart:math' as math;

import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/story/puzzles.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

/// tool/puzzle_sim.dart 가 찾은 풀이(각도 라디안, 처음 속도). 손으로 칠 수 있는 범위(≤120cm/s).
const solutions = {
  1: [(-1.6731146000766692, 110.0)],
  2: [(-2.532381238375205, 70.0), (0.30611271669968954, 80.0)],
  3: [(-1.5682114534647251, 60.0), (0.7399980335033897, 80.0)],
  4: [(-1.5573418599224607, 120.0), (3.0359060642900495, 110.0)],
  100: [(-1.5707963267948966, 120.0)],
};

void main() {
  setUpAll(initializePhysics);

  for (final p in [...puzzles, hermitPuzzle]) {
    test('묘수풀이 ${p.id} ${p.title}: 찾은 풀이로 성공 · 아무렇게나 치면 실패', () {
      MatchConfig cfg() => MatchConfig(
        mode: MatchMode.practice,
        arena: puzzleArena,
        layout: p.layout,
        shotLimit: p.shots,
      );
      final m = Match(cfg());
      for (final (angle, sp) in solutions[p.id]!) {
        m.shoot(m.table.stones[0], angle, sp, 0);
        while (m.isMoving) {
          m.step();
        }
      }
      expect(m.winner, 0);
      m.dispose();

      final miss = Match(cfg());
      for (var i = 0; i < p.shots; i++) {
        if (miss.isOver) break;
        miss.shoot(miss.table.stones[0], math.pi / 2, 20, 0);
        while (miss.isMoving) {
          miss.step();
        }
      }
      expect(miss.winner, 1, reason: '수를 다 쓰면 실패');
      miss.dispose();
    });
  }
}
