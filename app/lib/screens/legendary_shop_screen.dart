import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../progress/encounters.dart';
import '../progress/profile.dart';
import '../progress/store.dart';
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

/// 기인방(설계서 §6.2C): 10분 동안만. 물건마다 특수효과 1개(각 20%)가 붙어 **사기 전에 보인다**.
/// 값은 노인이 지금 엽전의 30~50% 를 부르고, 한 번 깎을 수 있다(50% 성공, −20%).
class LegendaryShopScreen extends StatefulWidget {
  const LegendaryShopScreen({super.key});

  @override
  State<LegendaryShopScreen> createState() => _LegendaryShopScreenState();
}

class _LegendaryShopScreenState extends State<LegendaryShopScreen> {
  final _store = ProfileStore.instance;
  final _rand = math.Random();
  final _price = <String, int>{};
  final _haggled = <String>{};
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    for (final e in _store.profile.legendary) {
      _price[e] = legendaryPrice(_store.profile.coins, _rand);
    }
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _haggle(String e) {
    if (_haggled.contains(e)) return;
    _haggled.add(e);
    final ok = _rand.nextBool();
    if (ok) _price[e] = (_price[e]! * 0.8).round();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '「허허, 젊은이 말솜씨가 좋구먼.」 20% 깎았다' : '「한 푼도 못 깎네.」'),
      ),
    );
    setState(() {});
  }

  Future<void> _buy(String e) async {
    if (!buyLegendary(_store.profile, e, _price[e]!)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('엽전이 모자랍니다')));
      return;
    }
    // 산 뒤 남은 엽전을 보고 값을 다시 부른다(처음 값으로 여러 개 사던 구멍, 2026-10-11).
    for (final k in _store.profile.legendary) {
      if (!_haggled.contains(k)) {
        _price[k] = legendaryPrice(_store.profile.coins, _rand);
      }
    }
    await _store.save();
    if (mounted) setState(() {});
  }

  /// 물건 한 칸: 이름 · 붙은 효과(사기 전에 보임) · 값 · 깎기 · 사기.
  Widget _item(Profile p, String e) {
    final name = itemLabel(e.split('|').first);
    final perk = e.split('|').last;
    final price = _price[e]!;
    final can = p.coins >= price;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.all(12),
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Image.asset(Art.icon('legend'), width: 48),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: titleFont,
                          fontFamilyFallback: fallbackFonts,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '$perk · ${perkHelp(perk)}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Palette.gold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: InfoPill(icon: 'coin', text: '$price', warn: !can),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: GameButton(
                    label: '깎기',
                    color: Palette.jade,
                    height: 44,
                    fontSize: 17,
                    onTap: _haggled.contains(e) ? null : () => _haggle(e),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: GameButton(
                    label: '사기',
                    height: 44,
                    fontSize: 17,
                    color: Palette.red,
                    onTap: can ? () => _buy(e) : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    final now = DateTime.now().millisecondsSinceEpoch;
    final left = ((p.legendaryUntil - now) / 1000).ceil();
    final open = p.legendaryOpen(now);
    return GameScaffold(
      background: 'oilyTable',
      appBar: AppBar(
        title: const Text('기인방'),
        actions: [
          if (open) ...[
            const Icon(Icons.timer_outlined, color: Palette.gold),
            const SizedBox(width: 4),
            InfoPill(
              text: '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
              warn: left < 60,
            ),
          ],
          const SizedBox(width: 12),
        ],
      ),
      body: !open
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: GlassPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(Art.icon('legend'), height: 80),
                    const SizedBox(height: 10),
                    const Text(
                      '노인은 이미 떠났다',
                      style: TextStyle(fontFamily: titleFont, fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '기연은 또 와요',
                      style: TextStyle(fontSize: 17, color: Palette.dim),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InfoPill(icon: 'coin', text: '${p.coins}'),
                  ),
                ),
                for (final e in p.legendary) _item(p, e),
              ],
            ),
    );
  }
}
