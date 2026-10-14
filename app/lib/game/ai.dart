import 'dart:async';
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
    this.weather = 0,
    this.features = const [],
    this.rule = 0,
    this.generals = const {},
    this.jewel,
    this.errorScale = 1,
    this.powerScale = 1,
    this.blunder = 0,
    this.angleError,
    this.speedError,
  });

  /// 주면 난이도 대신 이 오차(사람 손 흉내).
  final double? angleError;
  final double? speedError;
  final int weather;

  /// 손 오차 배수([MatchConfig.aiErrorScale]).
  final double errorScale;

  /// 세기 배수([MatchConfig.aiPowerScale]).
  final double powerScale;

  /// 실수 확률([MatchConfig.aiBlunder]).
  final double blunder;

  /// 판 규칙([MatchRule.index])·장수 돌 자리(stones 의 번호 → 편)·보주 자리.
  final int rule;
  final Map<int, int> generals;
  final int? jewel;

  /// (종류, x, y, 각도).
  final List<(int, double, double, double)> features;
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
Future<AiShot> chooseAiShot(Match match, {int? seed}) async {
  final request = _requestFor(match, seed);
  AiGate._running++;
  try {
    return await compute(_choose, request);
  } finally {
    if (--AiGate._running == 0) {
      AiGate._idle?.complete();
      AiGate._idle = null;
    }
  }
}

/// AI 계산이 도는 중인가. 따로 도는 계산과 화면이 Box2D 세계 칸 표(프로세스에 하나 · 잠금 없음)를 함께 쓰므로,
/// 계산 중에는 화면 쪽에서 새 세계를 만들지 않는다(2026-10-14 점검 — 같은 칸을 집으면 앱이 꺼질 수 있다).
abstract final class AiGate {
  static int _running = 0;
  static Completer<void>? _idle;

  static bool get busy => _running > 0;

  /// 계산이 모두 끝날 때.
  static Future<void> get idle =>
      busy ? (_idle ??= Completer<void>()).future : Future<void>.value();
}

/// 같은 계산을 지금 이 자리에서(물리가 이미 준비돼 있어야 한다 · 가상 대전·시험용).
/// [search]·[angleError]·[speedError] 를 주면 그 실력으로(사람 손 흉내 — 버릇·내공 없이).
AiShot aiShotNow(
  Match match, {
  int? seed,
  Difficulty? search,
  double? angleError,
  double? speedError,
}) => _plan(
  _requestFor(
    match,
    seed,
    search: search,
    angleError: angleError,
    speedError: speedError,
  ),
);

_Request _requestFor(
  Match match,
  int? seed, {
  Difficulty? search,
  double? angleError,
  double? speedError,
}) {
  final all = match.table.stones;
  final generals = <int, int>{
    for (var i = 0; i < all.length; i++)
      if (match.isGeneral(all[i])) i: all[i].team,
  };
  final jewel = match.jewelId == null
      ? null
      : all.indexWhere((s) => s.id == match.jewelId);
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
  return _Request(
    stones,
    match.turn,
    (search ?? match.config.difficulty).index,
    match.config.arena.index,
    seed ?? DateTime.now().microsecondsSinceEpoch,
    style: (search == null ? match.config.aiStyle : AiStyle.plain).index,
    qi: match.qi(match.turn),
    martial: match.config.opponentMartial.index,
    weather: match.config.weather.index,
    features: [
      for (final f in match.table.features) (f.kind.index, f.x, f.y, f.angle),
    ],
    rule: match.rule.index,
    generals: generals,
    jewel: jewel,
    errorScale: search == null ? match.config.aiErrorScale : 1,
    powerScale: search == null ? match.config.aiPowerScale : 1,
    blunder: search == null ? match.config.aiBlunder : 0,
    angleError: angleError,
    speedError: speedError,
  );
}

/// 후보 수를 하나씩 물리로 끝까지 계산해 보고 가장 좋은 수에 오차를 섞는다.
/// 고수마다 버릇([AiStyle])이 달라 후보·고르는 법이 다르다(설계서 §16.1).
Future<AiShot> _choose(_Request r) async {
  await initializePhysics();
  return _plan(r);
}

