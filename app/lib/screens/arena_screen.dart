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

/// 투기장(설계서 §8.1): 진기 10 + 엽전 20 으로 들어가 AI 와 연승전. 이길수록 배수가 오르고
/// 언제든 그만두고 모은 엽전을 받는다. 지면 50% 만. 3연승 이상 그만두면 징표 +1.
class ArenaScreen extends StatefulWidget {
  const ArenaScreen({super.key});

  @override
  State<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends State<ArenaScreen> {
  final _store = ProfileStore.instance;
  final _rand = math.Random();
  bool _inRun = false;
  int _streak = 0;
  int _pot = 0;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  Future<void> _enter() async {
    final p = _store.profile;
    if (p.coins < ArenaRules.entryCoins ||
        !p.spendStamina(_now, Stamina.cost)) {
      _say('진기 ${Stamina.cost.toInt()} · 엽전 ${ArenaRules.entryCoins} 가 필요합니다');
      return;
    }
    p.coins -= ArenaRules.entryCoins;
    await _store.save();
    setState(() {
      _inRun = true;
      _streak = 0;
      _pot = 0;
    });
    await _fight();
  }

  Future<void> _fight() async {
    final p = _store.profile;
    final diff = _streak == 0
        ? Difficulty.easy
        : (_streak == 1 ? Difficulty.normal : Difficulty.hard);
    final cfg = Campaign.playerConfig(
      p,
      arena: Arena.values[_rand.nextInt(Arena.values.length)],
      difficulty: diff,
      opponentMaterial:
          StoneMaterial.values[_rand.nextInt(StoneMaterial.values.length)],
      opponentName: '투기장 ${_streak + 1}번째 상대',
      aimAssist: 1,
    );
    Match? last;
    final won = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          config: cfg,
          title: '투기장 ${_streak + 1}연전',
          onTurnEnd: (m) => last = m,
        ),
      ),
    );
    if (won == null || !mounted) return;
    // 일타쌍피 엽전(설계서 §16.7)은 판돈과 따로 바로 받는다.
    p.coins += last?.bonusCoins ?? 0;
    if (won) {
      _pot += ArenaRules.winReward(_streak);
      _streak++;
      p.arenaBest = math.max(p.arenaBest, _streak);
    } else {
      final got = ArenaRules.onLoss(_pot);
      p.coins += got;
      p.refundStamina(_now, Stamina.cost / 2);
      _say('졌습니다 — 모은 것의 절반 엽전 $got, 진기 5 돌려받음');
      _inRun = false;
    }
    await _store.save();
    if (!mounted) return;
    setState(() {});
    await afterRound(context);
  }

  Future<void> _cashOut() async {
    final p = _store.profile;
    p.coins += _pot;
    if (_streak >= 3) p.tokens++;
    _say('엽전 $_pot 받음${_streak >= 3 ? ' · 무림맹 징표 +1' : ''}');
    await _store.save();
    setState(() => _inRun = false);
  }

  void _say(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('투기장 · 진기 ${p.staminaNow(_now).floor()} · 엽전 ${p.coins}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('최고 연승 ${p.arenaBest}', style: t.titleMedium),
            const SizedBox(height: 8),
            Text(
              '이길 때마다 엽전 40 × 배수(×1 → ×1.5 → ×2 → ×3). 지면 모은 것의 절반.\n'
              '상대는 판마다 세지고 대전장·돌이 바뀝니다.',
            ),
            const SizedBox(height: 24),
            if (!_inRun)
              FilledButton(
                onPressed: _enter,
                child: Text(
                  '들어가기 (진기 ${Stamina.cost.toInt()} · 엽전 ${ArenaRules.entryCoins})',
                ),
              )
            else ...[
              Text('$_streak연승 · 모은 엽전 $_pot', style: t.headlineSmall),
              const SizedBox(height: 4),
              Text('다음 판 이기면 +${ArenaRules.winReward(_streak)}'),
              const SizedBox(height: 16),
              FilledButton(onPressed: _fight, child: const Text('다음 상대')),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _cashOut, child: const Text('그만하고 받기')),
            ],
          ],
        ),
      ),
    );
  }
}
