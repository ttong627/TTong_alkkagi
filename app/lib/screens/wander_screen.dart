import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';

import '../game/arena.dart';
import '../game/match.dart';
import '../progress/modes.dart';
import '../progress/profile.dart';
import '../progress/store.dart';
import '../story/campaign.dart';
import 'encounter_flow.dart';
import 'game_screen.dart';
import '../ui/kit.dart';

/// 강호유랑(설계서 §8.4): 갈림길에서 전투·마을·물음표·수레 객잔을 골라 나아간다. 칸마다 진기 10.
/// 매주 월요일 05:00 에 지도가 바뀐다. 끝까지 가면 무림맹 징표 +3.
class WanderScreen extends StatefulWidget {
  const WanderScreen({super.key});

  @override
  State<WanderScreen> createState() => _WanderScreenState();
}

class _WanderScreenState extends State<WanderScreen> {
  final _store = ProfileStore.instance;
  final _rand = math.Random();
  late final String _week = WanderMap.weekOf(DateTime.now());
  late final _map = WanderMap.build(_week);

  int get _now => DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    final p = _store.profile;
    if (p.wanderWeek != _week) {
      p
        ..wanderWeek = _week
        ..wanderRow = 0;
      _store.save();
    }
  }

  void _say(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _go(WanderNode n) async {
    final p = _store.profile;
    if (!p.spendStamina(_now, Stamina.cost)) {
      _say('진기가 모자랍니다 — 6분에 1씩 찹니다');
      return;
    }
    var advance = true;
    switch (n) {
      case WanderNode.battle:
        final cfg = Campaign.playerConfig(
          p,
          arena: Arena.values[_rand.nextInt(Arena.values.length)],
          difficulty: p.wanderRow < 3 ? Difficulty.normal : Difficulty.hard,
          opponentMaterial:
              StoneMaterial.values[_rand.nextInt(StoneMaterial.values.length)],
          opponentShape:
              StoneShape.values[_rand.nextInt(StoneShape.values.length)],
          opponentName: '떠돌이 고수',
          aimAssist: 1,
        );
        final won = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => GameScreen(config: cfg, title: '강호유랑 · 전투'),
          ),
        );
        if (won == true) {
          p.coins += 50;
          _say('이겼다 — 엽전 +50');
        } else {
          p.refundStamina(_now, Stamina.cost / 2);
          advance = false;
          _say('졌다 — 진기 5 돌려받음, 다시 고르세요');
        }
      case WanderNode.village:
        p.refundStamina(_now, 15);
        p.coins += 20;
        _say('마을에서 쉬었다 — 진기 +15 · 엽전 +20');
      case WanderNode.mystery:
        p.coins += 10;
        _say('물음표 — 엽전 +10, 기연 확률 ×5');
      case WanderNode.wagon:
        p.refundStamina(_now, 30);
        await _wagon();
    }
    if (advance) p.wanderRow++;
    if (p.wanderRow == WanderMap.rows) {
      p.tokens += 3;
      _say('이번 주 강호유랑 완주! 무림맹 징표 +3');
    }
    await _store.save();
    if (!mounted) return;
    setState(() {});
    await afterRound(context, boost: n == WanderNode.mystery ? 5 : 1);
  }

  /// 수레 객잔: 특산물(잔상 꾸미기)을 흥정해 산다.
  Future<void> _wagon() async {
    final p = _store.profile;
    const items = ['달맞이', '청죽', '먹물'];
    final left = items.where((x) => !p.trails.contains(x)).toList();
    if (left.isEmpty) {
      _say('수레 객잔 — 진기 +30 (살 것이 없다)');
      return;
    }
    final item = left[_rand.nextInt(left.length)];
    var price = 150;
    var haggled = false;
    final res = await showDialog<int>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('수레 객잔'),
          content: Text('진기 +30. 「이 동네 특산물, $item 잔상이라네. 엽전 $price.」'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, 0),
              child: const Text('안 사요'),
            ),
            TextButton(
              onPressed: haggled
                  ? null
                  : () => set(() {
                      haggled = true;
                      if (_rand.nextBool()) price = 120;
                    }),
              child: const Text('깎기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, price),
              child: const Text('사기'),
            ),
          ],
        ),
      ),
    );
    if (res != null && res > 0 && p.coins >= res) {
      p.coins -= res;
      p.trails.add(item);
      _say('$item 잔상을 샀다');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    final t = Theme.of(context).textTheme;
    final row = p.wanderRow;
    return GameScaffold(
      background: 'kubiForest',
      appBar: AppBar(title: Text('강호유랑 · 진기 ${p.staminaNow(_now).floor()}')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            row >= WanderMap.rows
                ? '이번 주 지도를 다 돌았습니다. 월요일 05:00 에 새 지도가 열립니다.'
                : '${row + 1}번째 갈림길 — 하나를 고르세요 (칸마다 진기 10)',
            style: t.titleMedium,
          ),
          const SizedBox(height: 8),
          for (var r = WanderMap.rows - 1; r >= 0; r--)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 28, child: Text('${r + 1}')),
                  for (final n in _map[r])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: r == row
                            ? FilledButton(
                                onPressed: () => _go(n),
                                child: Text(n.label),
                              )
                            : OutlinedButton(
                                onPressed: null,
                                child: Text(r < row ? '지나옴' : n.label),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          for (final n in WanderNode.values)
            Text('· ${n.label}: ${n.help}', style: t.bodySmall),
        ],
      ),
    );
  }
}