AiShot _plan(_Request r) {
  final diff = Difficulty.values[r.difficulty];
  final arena = Arena.values[r.arena];
  final style = AiStyle.values[r.style];
  final rand = math.Random(r.seed);
  var speeds = switch (diff) {
    Difficulty.easy => [70.0],
    Difficulty.normal => [55.0, 90.0],
    Difficulty.skilled => [50.0, 80.0, 100.0],
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
  final rule = MatchRule.values[r.rule];
  final targets = <StoneData>[
    for (final s in r.stones)
      if (!s.out && s.team == 1 - r.team) s,
    // 점수전: 보주도 노린다.
    if (r.jewel case final j? when !r.stones[j].out) r.stones[j],
  ];
  if (style == AiStyle.assassin && targets.length > 2) {
    targets.sort(
      (a, b) => arena.boundary
          .edgeDistance(a.x, a.y, arena.half)
          .compareTo(arena.boundary.edgeDistance(b.x, b.y, arena.half)),
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
                weather: Weather.values[r.weather],
                features: [
                  for (final (k, x, y, a) in r.features)
                    Feature(FeatureKind.values[k], x, y, angle: a),
                ],
                rule: rule,
                generals: r.generals,
                jewel: r.jewel,
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
  } else if (r.blunder > 0 &&
      scored.length > 2 &&
      rand.nextDouble() < r.blunder) {
    // 실수: 가장 좋은 수를 놓치고 위쪽 절반 아무거나.
    best = scored[1 + rand.nextInt(math.max(1, scored.length ~/ 2))].$2;
  } else {
    best = scored.first.$2;
  }
  double jitter(double maxAbs) => (rand.nextDouble() * 2 - 1) * maxAbs;
  // 둥근 돌은 잘 안 맞는다(사람 손 흉내 [r.angleError] 에는 따로 주므로 AI 오차에만).
  final aimHard = aimHardness(r.stones, 1 - r.team);
  return AiShot(
    best.stoneId,
    best.angle +
        jitter(r.angleError ?? diff.angleError * r.errorScale * aimHard),
    best.speed *
        r.powerScale *
        (1 + jitter(r.speedError ?? diff.speedError * r.errorScale)),
    best.hit,
    mode: best.mode,
  );
}

/// 노리는 편([team])의 살아 있는 돌 모양으로 AI 방향 오차에 곱하는 배수.
///
/// 2026-10-14 형 「둥글수록 컨트롤은 어렵지만 상대가 잘 맞추지 못하고」: 둥글수록 맞히기 어렵다 —
/// 납작 ×1 · 둥근 ×1.15 · 구형 ×1.4 의 평균. [가정 — 실기기로 맞춘다]
double aimHardness(List<StoneData> stones, int team) {
  const by = {
    StoneShape.flat: 1.0,
    StoneShape.round: 1.15,
    StoneShape.sphere: 1.4,
  };
  var sum = 0.0, n = 0;
  for (final s in stones) {
    if (s.out || s.team != team) continue;
    sum += by[StoneShape.values[s.shape]]!;
    n++;
  }
  return n == 0 ? 1 : sum / n;
}

/// 한 수를 미리 계산해 점수를 매긴다. 상대 돌 장외 +10, 내 돌 장외 −12,
/// 쏜 돌이 판 가장자리에서 멀수록 조금 더 좋다. 대전장의 바닥·판 모양으로 계산한다.
/// 규칙([rule]): 장수전은 상대 장수 +60 · 내 장수 −100(반칙패), 점수전은 보주 +30.
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
  Weather weather = Weather.clear,
  List<Feature> features = const [],
  MatchRule rule = MatchRule.annihilate,
  Map<int, int> generals = const {},
  int? jewel,
}) {
  final t = Table(
    floorFactor: arena.floorFactor,
    boundary: arena.boundary,
    weather: weather,
    half: arena.half,
  );
  try {
    for (final f in features) {
      t.addFeature(f);
    }
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
    for (var i = 0; i < placed.length; i++) {
      final s = placed[i];
      if (s == null || !s.out) continue;
      if (i == jewel) {
        score += MatchRule.jewelPoints.toDouble();
        continue;
      }
      // 내 돌 −12, 상대 돌 +10, 백성 돌 −5.
      score += s.team == team ? -12 : (s.team == 2 ? -5 : 10);
      if (rule == MatchRule.general && generals.containsKey(i)) {
        score += s.team == team ? -100 : 60;
      }
    }
    final me = placed[shooter]!;
    if (!me.out) {
      score +=
          arena.boundary.edgeDistance(
            me.position.x,
            me.position.y,
            arena.half,
          ) *
          0.1;
    }
    return score;
  } finally {
    t.dispose();
  }
}
