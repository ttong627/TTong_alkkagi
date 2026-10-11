import 'dart:math' as math;

import 'package:alkkagi/progress/encounters.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('기연 확률: 10만 번 뽑아 표의 확률과 ±5% 안 (설계서 §13 단계 4 기준)', () {
    final r = math.Random(20261011);
    final counts = {for (final e in Encounter.values) e: 0};
    const n = 100000;
    // 확률이 아주 낮아 10만 번이면 기대값이 100~500 이라 ±5% 는 운에 크게 흔들린다.
    // 그래서 같은 시험을 20번(200만 번) 모아 비율을 본다.
    for (var k = 0; k < 20 * n; k++) {
      final e = rollEncounter(Profile(), r, now: 0);
      if (e != null) counts[e] = counts[e]! + 1;
    }
    for (final e in Encounter.values) {
      final want = e.chance * 20 * n;
      expect(
        (counts[e]! - want).abs() / want,
        lessThan(0.05),
        reason: '${e.label}: ${counts[e]} / 기대 $want',
      );
    }
  });

  test('물음표 칸은 5배', () {
    final r = math.Random(7);
    var hits = 0;
    const n = 200000;
    for (var k = 0; k < n; k++) {
      if (rollEncounter(Profile(), r, now: 0, boost: 5) != null) hits++;
    }
    expect(hits / n, closeTo(0.008 * 5, 0.002));
  });

  test('영약은 내공 +100 · 기인방은 10분 열리고 진열 3개에 효과가 붙어 있다', () {
    final p = Profile();
    final r = math.Random(1);
    var gotElixir = false, gotShop = false;
    for (var i = 0; i < 100000 && !(gotElixir && gotShop); i++) {
      final before = p.naegong;
      final e = rollEncounter(p, r, now: 1000);
      if (e == Encounter.elixir) {
        expect(p.naegong - before, 100);
        gotElixir = true;
      }
      if (e == Encounter.legendary) {
        expect(p.legendaryOpen(1000), isTrue);
        expect(p.legendaryOpen(1000 + 10 * 60 * 1000), isFalse);
        expect(p.legendary.length, 3);
        for (final x in p.legendary) {
          expect(legendaryPerks, contains(x.split('|').last));
        }
        gotShop = true;
      }
    }
    expect(gotElixir && gotShop, isTrue);
  });

  test('기인방에서 사면 물건과 효과를 함께 얻고 진열에서 빠진다', () {
    final p = Profile()..coins = 1000;
    p.legendary.addAll(['재질:ice|꺾기+1', '비급|내공 아낌']);
    expect(buyLegendary(p, '재질:ice|꺾기+1', 400), isTrue);
    expect(p.materials, contains(StoneMaterial.ice));
    expect(p.perks, contains('꺾기+1'));
    expect(p.steersTotal, 2);
    expect(p.coins, 600);
    expect(buyLegendary(p, '재질:ice|꺾기+1', 1), isFalse, reason: '이미 산 것');
    expect(buyLegendary(p, '비급|내공 아낌', 9999), isFalse, reason: '엽전 모자람');
    expect(legendaryPrice(1000, math.Random(3)), inInclusiveRange(300, 500));
    expect(legendaryPrice(0, math.Random(3)), 50);
  });

  test('은둔 고수: 숨은 캐릭터 둘을 차례로, 다 있으면 비급', () {
    final p = Profile();
    final r = math.Random(5);
    hermitReward(p, r);
    hermitReward(p, r);
    expect(p.heroes, containsAll([Fighter.chwiseon, Fighter.mukgaek]));
    hermitReward(p, r);
    expect(p.secretArts, 1);
  });
}
