import 'dart:math' as math;

import 'package:alkkagi/game/ai.dart';
import 'package:alkkagi/game/match.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

void runToRest(Match m) {
  var guard = 0;
  while (m.isMoving && guard++ < 2000) {
    m.step();
  }
}

/// 돌을 판 밖으로 치운다(판 위에 없는 것으로).
void remove(Stone s) {
  s.out = true;
  s.body.isEnabled = false;
}

/// [s] 를 판 아래 가장자리 바로 앞에 두고 아래로 세게 쳐서 떨어뜨린다(제 돌 잃기).
void shootOff(Match m, Stone s) {
  s.body.setTransform(Vector2(-14, 19.5), s.body.rotation);
  m.shoot(s, math.pi / 2, 90, 0);
  runToRest(m);
}

/// [shooter] 로 [target] 을 위쪽 가장자리 밖으로 친다.
void knock(Match m, Stone shooter, Stone target) {
  target.body.setTransform(Vector2(10, -19.5), target.body.rotation);
  shooter.body.setTransform(Vector2(10, -16), shooter.body.rotation);
  m.shoot(shooter, -math.pi / 2, 80, -1);
  runToRest(m);
}

/// 아무것도 안 건드리는 약한 수.
void tap(Match m, Stone s) {
  m.shoot(s, s.team == 0 ? math.pi / 2 : -math.pi / 2, 4, 0);
  runToRest(m);
}

Stone first(Match m, int team, {bool general = false}) => m.table.stones
    .firstWhere((s) => s.team == team && !s.out && m.isGeneral(s) == general);

