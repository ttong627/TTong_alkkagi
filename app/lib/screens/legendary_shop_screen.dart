import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../progress/encounters.dart';
import '../progress/store.dart';

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
    await _store.save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    final now = DateTime.now().millisecondsSinceEpoch;
    final left = ((p.legendaryUntil - now) / 1000).ceil();
    final open = p.legendaryOpen(now);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          open ? '기인방 · ${left ~/ 60}분 ${left % 60}초 남음' : '기인방 · 닫힘',
        ),
      ),
      body: !open
          ? const Center(child: Text('노인은 이미 떠났다. 기연은 또 온다.'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text('엽전 ${p.coins}'),
                for (final e in p.legendary)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            itemLabel(e.split('|').first),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '붙은 효과: ${e.split('|').last} — ${perkHelp(e.split('|').last)}',
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('부른 값 엽전 ${_price[e]}'),
                              const Spacer(),
                              TextButton(
                                onPressed: _haggled.contains(e)
                                    ? null
                                    : () => _haggle(e),
                                child: const Text('깎기(1번)'),
                              ),
                              FilledButton(
                                onPressed: () => _buy(e),
                                child: const Text('사기'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
