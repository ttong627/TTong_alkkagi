import 'dart:math' as math;

import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/progress/daily.dart';
import 'package:alkkagi/progress/encounters.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/progress/quests.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-10-14 형 「일일 퀘스트와 주간 월간 년간 퀘스트를 만들어서 다양한 재료와 아이템 획득을 가능하게
// 해주고 일회용 아이템도 도입해줘」.
void main() {
  setUpAll(initializePhysics);

  test('기간 열쇠: 주는 월요일부터 · 월 · 연', () {
    // 2026-10-14 는 수요일 → 그 주 월요일 10-12.
    expect(QuestPeriod.week.keyOf('20261014'), 'w20261012');
    expect(
      QuestPeriod.week.keyOf('20261018'),
      'w20261012',
      reason: '일요일까지 같은 주',
    );
    expect(QuestPeriod.week.keyOf('20261019'), 'w20261019');
    expect(QuestPeriod.month.keyOf('20261014'), 'm202610');
    expect(QuestPeriod.year.keyOf('20261014'), 'y2026');
  });

  test('한 일을 세면 일일·주간·월간·연간이 함께 오르고, 다 하면 재료·아이템을 받는다', () {
    final p = Profile();
    Missions.record(p, Deed.win, '20261014', 10);
    final week = questPool[QuestPeriod.week]!;
    expect(Quests.progress(p, QuestPeriod.week, week[0], '20261014'), 10);
    expect(
      Quests.progress(
        p,
        QuestPeriod.year,
        questPool[QuestPeriod.year]![0],
        '20261014',
      ),
      10,
    );
    final r = Quests.claim(p, QuestPeriod.week, 0, '20261014');
    expect(r, isNotNull);
    expect(Bag.count(p, Mat.ore.key), 5);
    expect(Bag.count(p, Mat.herb.key), 3);
    expect(
      Quests.claim(p, QuestPeriod.week, 0, '20261014'),
      isNull,
      reason: '한 번만',
    );
    expect(Quests.hasClaimable(p, '20261014'), isFalse);
  });

  test('주가 바뀌면 주간은 새로 · 월간·연간은 이어서', () {
    final p = Profile();
    Missions.record(p, Deed.knock, '20261016', 30);
    Missions.record(p, Deed.knock, '20261020', 5);
    final knockW = questPool[QuestPeriod.week]![1];
    final knockM = questPool[QuestPeriod.month]![1];
    expect(Quests.progress(p, QuestPeriod.week, knockW, '20261020'), 5);
    expect(Quests.progress(p, QuestPeriod.month, knockM, '20261020'), 35);
  });

  // 2026-10-14 형 「기연이나 이벤트에서 조각을 모아서 완성하는 돌」.
  test('판마다 돌 조각 12% · 천년온옥이 가장 흔하고 태극석이 가장 드물다', () {
    final p = Profile();
    final r = math.Random(3);
    var got = 0;
    for (var i = 0; i < 20000; i++) {
      if (rollShard(p, r) != null) got++;
    }
    expect(got / 20000, closeTo(shardChance, 0.01));
    final warm = p.bag[shardKey(StoneMaterial.warmJade)]!;
    final taeg = p.bag[shardKey(StoneMaterial.taegeuk)]!;
    expect(warm, greaterThan(taeg * 3));
    expect(Bag.label(shardKey(StoneMaterial.dragonScale)), '용린석 조각');
  });

  test('일일 임무 보상에도 재료가 들어 있다', () {
    expect(missionPool.every((m) => m.reward.bag.isNotEmpty), isTrue);
  });

  test('재료로 일회용 아이템 만들기 · 모자라면 못 만듦', () {
    final p = Profile();
    expect(Bag.craft(p, Item.critCharm), isFalse);
    Bag.add(p, Mat.jade.key, 3);
    Bag.add(p, Mat.herb.key, 2);
    expect(Bag.craft(p, Item.critCharm), isTrue);
    expect(Bag.count(p, Item.critCharm.key), 1);
    expect(Bag.count(p, Mat.jade.key), 0);
    expect(p.bag.containsKey(Mat.jade.key), isFalse, reason: '0 개는 지운다');
    expect(Bag.take(p, Item.critCharm.key), isTrue);
    expect(Bag.take(p, Item.critCharm.key), isFalse);
  });

  test('가방·퀘스트는 저장했다 불러와도 그대로', () {
    final p = Profile();
    Bag.add(p, Mat.scale.key, 2);
    Missions.record(p, Deed.win, '20261014', 3);
    final q = Profile.decode(p.encode());
    expect(Bag.count(q, Mat.scale.key), 2);
    expect(
      Quests.progress(
        q,
        QuestPeriod.month,
        questPool[QuestPeriod.month]![0],
        '20261014',
      ),
      3,
    );
  });

  test('내공 단약: 내공 2칸 · 철벽 부적: 상대가 칠 동안 내 돌이 덜 밀리고, 내가 다시 치면 풀린다', () {
    Match duel() => Match(
      const MatchConfig(
        mode: MatchMode.vsAi,
        layout: [
          Placement(0, 4, team: 0),
          Placement(0, -6, team: 1),
          Placement(12, 12, team: 0),
          Placement(-12, -12, team: 1),
        ],
      ),
    );
    final m = duel();
    m.addQi(0, 2);
    expect(m.qi(0), 2);

    double pushed({required bool guard}) {
      final g = duel();
      // 내가 먼저 한 수(멀리 있는 돌로 헛친다) — 그다음 상대 차례.
      g.shoot(g.table.stones[2], math.pi / 4, 5, 0);
      var guardSteps = 0;
      while (g.isMoving && guardSteps++ < 2000) {
        g.step();
      }
      if (guard) g.guard(0);
      final mine = g.table.stones[0];
      final start = mine.position.clone();
      g.shoot(g.table.stones[1], math.pi / 2, 60, 0);
      guardSteps = 0;
      while (g.isMoving && guardSteps++ < 2000) {
        g.step();
      }
      final d = mine.out ? double.infinity : (mine.position - start).length;
      if (guard) {
        expect(g.guardTeam, 0);
        g.shoot(g.table.stones[2], 0, 3, 0);
        expect(g.guardTeam, isNull, reason: '내가 다시 치면 풀린다');
        expect(mine.dampingScale, closeTo(1, 1e-9));
      }
      g.dispose();
      return d;
    }

    expect(pushed(guard: true), lessThan(pushed(guard: false) * 0.7));
    m.dispose();
  });
}
