import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/progress/daily.dart';
import 'package:alkkagi/progress/encounters.dart';
import 'package:alkkagi/progress/modes.dart';
import 'package:alkkagi/story/campaign.dart' as c;
import 'package:alkkagi/story/chapters.dart';

void main() {
  test('econ', () {
    // 1 mission sets
    final sets = <String>{};
    var d = DateTime(2026, 10, 1);
    final seq = <String>[];
    for (var i = 0; i < 62; i++) {
      final day = today(d);
      final ms = Missions.of(day).map((m) => m.deed.name).toList()..sort();
      sets.add(ms.join(','));
      if (i < 35)
        seq.add('${day.substring(6)}:${ms.contains('win') ? 'A' : 'B'}');
      d = d.add(const Duration(days: 1));
    }
    print('mission sets: $sets');
    print(seq.join(' '));
    // 2 attendance flip
    final p = Profile();
    var claims = 0;
    for (var i = 0; i < 14; i++) {
      if (Attendance.claim(p, i.isEven ? '20261011' : '20261012') != null)
        claims++;
    }
    print(
      'attendance flip claims=$claims coins=${p.coins} tp=${p.trainingPoints} silver=${p.silver} tokens=${p.tokens}',
    );
    // 3 training flip
    final q = Profile();
    for (var i = 0; i < 10; i++) {
      for (var h = 0; h < 30; h++) {
        q.trainHit(i.isEven ? '20261011' : '20261012');
      }
    }
    print('training flip 10x30: naegong=${q.naegong} stage=${q.stage}');
    // 4 rival replay tokens
    final r = Profile()..done.addAll(['c1', 'c2']);
    final r1 = campaign.firstWhere((s) => s.id == 'r1');
    for (var i = 0; i < 10; i++) {
      c.Campaign.finish(r, r1, won: true);
    }
    print('r1 x10: tokens=${r.tokens} coins=${r.coins}');
    final c1 = campaign.first;
    print(
      'replay coins: ${[for (final s in campaign) '${s.id}:${s.coins(first: true)}/${s.coins(first: false)}']}',
    );
    print('max stars=${campaign.length * 3}');
    // 6 days to stages at 30/day
    for (var i = 1; i < naegongStages.length; i++) {
      final need = naegongStages[i].$2;
      print(
        'stage ${i + 1} ${naegongStages[i].$1}: day ${(need / 90).ceil() + (need % 90 == 0 ? 1 : 0)} (hits day1 needed: ${need <= 90 ? (need / 3).ceil() : 30 + ((need - 90) / 0.1).ceil()})',
      );
    }
    var tot = 0;
    for (var l = 0; l < 20; l++) {
      tot += statCost(l);
    }
    print('stat total per stat=$tot all=${tot * 3}');
    // arena pot
    var pot = 0;
    final pots = <int>[];
    for (var s = 0; s < 8; s++) {
      pot += ArenaRules.winReward(s);
      pots.add(pot);
    }
    print('arena pots $pots');
    // legendary min price
    final lp = Profile()..coins = 150;
    final rnd = math.Random(1);
    lp.legendary.addAll(legendaryStock(lp, rnd));
    final price = legendaryPrice(lp.coins, rnd);
    var bought = 0;
    for (final e in List.of(lp.legendary)) {
      if (buyLegendary(lp, e, price)) bought++;
    }
    print(
      'legendary at 150 coins price=$price bought=$bought items=${lp.materials} secret=${lp.secretArts}',
    );
    final big = Profile()..coins = 10000;
    print('legendary price at 10000: ${legendaryPrice(10000, math.Random(2))}');
    // encounter expectation
    final enc = Profile();
    final er = math.Random(7);
    var leg = 0, eli = 0, her = 0;
    for (var i = 0; i < 100000; i++) {
      final e = rollEncounter(enc, er, now: 0);
      if (e == Encounter.legendary) leg++;
      if (e == Encounter.elixir) eli++;
      if (e == Encounter.hermit) her++;
    }
    print('100k rolls: leg=$leg eli=$eli her=$her');
    // all-sink coins
    print(
      'sinks coins = ${materialPrices.values.fold(0, (a, b) => a + b) + shapePrices.values.fold(0, (a, b) => a + b)} + wagon 450',
    );
    var first = 0;
    for (final s in campaign) {
      first += s.coins(first: true);
    }
    print(
      'first clear coins total=$first silver=${campaign.where((s) => s.chapter != null).length * 5}',
    );
    int ach(String k) => 0;
    var ac = 0, asv = 0, at = 0;
    for (final a in achievements) {
      ac += a.reward.coins;
      asv += a.reward.silver;
      at += a.reward.tokens;
    }
    print('achievements coins=$ac silver=$asv tokens=$at');
    print(
      'looks silver sink=${(hairStyles.length - 3 + robeColors.length - 3) * lookPrice}',
    );
    print(
      'wander map week sample: ${WanderMap.build(WanderMap.weekOf(DateTime(2026, 10, 12))).map((r) => r.map((n) => n.name[0]).join()).join('|')}',
    );
  });
}
