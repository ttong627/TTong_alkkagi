import 'dart:async';
import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../game/arena.dart';
import '../game/match.dart';
import '../progress/modes.dart';
import '../progress/profile.dart';
import '../progress/settings.dart';
import '../progress/store.dart';
import '../story/campaign.dart';
import 'encounter_flow.dart';
import 'game_screen.dart';
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

// 칸마다 받는 몫(화면 설명과 실제 지급이 같은 값을 쓰게 한 곳에 둔다).
const _battleCoins = 120;
const _villageStamina = 8.0;
const _villageCoins = 20;
const _mysteryCoins = 10;
const _wagonStamina = 15.0;

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

  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    // 첫 방문 안내(설계서 §16.13).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => firstVisit(context, 'wander', '한 칸 갈 때마다 진기가 든다. 길 위에서 기연을 찾아라!'),
    );
    // 진기가 차면 「진기 필요」 표시가 저절로 풀린다.
    _tick = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
    final p = _store.profile;
    // 주는 앞으로만 넘어간다(시계를 되돌려 지도·완주 보상을 다시 받던 것 — 2026-10-11).
    if (WanderMap.order(_week) > WanderMap.order(p.wanderWeek)) {
      p
        ..wanderWeek = _week
        ..wanderRow = 0
        ..wanderWins = 0;
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
          difficulty: p.wanderRow < 3
              ? Difficulty.normal
              : (p.done.contains('c5') ? Difficulty.hard : Difficulty.skilled),
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
          p.coins += _battleCoins;
          p.wanderWins++;
          _say('이겼다 — 엽전 +$_battleCoins');
        } else {
          p.refundStamina(_now, Stamina.cost / 2);
          advance = false;
          _say('졌다 — 진기 5 돌려받음, 다시 고르세요');
        }
      case WanderNode.village:
        // 칸 값(10)보다 적게 돌려준다 — 예전 +15 는 진기를 오히려 남겨 전투 없이 완주됐다.
        p.refundStamina(_now, _villageStamina);
        p.coins += _villageCoins;
        _say('마을에서 쉬었다 — 진기 +${_villageStamina.toInt()} · 엽전 +$_villageCoins');
      case WanderNode.mystery:
        p.coins += _mysteryCoins;
        _say('물음표 — 엽전 +$_mysteryCoins, 기연 확률 ×5');
      case WanderNode.wagon:
        p.refundStamina(_now, _wagonStamina);
        await _wagon();
    }
    if (advance) p.wanderRow++;
    if (p.wanderRow == WanderMap.rows) {
      // 완주 보상은 전투를 두 번 이상 이겼을 때만.
      if (p.wanderWins >= 2) {
        p.tokens += 3;
        _say('이번 주 강호유랑 완주! 무림맹 징표 +3');
      } else {
        _say('완주했지만 싸움 없이 왔다 — 징표는 전투 2승부터');
      }
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
      _say('수레 객잔 — 진기 +15 (살 것이 없다)');
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
          content: Text('진기 +15. 「이 동네 특산물, $item 잔상이라네. 엽전 $price.」'),
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

  static String _icon(WanderNode n) => switch (n) {
    WanderNode.battle => 'arena',
    WanderNode.village => 'stamina',
    WanderNode.mystery => 'odds',
    WanderNode.wagon => 'shop',
  };

  static Color _color(WanderNode n) => switch (n) {
    WanderNode.battle => Palette.red,
    WanderNode.village => Palette.jade,
    WanderNode.mystery => Palette.sky,
    WanderNode.wagon => Palette.goldDeep,
  };

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    final row = p.wanderRow;
    final cost = Stamina.cost.toInt();
    final done = row >= WanderMap.rows;
    final lacking = p.staminaNow(_now) < Stamina.cost;
    return GameScaffold(
      background: 'kubiForest',
      appBar: AppBar(
        title: const Text('강호유랑'),
        actions: [
          HelpButton(
            title: '강호유랑',
            lines: [
              ('arena', '전투 — 이기면 엽전 +$_battleCoins'),
              (
                'stamina',
                '마을 — 진기 +${_villageStamina.toInt()} · 엽전 +$_villageCoins',
              ),
              ('odds', '물음표 — 엽전 +$_mysteryCoins · 기연 ×5'),
              ('shop', '수레 객잔 — 진기 +${_wagonStamina.toInt()} · 특산물 흥정'),
              ('token', '끝까지 가면 징표 +3 (전투 2승 이상)'),
              ('wander', '칸마다 진기 $cost · 월요일 05:00 새 지도'),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              InfoPill(
                icon: 'stamina',
                text: '${p.staminaNow(_now).floor()}',
                warn: lacking && !done,
              ),
              InfoPill(
                icon: 'wander',
                text: '${row.clamp(0, WanderMap.rows)}/${WanderMap.rows}',
              ),
              InfoPill(icon: 'arena', text: '${p.wanderWins}/2'),
            ],
          ),
          const SizedBox(height: 8),
          GameBar(value: row / WanderMap.rows, color: Palette.jade),
          const SizedBox(height: 10),
          if (done)
            GlassPanel(
              child: Row(
                children: [
                  Image.asset(Art.icon('chest'), width: 48),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '이번 주 끝! 월요일 05:00 에 새 지도',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            )
          else if (lacking)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(Art.icon('stamina'), width: 26),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '진기 $cost 필요 · 6분에 1씩 차요',
                    style: const TextStyle(fontSize: 17, color: Palette.dim),
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.touch_app, color: Palette.gold),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${row + 1}번째 갈림길 · 진기 $cost',
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          for (var r = WanderMap.rows - 1; r >= 0; r--)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${r + 1}',
                      style: TextStyle(
                        fontFamily: titleFont,
                        fontSize: 16,
                        color: r == row ? Palette.gold : Palette.dim,
                      ),
                    ),
                  ),
                  for (final n in _map[r])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _NodeTile(
                          label: n.label,
                          icon: _icon(n),
                          color: _color(n),
                          state: r < row
                              ? _NodeState.passed
                              : (r == row ? _NodeState.here : _NodeState.ahead),
                          enabled: !lacking,
                          onTap: () => _go(n),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum _NodeState { passed, here, ahead }

/// 지도 칸: 지금 고를 줄은 색이 켜지고, 지나온 줄은 ✔, 앞줄은 흐리게.
class _NodeTile extends StatelessWidget {
  const _NodeTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.state,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final String icon;
  final Color color;
  final _NodeState state;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final here = state == _NodeState.here;
    final tappable = here && enabled;
    Widget tile = Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: here
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(color, Colors.white, 0.2)!, color],
              )
            : null,
        color: here ? null : Palette.panel,
        border: Border.all(
          color: here ? Palette.gold : Colors.white24,
          width: here ? 2.5 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(Art.icon(icon), height: 36),
              if (state == _NodeState.passed)
                const Icon(Icons.check_circle, color: Palette.jade, size: 30),
            ],
          ),
          const SizedBox(height: 2),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 15,
                  color: here ? Colors.white : Palette.dim,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (state != _NodeState.here || !enabled) {
      tile = Opacity(opacity: here ? 0.6 : 0.45, child: tile);
    }
    return Semantics(
      button: tappable,
      enabled: tappable,
      label: state == _NodeState.passed ? '$label, 지나옴' : label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tappable
            ? () {
                Sound.play('ui_tap', 0.7);
                Buzz.tick();
                onTap();
              }
            : null,
        child: ExcludeSemantics(child: tile),
      ),
    );
  }
}
