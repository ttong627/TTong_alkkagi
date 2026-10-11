import 'dart:math' as math;

import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/screens/tutorial_screen.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

/// 입문 수련 판(설계서 §16.10)은 손으로 칠 수 있는 범위(≤120cm/s)에서 깰 수 있어야 한다.
/// 각도·세기를 훑어 한 수로 이기는 풀이가 넉넉히 있는지(쉬운 판인지) 센다.
void main() {
  setUpAll(initializePhysics);

  for (var i = 0; i < 3; i++) {
    test('수련 ${i + 1}: 한 수로 깨는 각도·세기가 넉넉하다', () {
      final l = lessons[i];
      var wins = 0, tried = 0;
      for (var a = -150.0; a <= -30; a += 2) {
        for (var sp = 50.0; sp <= 120; sp += 10) {
          tried++;
          final m = Match(l.config);
          final me = m.table.stones.firstWhere((s) => s.team == 0);
          m.shoot(me, a * math.pi / 180, sp, 0);
          var guard = 0;
          while (m.isMoving && guard++ < 20000) {
            m.step();
          }
          // 수련 3(일타쌍피)은 두 수까지 — 한 수 안에 둘 다 떨어지는지만 본다.
          if (m.alive(1) == 0) wins++;
          m.dispose();
        }
      }
      // ignore: avoid_print
      print('수련 ${i + 1}: 한 수 풀이 $wins / $tried');
      expect(wins, greaterThan(15), reason: '너무 어렵다');
    });
  }

  test('수련 4: 쉬운 상대와 3:2 — 내 돌이 더 많다', () {
    final m = Match(lessons[3].config);
    expect(m.alive(0), 3);
    expect(m.alive(1), 2);
    expect(lessons[3].config.difficulty, Difficulty.easy);
    m.dispose();
  });
}