void main() {
  setUpAll(initializePhysics);

  group('장수전', () {
    test('편마다 장수 하나 · 상대 장수를 떨어뜨리면 남은 돌이 많아도 이긴다', () {
      final m = Match(
        const MatchConfig(mode: MatchMode.twoPlayer, rule: MatchRule.general),
      );
      expect(m.generals.length, 2);
      expect(m.table.stones.where(m.isGeneral).length, 2);
      final theirs = m.table.stones.firstWhere(
        (s) => s.team == 1 && m.isGeneral(s),
      );
      knock(m, first(m, 0), theirs);
      expect(theirs.out, isTrue);
      expect(m.alive(1), 7, reason: '돌은 아직 7개 남음');
      expect(m.winner, 0);
      m.dispose();
    });

    test('제 장수를 떨어뜨리면(제 수라도) 진다', () {
      final m = Match(
        const MatchConfig(mode: MatchMode.vsAi, rule: MatchRule.general),
      );
      shootOff(m, first(m, 0, general: true));
      expect(m.winner, 1);
      m.dispose();
    });

    test('보통 돌만 잃으면 판은 이어진다', () {
      final m = Match(
        const MatchConfig(mode: MatchMode.vsAi, rule: MatchRule.general),
      );
      shootOff(m, first(m, 0));
      expect(m.isOver, isFalse);
      expect(m.turn, 1);
      m.dispose();
    });
  });

  group('점수전', () {
    test('가운데 보주 · 상대 돌 10점 · 제 돌 잃으면 상대 10점', () {
      final m = Match(
        const MatchConfig(mode: MatchMode.twoPlayer, rule: MatchRule.score),
      );
      final jewel = m.table.stones.firstWhere((s) => s.id == m.jewelId);
      expect(jewel.team, MatchRule.jewelTeam);
      expect(m.canShoot(jewel), isFalse, reason: '보주는 아무도 칠 수 없다');
      knock(m, first(m, 0), first(m, 1));
      expect(m.scores, [10, 0]);
      expect(m.turn, 1);
      shootOff(m, first(m, 1));
      expect(m.scores, [20, 0], reason: '편 1 이 제 돌을 잃어 편 0 이 10점');
      m.dispose();
    });

    test('보주를 떨어뜨리면 30점 · 먼저 60점이면 이긴다', () {
      final m = Match(
        const MatchConfig(mode: MatchMode.twoPlayer, rule: MatchRule.score),
      );
      final jewel = m.table.stones.firstWhere((s) => s.id == m.jewelId);
      knock(m, first(m, 0), jewel);
      expect(jewel.out, isTrue);
      // 보주 30 + (같이 떨어진 상대 돌이 있으면 하나에 10).
      expect(m.scores[0], MatchRule.jewelPoints + 10 * m.lastKnocked);
      // 편 1 이 제 돌을 잃을 때마다 편 0 이 10점 — 60점이 되는 순간 끝.
      while (!m.isOver) {
        shootOff(m, first(m, 1));
        if (!m.isOver) tap(m, first(m, 0));
      }
      expect(m.scores[0], greaterThanOrEqualTo(MatchRule.scoreTarget));
      expect(m.scores[0], lessThan(MatchRule.scoreTarget + 10));
      expect(m.winner, 0);
      m.dispose();
    });
  });

  group('여섯 수 승부', () {
    test('한 사람 여섯 수 · 다 치면 남은 돌이 많은 쪽 · 같으면 비김', () {
      final m = Match(
        const MatchConfig(mode: MatchMode.twoPlayer, rule: MatchRule.shots),
      );
      for (var i = 0; i < MatchRule.shotLimit; i++) {
        expect(m.isOver, isFalse);
        tap(m, first(m, 0));
        tap(m, first(m, 1));
      }
      expect(m.shotsTaken, [6, 6]);
      expect(m.isDraw, isTrue);
      m.dispose();
    });

    test('남은 돌이 많은 쪽이 이긴다', () {
      final m = Match(
        const MatchConfig(mode: MatchMode.twoPlayer, rule: MatchRule.shots),
      );
      shootOff(m, first(m, 0)); // 편 0 이 하나 잃음.
      for (var i = 0; i < MatchRule.shotLimit; i++) {
        if (m.turn == 1) tap(m, first(m, 1));
        if (m.isOver) break;
        if (m.turn == 0) tap(m, first(m, 0));
      }
      if (!m.isOver) tap(m, first(m, 1));
      expect(m.winner, 1);
      m.dispose();
    });
  });

  test('연습·묘수 판은 규칙을 골라도 늘 기본', () {
    final m = Match(
      const MatchConfig(mode: MatchMode.practice, rule: MatchRule.general),
    );
    expect(m.rule, MatchRule.annihilate);
    expect(m.generals, isEmpty);
    m.dispose();
  });

  test('AI 는 제 장수를 떨어뜨리는 수를 크게 꺼리고 상대 장수는 노린다', () {
    // 내 장수(0번)가 아래 가장자리 앞, 상대 장수(2번)가 위 가장자리 앞.
    final stones = <StoneData>[
      (x: 0, y: 19.5, team: 1, material: 0, shape: 0, out: false),
      (x: 0, y: 16, team: 1, material: 0, shape: 0, out: false),
      (x: 0, y: -19.5, team: 0, material: 0, shape: 0, out: false),
      (x: 0, y: -16, team: 1, material: 0, shape: 0, out: false),
    ];
    final generals = {0: 1, 2: 0};
    // 편 1 이 1번 돌로 아래로 세게: 제 장수(0번)를 민다.
    final self = scoreShot(
      stones,
      1,
      math.pi / 2,
      90,
      0,
      1,
      rule: MatchRule.general,
      generals: generals,
    );
    // 편 1 이 3번 돌로 위로: 상대 장수(2번)를 떨어뜨린다.
    final kill = scoreShot(
      stones,
      3,
      -math.pi / 2,
      80,
      -1,
      1,
      rule: MatchRule.general,
      generals: generals,
    );
    expect(self, lessThan(-50));
    expect(kill, greaterThan(50));
  });

  test('규칙 판에서도 AI 가 제 돌로 둘 수를 고른다(장수전·점수전·여섯 수)', () async {
    for (final rule in [MatchRule.general, MatchRule.score, MatchRule.shots]) {
      final m = Match(
        MatchConfig(
          mode: MatchMode.vsAi,
          rule: rule,
          difficulty: Difficulty.easy,
        ),
      );
      tap(m, first(m, 0));
      expect(m.turn, 1);
      final shot = await chooseAiShot(m, seed: 7);
      final s = m.table.stones[shot.stoneId];
      expect(s.team, 1, reason: rule.label);
      expect(m.canShoot(s), isTrue, reason: rule.label);
      m.dispose();
    }
  });
}
