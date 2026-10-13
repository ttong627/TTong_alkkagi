import 'dart:math' as math;
import 'dart:ui';

import 'package:alkkagi/game/fx.dart';
import 'package:alkkagi/game/match.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

/// 상대 돌을 판 끝에 두고 세게 쳐서 장외시킨다. 연출이 남긴 (조각 수, 떨어지는 돌 수).
(int, int) knockOut({required bool critical}) {
  final m = Match(
    const MatchConfig(
      mode: MatchMode.vsAi,
      layout: [
        Placement(0, -14, team: 0),
        Placement(0, -18.5, team: 1),
        Placement(12, 12, team: 1),
        Placement(-12, 12, team: 0),
      ],
    ),
  );
  final fx = BattleFx();
  m.shoot(m.table.stones[0], -math.pi / 2, 120, 0, critical: critical);
  var guard = 0;
  while (m.isMoving && guard++ < 2000) {
    final wasOut = {
      for (final s in m.table.stones)
        if (s.out) s.id,
    };
    m.step();
    fx.onStep(m, wasOut);
  }
  // 상대 돌(편 1)이 떨어진 것만 센다 — 내 돌도 기세에 밀려 따라 나갈 수 있다.
  final r = (fx.shards.length, fx.falls.where((f) => f.team == 1).length);
  m.dispose();
  return r;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializePhysics);

  // 2026-10-14 형 「크리티컬 기능도 넣어줘서 상대 돌이 떨어지는 게 아니라 박살나면서 분해되는 그래픽과 액션」.
  test('회심으로 상대 돌을 장외시키면 떨어지는 대신 조각 8개로 박살난다', () {
    final (shards, falls) = knockOut(critical: true);
    expect(shards, 8);
    expect(falls, 0);
  });

  test('회심이 아니면 예전처럼 판 밖으로 떨어진다', () {
    final (shards, falls) = knockOut(critical: false);
    expect(shards, 0);
    expect(falls, greaterThanOrEqualTo(1));
  });

  test('조각은 0.9초 뒤 사라진다', () {
    final fx = BattleFx();
    fx.shards.add(
      Shard(
        Offset.zero,
        const Offset(10, 0),
        0,
        1,
        0.5,
        const Color(0xFFFFFFFF),
        const Color(0xFF000000),
      ),
    );
    fx.update(0.5);
    expect(fx.shards, hasLength(1));
    fx.update(0.5);
    expect(fx.shards, isEmpty);
  });
}
