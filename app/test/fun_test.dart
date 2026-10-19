import 'dart:math' as math;

import 'package:alkkagi/game/arena.dart';
import 'package:alkkagi/game/match.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-10-20 형 「재미적 요소」: 뽀록·아슬아슬 · 연타 · 방향 보정 · 대전장 담장·장애물.
void main() {
  void settle(Match m) {
    var guard = 0;
    while (m.isMoving && guard++ < 4000) {
      m.step();
    }
  }

  test('가장자리 운: 확률 1 이면 가장자리에 선 돌이 기우뚱 떨어지고, 0 이면 버틴다', () {
    for (final chance in [1.0, 0.0]) {
      final m = Match(
        MatchConfig(
          mode: MatchMode.practice,
          arena: Arena.dustyYard,
          edgeTipChance: chance,
        ),
      );
      final me = m.table.stones.firstWhere((s) => s.team == 0);
      // 가장자리 바로 앞에 멈추도록 아주 약하게 민다: 돌을 가장자리 근처로 옮겨 놓고 살짝.
      me.body.setTransform(Vector2(0, 20.8), me.body.rotation);
      m.shoot(me, math.pi / 2, 0.3, 0);
      settle(m);
      if (me.out && m.luckEvents.isEmpty) {
        // 너무 세서 그냥 나간 경우(운과 무관) — 이 시험의 전제가 깨짐.
        fail('돌이 운 없이 나갔다');
      }
      if (m.luckEvents.isNotEmpty) {
        expect(m.luckEvents.first.tipped, chance == 1.0);
        expect(me.out, chance == 1.0);
      }
      m.dispose();
    }
  });

  test('방향 보정: 상대 돌에서 4도 안쪽이면 반만 꺾고, 멀면 그대로', () {
    final m = Match(const MatchConfig(mode: MatchMode.vsAi));
    final me = m.table.stones.firstWhere((s) => s.team == 0);
    final foe = m.table.stones.firstWhere((s) => s.team == 1);
    final d = foe.position - me.position;
    final exact = math.atan2(d.y, d.x);
    expect(m.nudgeAngle(me, exact + 0.04), closeTo(exact + 0.02, 1e-3));
    // 상대 돌이 없는 쪽(뒤)으로 겨누면 그대로.
    expect(m.nudgeAngle(me, exact + math.pi), exact + math.pi);
    m.dispose();
  });

  test('대전장마다 담장이 있고, 묘수풀이에는 없다', () {
    for (final a in Arena.values) {
      final kinds = arenaLayout(a).map((f) => f.kind).toSet();
      expect(kinds, contains(FeatureKind.fence), reason: a.name);
      expect(kinds, contains(FeatureKind.pillar), reason: a.name);
    }
    final puzzle = Match(
      const MatchConfig(mode: MatchMode.practice, layout: []),
    );
    expect(
      puzzle.table.features.where((f) => f.kind == FeatureKind.fence),
      isEmpty,
    );
    puzzle.dispose();
  });
}
