import 'dart:async';
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
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

/// 투기장(설계서 §8.1): 진기 10 + 엽전 20 으로 들어가 AI 와 연승전. 이길수록 배수가 오르고
/// 언제든 그만두고 모은 엽전을 받는다. 지면 50% 만. 3연승 이상 그만두면 징표 +1.
class ArenaScreen extends StatefulWidget {
  const ArenaScreen({super.key});

  @override
  State<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends State<ArenaScreen> {
  @override
  void initState() {
    super.initState();
    // 첫 방문 안내(설계서 §16.13).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) =>
          firstVisit(context, 'arena', '이길수록 상금이 불어난다. 지면 절반만 남으니 적당할 때 챙겨라.'),
    );
    // 진기가 차면 「들어가기」가 저절로 켜진다.
    _tick = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    // 연전 도중 나가면 모은 판돈은 받고 끝(메모리에만 있어 사라지던 것 · 2026-10-14 점검).
    if (_inRun && _pot > 0) {
      _bank();
      _store.save();
    }
    super.dispose();
  }

  final _store = ProfileStore.instance;
  final _rand = math.Random();
  bool _inRun = false;
  int _streak = 0;
  int _pot = 0;

  /// 입장·받기를 처리하는 중(두 번 눌러 두 번 내고 두 번 받던 것 · 2026-10-14 점검).
  bool _busy = false;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  /// 판돈을 엽전으로 받는다(3연승 이상이면 징표 +1). 받은 판돈 · 징표 여부를 돌려준다.
  (int, bool) _bank() {
    final p = _store.profile;
    final pot = _pot, token = _streak >= 3;
    p.coins += pot;
    if (token) p.tokens++;
    _pot = 0;
    _inRun = false;
    return (pot, token);
  }

  /// 단추를 한 번만 처리한다(처리하는 동안 다시 눌러도 무시).
  Future<void> _once(Future<void> Function() f) async {
    if (_busy) return;
    _busy = true;
    try {
      await f();
    } finally {
      _busy = false;
    }
  }

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
    // 연전마다 진기 10(첫 판은 입장 때 냈다). 모자라면 모은 것을 받고 끝(2026-10-11 경제 점검:
    // 입장 한 번에 무한 연전이던 것).
    if (_streak > 0 && !p.spendStamina(_now, Stamina.cost)) {
      _say('진기가 모자라 여기까지 — 모은 엽전을 받습니다');
      await _cashOut();
      return;
    }
    // 난이도: 1·2판 쉬움 · 3·4판 보통 · 5판부터 어려움.
    final diff = _streak < 2
        ? Difficulty.easy
        : (_streak < 4 ? Difficulty.normal : Difficulty.hard);
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
    if (!mounted) return;
    // 일타쌍피 엽전(설계서 §16.7)은 판돈과 따로 바로 받는다.
    p.coins += last?.bonusCoins ?? 0;
    if (won == true) {
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
    if (!_inRun) return;
    final (pot, token) = _bank();
    setState(() {});
    _say('엽전 $pot 받음${token ? ' · 무림맹 징표 +1' : ''}');
    await _store.save();
  }

  void _say(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  /// 연승 사다리: 이길 때마다 받는 엽전(40 → 60 → 80 → 120).
  Widget _ladder() => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 4,
    runSpacing: 4,
    children: [
      for (var i = 0; i < ArenaRules.multipliers.length; i++) ...[
        if (i > 0) const Icon(Icons.chevron_right, color: Palette.dim),
        InfoPill(icon: 'coin', text: '${ArenaRules.winReward(i)}'),
      ],
    ],
  );

  /// 들어가기 단추. 못 들어가면 회색으로 두고 무엇이 모자란지 화면에 적는다.
  Widget _enterArea(Profile p) {
    final cost = Stamina.cost.toInt();
    final needCoin = p.coins < ArenaRules.entryCoins;
    final needStamina = p.staminaNow(_now) < Stamina.cost;
    final can = !needCoin && !needStamina;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameButton(
          key: const Key('arena-enter'),
          height: 64,
          color: Palette.red,
          onTap: can ? () => _once(_enter) : null,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: can
                ? const Text(
                    '들어가기',
                    style: TextStyle(
                      fontFamily: titleFont,
                      fontSize: 26,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    '엽전 ${ArenaRules.entryCoins} · 진기 $cost 필요',
                    style: const TextStyle(
                      fontFamily: titleFont,
                      fontSize: 20,
                      color: Colors.white70,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        if (can)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              InfoPill(icon: 'stamina', text: '-$cost'),
              InfoPill(icon: 'coin', text: '-${ArenaRules.entryCoins}'),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(Art.icon(needCoin ? 'coin' : 'stamina'), width: 26),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  needCoin ? '강호행에서 엽전을 모아요' : '진기는 6분에 1씩 차요',
                  style: const TextStyle(fontSize: 17, color: Palette.dim),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _runArea(Profile p) {
    final cost = Stamina.cost.toInt();
    final lowStamina = p.staminaNow(_now) < Stamina.cost;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanel(
          child: Row(
            children: [
              Image.asset(Art.icon('rank'), width: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedText(
                      '$_streak연승',
                      size: 30,
                      title: true,
                      color: Palette.gold,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        InfoPill(icon: 'coin', text: '$_pot'),
                        InfoPill(
                          icon: 'arena',
                          text: '+${ArenaRules.winReward(_streak)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        GameButton(
          key: const Key('arena-next'),
          height: 64,
          color: Palette.red,
          onTap: () => _once(_fight),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              lowStamina ? '진기 부족 · 받고 끝' : '다음 상대 · 진기 $cost',
              style: const TextStyle(
                fontFamily: titleFont,
                fontSize: 24,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        GameButton(
          key: const Key('arena-cashout'),
          label: '그만하고 받기',
          icon: 'chest',
          color: Palette.jade,
          height: 56,
          fontSize: 22,
          onTap: () => _once(_cashOut),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    final stamina = p.staminaNow(_now).floor();
    final mult = ArenaRules.multipliers
        .map((m) => '×${m == m.roundToDouble() ? m.toInt() : m}')
        .join(' → ');
    return GameScaffold(
      background: 'murimIce',
      appBar: AppBar(
        title: const Text('투기장'),
        actions: [
          HelpButton(
            title: '투기장',
            lines: [
              ('coin', '이길 때마다 엽전 ${ArenaRules.base} $mult'),
              ('chest', '지면 모은 엽전의 절반만 받아요'),
              ('token', '3연승 넘기고 그만두면 징표 +1'),
              ('stamina', '판마다 진기 ${Stamina.cost.toInt()} · 상대는 점점 세져요'),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              InfoPill(icon: 'rank', text: '최고 ${p.arenaBest}'),
              InfoPill(
                icon: 'stamina',
                text: '$stamina',
                warn: p.staminaNow(_now) < Stamina.cost,
              ),
              InfoPill(
                icon: 'coin',
                text: '${p.coins}',
                warn: !_inRun && p.coins < ArenaRules.entryCoins,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!_inRun) ...[
            GlassPanel(
              child: Column(
                children: [
                  Image.asset(Art.icon('arena'), height: 96),
                  const SizedBox(height: 10),
                  _ladder(),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Palette.gold),
                      SizedBox(width: 6),
                      Text('지면 절반만', style: TextStyle(fontSize: 17)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _enterArea(p),
          ] else
            _runArea(p),
        ],
      ),
    );
  }
}
