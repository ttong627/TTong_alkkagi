import 'dart:math' as math;

import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/story/chapters.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

/// 내 돌(0,4)과 상대 돌(0,−4)을 마주 보게 놓은 고수전. 상대 돌 하나를 더 멀리 둬서 판이 안 끝나게.
Match duel({bool qiClash = true}) => Match(
  MatchConfig(
    mode: MatchMode.vsAi,
    qiClash: qiClash,
    layout: const [
      Placement(0, 4, team: 0),
      Placement(0, -4, team: 1),
      Placement(10, -12, team: 1),
      Placement(-10, 12, team: 0),
    ],
  ),
);

void main() {
  setUpAll(initializePhysics);

  group('내공 겨루기 (설계서 §4)', () {
    test('연타 수 차이 → 반발 ±20%, 초당 15회 넘으면 무효', () {
      expect(QiClash.swing(30, 30), 0);
      expect(QiClash.swing(30, 15), closeTo(0.1, 1e-9));
      expect(QiClash.swing(0, 27), closeTo(-0.2, 1e-9));
      expect(QiClash.swing(45, 0), closeTo(0.2, 1e-9));
      // 46회(초당 15.3회)는 무효 → 0 회로 친다.
      expect(QiClash.swing(46, 20), closeTo(-0.2, 1e-9));
      expect(QiClash.swing(0, 0), 0);
    });

    test('고수의 연타 수: 쉬움 15~21 · 보통 24~30 · 어려움 33~39', () {
      final r = math.Random(1);
      for (var i = 0; i < 200; i++) {
        expect(QiClash.aiTaps(Difficulty.easy, r), inInclusiveRange(15, 21));
        expect(QiClash.aiTaps(Difficulty.normal, r), inInclusiveRange(24, 30));
        expect(QiClash.aiTaps(Difficulty.hard, r), inInclusiveRange(33, 39));
      }
    });

    test('정면으로 세게 부딪히면 물리를 멈추고 기다린다 → 결과를 넣으면 이어 간다', () {
      final m = duel();
      m.shoot(m.table.stones[0], -math.pi / 2, 90, 0);
      var guard = 0;
      while (m.isMoving && m.clash == null && guard++ < 600) {
        m.step();
      }
      expect(m.clash, isNotNull);
      final (mine, theirs) = m.clash!;
      expect(m.table.stones.firstWhere((s) => s.id == mine).team, 0);
      expect(m.table.stones.firstWhere((s) => s.id == theirs).team, 1);
      // 기다리는 동안은 한 걸음도 안 간다.
      final at = m.table.stones[1].position.clone();
      expect(m.step(), isFalse);
      expect(m.table.stones[1].position, at);
      final before = m.table.stones[1].velocity.length;
      final d = m.resolveClash(45, 0);
      expect(d, closeTo(0.2, 1e-9));
      expect(m.table.stones[1].velocity.length, closeTo(before * 1.2, 1e-3));
      expect(m.clash, isNull);
      guard = 0;
      while (m.isMoving && guard++ < 2000) {
        m.step();
      }
      expect(m.isMoving, isFalse);
    });

    test('고수전이 아니거나 빗맞으면 겨루지 않는다', () {
      final plain = duel(qiClash: false);
      plain.shoot(plain.table.stones[0], -math.pi / 2, 90, 0);
      var guard = 0;
      while (plain.isMoving && guard++ < 2000) {
        plain.step();
        expect(plain.clash, isNull);
      }
      // 비스듬히(약 35°) 스치면 정면이 아니다.
      final glance = Match(
        const MatchConfig(
          mode: MatchMode.vsAi,
          qiClash: true,
          layout: [
            Placement(0, 4, team: 0),
            Placement(1.25, -4, team: 1),
            Placement(10, -12, team: 1),
            Placement(-10, 12, team: 0),
          ],
        ),
      );
      glance.shoot(glance.table.stones[0], -math.pi / 2, 90, 0);
      guard = 0;
      var touched = false;
      while (glance.isMoving && guard++ < 2000) {
        glance.step();
        if (glance.table.impacts.isNotEmpty) touched = true;
        expect(glance.clash, isNull);
      }
      expect(touched, isTrue);
    });
  });

  test('일타쌍피: 내가 한 수에 2개 떨어뜨리면 엽전 10×2', () {
    final m = Match(
      const MatchConfig(
        mode: MatchMode.vsAi,
        layout: [
          Placement(0, 6, team: 0),
          Placement(-0.9, -14.5, team: 1),
          Placement(0.9, -14.5, team: 1),
          Placement(12, -12, team: 1),
          Placement(-12, 12, team: 0),
        ],
      ),
    );
    m.shoot(m.table.stones[0], -math.pi / 2, 120, 0);
    var guard = 0;
    while (m.isMoving && guard++ < 3000) {
      m.step();
    }
    expect(m.lastShooter, 0);
    expect(m.lastKnocked, greaterThanOrEqualTo(2));
    expect(m.bonusCoins, Match.multiKnockCoin * m.lastKnocked);
  });

  test('강호행 판마다 고수 한마디 6줄 · 캐릭터마다 첫 대사', () {
    for (final s in campaign) {
      expect(s.quips.length, 6, reason: s.id);
    }
    expect(heroGreeting('석두', '근력형 · 탄지 파워 +10%'), startsWith('「근력형」 석두라'));
    expect(heroGreeting('청명', '집중형 · 어기'), startsWith('「집중형」 청명이라'));
  });
}
