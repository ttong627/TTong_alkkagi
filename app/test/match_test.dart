import 'dart:math' as math;

import 'package:alkkagi/game/ai.dart';
import 'package:alkkagi/game/match.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

void runToRest(Match m) {
  var guard = 0;
  while (m.isMoving && guard++ < 1000) {
    m.step();
  }
}

void main() {
  setUpAll(initializePhysics);

  test('처음 판: 편마다 8알, 판 안, 겹치지 않음', () {
    final m = Match(const MatchConfig(mode: MatchMode.twoPlayer));
    expect(m.alive(0), 8);
    expect(m.alive(1), 8);
    for (final a in m.table.stones) {
      expect(a.position.x.abs(), lessThan(PhysicsConstants.halfBoard));
      for (final b in m.table.stones) {
        if (identical(a, b)) continue;
        expect(
          a.position.distanceTo(b.position),
          greaterThan(2 * PhysicsConstants.stoneRadius),
        );
      }
    }
    m.dispose();
  });

  test('한 수가 끝나면 차례가 바뀐다', () {
    final m = Match(const MatchConfig(mode: MatchMode.twoPlayer));
    final s = m.table.stones.first;
    m.shoot(s, 0, 5, 0);
    expect(m.canShoot(m.table.stones.last), isFalse, reason: '움직이는 동안은 못 쏜다');
    runToRest(m);
    expect(m.turn, 1);
    expect(m.canShoot(s), isFalse, reason: '상대 차례에 내 돌은 못 쏜다');
    m.dispose();
  });

  test('상대 돌이 모두 나가면 이긴다', () {
    final m = Match(const MatchConfig(mode: MatchMode.vsAi));
    for (final s in m.table.stones.where((s) => s.team == 1).skip(1)) {
      s.out = true;
      s.body.isEnabled = false;
    }
    final target = m.table.stones.firstWhere((s) => s.team == 1);
    target.body.setTransform(Vector2(0, -19.5), target.body.rotation);
    final me = m.table.stones.firstWhere((s) => s.team == 0);
    me.body.setTransform(Vector2(0, -16), me.body.rotation);
    m.shoot(me, -math.pi / 2, 80, -1);
    runToRest(m);
    expect(target.out, isTrue);
    expect(m.winner, 0);
    expect(m.isOver, isTrue);
    m.dispose();
  });

  test('끈 길이 → 세기: 10cm 이상이면 최대 120cm/s', () {
    expect(Match.dragToSpeed(5), 60);
    expect(Match.dragToSpeed(20), baseMaxSpeed);
    expect(Match.dragToSpeed(0), 0);
  });

  test('AI 점수: 상대 돌을 떨어뜨리는 수가 허공 수보다 높다', () {
    final stones = <StoneData>[
      (x: 0, y: -16, team: 1, material: 0, shape: 1, out: false),
      (x: 0, y: -19.5, team: 0, material: 0, shape: 1, out: false),
      (x: 10, y: 10, team: 0, material: 0, shape: 1, out: false),
    ];
    final good = scoreShot(stones, 0, -math.pi / 2, 80, -1, 1);
    final miss = scoreShot(stones, 0, 0, 20, 0, 1);
    expect(good, greaterThan(miss));
  });
}
