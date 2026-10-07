import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/foundation.dart';

import 'arena.dart';
import 'match.dart';

/// AI 가 고른 한 수.
class AiShot {
  const AiShot(this.stoneId, this.angle, this.speed, this.hit);
  final int stoneId;
  final double angle;
  final double speed;
  final double hit;
}

/// 판 상태를 다른 isolate 로 넘기기 위한 값.
typedef StoneData = ({
  double x,
  double y,
  int team,
  int material,
  int shape,
  bool out,
});

class _Request {
  _Request(this.stones, this.team, this.difficulty, this.arena, this.seed);
  final List<StoneData> stones;
  final int team;
  final int difficulty;
  final int arena;
  final int seed;
}

/// AI 가 둘 수를 고른다. 휴대폰에서는 화면이 멈추지 않게 따로 계산한다.
Future<AiShot> chooseAiShot(Match match, {int? seed}) {
  final stones = [
    for (final s in match.table.stones)
      (
        x: s.position.x,
        y: s.position.y,
        team: s.team,
        material: s.material.index,
        shape: s.shape.index,
        out: s.out,
      ),
  ];
  return compute(
    _choose,
    _Request(
      stones,
      match.turn,
      match.config.difficulty.index,
      match.config.arena.index,
      seed ?? DateTime.now().microsecondsSinceEpoch,
    ),
  );
}

/// 후보 수를 하나씩 물리로 끝까지 계산해 보고 가장 좋은 수에 오차를 섞는다.
Future<AiShot> _choose(_Request r) async {
  await initializePhysics();
  final diff = Difficulty.values[r.difficulty];
  final arena = Arena.values[r.arena];
  final rand = math.Random(r.seed);
  final speeds = switch (diff) {
    Difficulty.easy => [70.0],
    Difficulty.normal => [55.0, 90.0],
    Difficulty.hard => [45.0, 70.0, 100.0],
  };
  final hits = diff == Difficulty.hard ? [0.0, -1.0] : [0.0];

  AiShot? best;
  var bestScore = double.negativeInfinity;
  for (var i = 0; i < r.stones.length; i++) {
    final me = r.stones[i];
    if (me.out || me.team != r.team) continue;
    for (final tg in r.stones) {
      if (tg.out || tg.team == r.team) continue;
      final angle = math.atan2(tg.y - me.y, tg.x - me.x);
      for (final sp in speeds) {
        for (final hit in hits) {
          final score = scoreShot(
            r.stones,
            i,
            angle,
            sp,
            hit,
            r.team,
            arena: arena,
          );
          if (score > bestScore) {
            bestScore = score;
            best = AiShot(i, angle, sp, hit);
          }
        }
      }
    }
  }
  best ??= AiShot(
    r.stones.indexWhere((s) => !s.out && s.team == r.team),
    math.pi / 2,
    60,
    0,
  );
  double jitter(double maxAbs) => (rand.nextDouble() * 2 - 1) * maxAbs;
  return AiShot(
    best.stoneId,
    best.angle + jitter(diff.angleError),
    best.speed * (1 + jitter(diff.speedError)),
    best.hit,
  );
}

/// 한 수를 미리 계산해 점수를 매긴다. 상대 돌 장외 +10, 내 돌 장외 −12,
/// 쏜 돌이 판 가장자리에서 멀수록 조금 더 좋다. 대전장의 바닥·판 모양으로 계산한다.
double scoreShot(
  List<StoneData> stones,
  int shooter,
  double angle,
  double speed,
  double hit,
  int team, {
  Arena arena = Arena.turtleMarket,
}) {
  final t = Table(floorFactor: arena.floorFactor, boundary: arena.boundary);
  final placed = <Stone?>[];
  for (final s in stones) {
    placed.add(
      s.out
          ? null
          : t.addStone(
              s.x,
              s.y,
              material: StoneMaterial.values[s.material],
              shape: StoneShape.values[s.shape],
              team: s.team,
            ),
    );
  }
  t.shoot(placed[shooter]!, angle, speed, hit);
  t.runTurn();
  var score = 0.0;
  for (final s in placed) {
    if (s == null || !s.out) continue;
    score += s.team == team ? -12 : 10;
  }
  final me = placed[shooter]!;
  if (!me.out) {
    score += arena.boundary.edgeDistance(me.position.x, me.position.y) * 0.1;
  }
  t.dispose();
  return score;
}
