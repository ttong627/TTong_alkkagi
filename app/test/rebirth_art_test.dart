import 'dart:math' as math;

import 'package:alkkagi/game/match.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

Match make(RebirthArt art, List<Placement> layout) =>
    Match(MatchConfig(mode: MatchMode.vsAi, art: art, layout: layout));

void run(Match m, {bool Function(Match)? stop}) {
  var g = 0;
  while (m.isMoving && g++ < 3000) {
    m.step();
    if (stop != null && stop(m)) return;
  }
}

void main() {
  setUpAll(initializePhysics);
  const far = [Placement(12, -12, team: 1), Placement(-12, 12, team: 0)];

  test('마교 교주 흡성대법: 내 수에 맞은 상대 돌의 감속이 그 판 동안 ×0.7', () {
    final m = make(RebirthArt.steal, const [
      Placement(0, 6, team: 0),
      Placement(0, 0, team: 1),
      ...far,
    ]);
    final enemy = m.table.stones[1];
    m.shoot(m.table.stones[0], -math.pi / 2, 30, 0);
    run(m);
    expect(enemy.dampingScale, RebirthArt.stealScale);
    final plain = make(RebirthArt.none, const [
      Placement(0, 6, team: 0),
      Placement(0, 0, team: 1),
      ...far,
    ]);
    plain.shoot(plain.table.stones[0], -math.pi / 2, 30, 0);
    run(plain);
    expect(plain.table.stones[1].dampingScale, 1);
  });

  test('검황 이기어검: 12° 빗나가게 쳐도 앞쪽 상대 돌로 따라가 맞힌다(없으면 빗나감)', () {
    const layout = [
      Placement(0, 10, team: 0),
      Placement(0, -6, team: 1),
      ...far,
    ];
    bool hits(RebirthArt art) {
      final m = make(art, layout);
      final me = m.table.stones[0];
      m.shoot(me, -math.pi / 2 + 12 * math.pi / 180, 60, 0);
      var touched = false;
      run(
        m,
        stop: (m) {
          touched = touched || m.touchedThisTurn.contains(1);
          return touched;
        },
      );
      return touched;
    }

    expect(hits(RebirthArt.none), isFalse);
    expect(hits(RebirthArt.homing), isTrue);
  });

  test('검황 어기어석: 첫 충돌에서 분신 둘이 다른 상대 돌을 쫓는다', () {
    final m = make(RebirthArt.homing, const [
      Placement(0, 8, team: 0),
      Placement(0, 0, team: 1),
      Placement(-6, -4, team: 1),
      Placement(6, -4, team: 1),
      Placement(-12, 12, team: 0),
    ]);
    m.grantQi(0, maxQi);
    m.shoot(m.table.stones[0], -math.pi / 2, 60, 0, mode: StrikeMode.ultimate);
    var seen = false;
    run(
      m,
      stop: (m) {
        seen = seen || m.artEvents.any((e) => e.$1 == '이기어검');
        return seen;
      },
    );
    expect(seen, isTrue);
    expect(m.table.stones.where((s) => s.phantom).length, 2);
  });

  test('신승 반탄공: 상대 돌에 맞을 때 30% 안팎으로 터진다(40판)', () {
    var fired = 0;
    for (var k = 0; k < 40; k++) {
      final m = make(RebirthArt.reflect, const [
        Placement(0, 6, team: 0),
        Placement(0, -2, team: 1),
        Placement(12, -12, team: 1),
        Placement(-12, 12, team: 0),
      ]);
      // 상대 차례로 넘기기: 내 먼 돌을 살짝 친다.
      m.shoot(m.table.stones[3], 0, 1, 0);
      run(m);
      expect(m.turn, 1);
      m.shoot(m.table.stones[1], math.pi / 2, 60, 0);
      var hit = false;
      run(
        m,
        stop: (m) {
          hit = hit || m.artEvents.any((e) => e.$1 == '반탄공');
          return false;
        },
      );
      if (hit) fired++;
      m.dispose();
    }
    expect(fired, inInclusiveRange(2, 25));
  });
}
