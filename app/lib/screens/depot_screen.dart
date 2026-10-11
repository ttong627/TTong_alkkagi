import 'package:flutter/material.dart';

import '../progress/store.dart';
import '../ui/kit.dart';

/// 무림맹 보급소(설계서 §6.2B): 주말, 또는 목인항 1,000타, 또는 6장 격파 때 열린다. 무림맹 징표로 산다.
class DepotScreen extends StatefulWidget {
  const DepotScreen({super.key});

  @override
  State<DepotScreen> createState() => _DepotScreenState();
}

/// (이름, 값, 설명).
const _goods = [
  ('잔상:달맞이', 3, '추석 한정 — 달빛 잔상'),
  ('잔상:청죽', 3, '푸른 대나무 잔상'),
  ('잔상:먹물', 3, '먹물이 번지는 잔상'),
  ('비급', 10, '모든 능력치 +1'),
];

class _DepotScreenState extends State<DepotScreen> {
  final _store = ProfileStore.instance;

  Future<void> _buy(String name, int price) async {
    final p = _store.profile;
    if (p.tokens < price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('징표가 모자랍니다 — 투기장·강호유랑·숙적전에서 얻습니다')),
      );
      return;
    }
    p.tokens -= price;
    if (name == '비급') {
      p.secretArts++;
    } else {
      p.trails.add(name.substring(3));
    }
    await _store.save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    final open = p.depotOpen(DateTime.now());
    return GameScaffold(
      background: 'turtleMarket',
      appBar: AppBar(title: Text('무림맹 보급소 · 징표 ${p.tokens}')),
      body: !open
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('보급소는 주말에, 또는 목인항 1,000타를 채우거나 6장을 깨면 열립니다.'),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final (name, price, help) in _goods)
                  Card(
                    child: ListTile(
                      title: Text(name.replaceFirst(':', ' ')),
                      subtitle: Text(help),
                      trailing:
                          name.startsWith('잔상:') &&
                              p.trails.contains(name.substring(3))
                          ? const Text('가짐')
                          : FilledButton(
                              onPressed: () => _buy(name, price),
                              child: Text('징표 $price'),
                            ),
                    ),
                  ),
              ],
            ),
    );
  }
}
