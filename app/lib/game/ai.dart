import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/foundation.dart';

import 'arena.dart';
import 'match.dart';

/// AI 가 고른 한 수.
class AiShot {
  const AiShot(
    this.stoneId,
    this.angle,
    this.speed,
    this.hit, {
    this.mode = StrikeMode.plain,
  });
  final int stoneId;
  final double angle;
  final double speed;
  final double hit;

  /// 내공을 쓰는 버릇(맹주·숙적)이면 내공 타격.
  final StrikeMode mode;
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
  _Request(
    this.stones,
    this.team,
    this.difficulty,
    this.arena,
    this.seed, {
    this.style = 0,
    this.qi = 0,
    this.martial = 0,
  });
  final List<StoneData> stones;
  final int team;
  final int difficulty;
  final int arena;
  final int seed;
  final int style;
  final int qi;
  final int martial;
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
      style: match.config.aiStyle.index,
      qi: match.qi(match.turn),
      martial: match.config.opponentMartial.index,
    ),
  );
}

/// 후보 수를 하나씩 물리로 끝까지 계산해 보고 가장 좋은 수에 오차를 섞는다.
/// 고수마다 버릇([AiStyle])이 달라 후보·고르는 법이 다르다(설계서 §16.1).
Future<AiShot> _choose(_Request r) async {
  await initializePhysics();
  final diff = Difficulty.values[r.difficulty];
  final arena = Arena.values[r.arena];
  final style = AiStyle.values[r.style];
  final rand = math.Random(r.seed);
  var speeds = switch (diff) {
    Difficulty.easy => [70.0],
    Difficulty.normal => [55.0, 90.0],
    Difficulty.hard => [45.0, 70.0, 100.0],
  };
  var hits = diff == Difficulty.hard ? [0.0, -1.0] : [0.0];
  var offsets = [0.0];
  switch (style) {
    case AiStyle.ram:
      speeds = [115.0];
      hits = [0.0];
    case AiStyle.spinner:
      speeds = [60.0, 90.0];
      hits = [-1.0, 0.0];
    case AiStyle.calculator:
      speeds = [50.0, 80.0, 110.0];
      hits = [0.0, -1.0];
      offsets = [0.0, -0.04, 0.04];
    case AiStyle.plain || AiStyle.teacher || AiStyle.assassin || AiStyle.master:
      break;
  }
  // 맹주·숙적은 내공이 있으면 내공 타격을 고려한다.
  final useInner = style == AiStyle.master && r.qi >= 1;
  final martial = Technique.values[r.martial];

  // 자객: 판 가장자리에 가까운 상대 돌 2개만 노린다.
  final targets = <StoneData>[
    for (final s in r.stones)
      if (!s.out && s.team != r.team) s,
  ];
  if (style == AiStyle.assassin && targets.length > 2) {
    targets.sort(
      (a, b) => arena.boundary
          .edgeDistance(a.x, a.y)
          .compareTo(arena.boundary.edgeDistance(b.x, b.y)),
    );
    targets.removeRange(2, targets.length);
  }

  final scored = <(double, AiShot)>[];
  for (var i = 0; i < r.stones.length; i++) {
    final me = r.stones[i];
    if (me.out || me.team != r.team) continue;
    for (final tg in targets) {
      final base = math.atan2(tg.y - me.y, tg.x - me.x);
      for (final off in offsets) {
        final angle = base + off;
        for (final sp in speeds) {
          for (final hit in hits) {
            for (final inner in useInner ? [false, true] : [false]) {
              var score = scoreShot(
                r.stones,
                i,
                angle,
                sp,
                hit,
                r.team,
                arena: arena,
                inner: inner,
                technique: inner ? martial : Technique.none,
              );
              if (style == AiStyle.ram) {
                // 통통: 가까운 돌부터.
                final d = math.sqrt(
                  (tg.x - me.x) * (tg.x - me.x) + (tg.y - me.y) * (tg.y - me.y),
                );
                score -= d * 0.05;
              }
              // 내공은 아껴 쓴다: 얻는 게 확실할 때만.
              if (inner) score -= 4;
              scored.add((
                score,
                AiShot(
                  i,
                  angle,
                  sp,
                  hit,
                  mode: inner ? StrikeMode.inner : StrikeMode.plain,
                ),
              ));
            }
          }
        }
      }
    }
  }
  scored.sort((a, b) => b.$1.compareTo(a.$1));
  AiShot best;
  if (scored.isEmpty) {
    best = AiShot(
      r.stones.indexWhere((s) => !s.out && s.team == r.team),
      math.pi / 2,
      60,
      0,
    );
  } else if (style == AiStyle.teacher &&
      scored.length > 1 &&
      rand.nextDouble() < 0.4) {
    // 촌장: 가르치는 사람이라 가장 좋은 수를 자주 피한다.
    best = scored[1 + rand.nextInt(math.min(4, scored.length - 1))].$2;
  } else {
    best = scored.first.$2;
  }
  double jitter(double maxAbs) => (rand.nextDouble() * 2 - 1) * maxAbs;
  return AiShot(
    best.stoneId,
    best.angle + jitter(diff.angleError),
    best.speed * (1 + jitter(diff.speedError)),
    best.hit,
    mode: best.mode,
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
  bool inner = false,
  Technique technique = Technique.none,
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
  t.shoot(
    placed[shooter]!,
    angle,
    speed,
    hit,
    inner: inner,
    technique: technique,
  );
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
