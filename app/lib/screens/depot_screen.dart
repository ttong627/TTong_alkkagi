import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../progress/profile.dart';
import '../progress/store.dart';
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

/// 무림맹 보급소(설계서 §6.2B): 주말, 또는 목인항 1,000타, 또는 6장 격파 때 열린다. 무림맹 징표로 산다.
class DepotScreen extends StatefulWidget {
  const DepotScreen({super.key});

  @override
  State<DepotScreen> createState() => _DepotScreenState();
}

/// (이름, 값, 설명).
const _goods = [
  ('잔상:달맞이', 3, '추석 한정 달빛 잔상'),
  ('잔상:청죽', 3, '푸른 대나무 잔상'),
  ('잔상:먹물', 3, '먹물이 번지는 잔상'),
  ('비급', 0, '모든 능력치 +1'),
];

class _DepotScreenState extends State<DepotScreen> {
  final _store = ProfileStore.instance;

  Future<void> _buy(String name, int listed) async {
    final p = _store.profile;
    final price = name == '비급' ? p.secretArtPrice : listed;
    if (name == '비급' && p.secretArts >= Profile.maxSecretArts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이번 생의 비급은 다 익혔습니다 — 환생하면 다시')),
      );
      return;
    }
    if (p.tokens < price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('징표가 모자랍니다 — 투기장·강호유랑·숙적전에서 얻습니다')),
      );
      return;
    }
    p.tokens -= price;
    if (name == '비급') {
      p.gainSecretArt();
    } else {
      p.trails.add(name.substring(3));
    }
    await _store.save();
    if (mounted) setState(() {});
  }

  /// 오른쪽 칸: 가짐 / 다 익힘 / 징표 값(모자라면 회색).
  Widget _trailing(Profile p, String name, int listed) {
    if (name.startsWith('잔상:') && p.trails.contains(name.substring(3))) {
      return const StateBadge('가짐');
    }
    final isArt = name == '비급';
    if (isArt && p.secretArts >= Profile.maxSecretArts) {
      return const StateBadge('다 익힘');
    }
    final price = isArt ? p.secretArtPrice : listed;
    final can = p.tokens >= price;
    return SizedBox(
      width: 96,
      child: GameButton(
        height: 44,
        color: Palette.red,
        onTap: can ? () => _buy(name, listed) : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(Art.icon('token'), height: 26),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$price',
                  style: TextStyle(
                    fontFamily: titleFont,
                    fontSize: 18,
                    color: can ? Colors.white : Colors.white60,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    final open = p.depotOpen(DateTime.now());
    // 아직 살 수 있는 것 중 가장 싼 값(없으면 안내를 띄우지 않는다).
    final prices = <int>[
      for (final (name, price, _) in _goods)
        if (name == '비급')
          ...(p.secretArts < Profile.maxSecretArts
              ? [p.secretArtPrice]
              : const <int>[])
        else if (!p.trails.contains(name.substring(3)))
          price,
    ];
    final poor = prices.isNotEmpty && p.tokens < prices.reduce(math.min);
    return GameScaffold(
      background: 'turtleMarket',
      appBar: AppBar(
        title: const Text('보급소'),
        actions: [
          CurrencyPill(icon: 'token', value: p.tokens),
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
                    Image.asset(Art.icon('lock'), height: 72),
                    const SizedBox(height: 10),
                    const Text(
                      '지금은 닫혔어요',
                      style: TextStyle(fontFamily: titleFont, fontSize: 22),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '주말 · 목인항 1,000타 · 6장 격파\n셋 중 하나면 열려요',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, color: Palette.dim),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              children: [
                if (poor)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      '징표는 투기장·강호유랑에서 얻어요',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Palette.dim),
                    ),
                  ),
                for (final (name, price, help) in _goods)
                  RowCard(
                    leading: Image.asset(
                      Art.icon(name == '비급' ? 'chest' : 'medal'),
                      width: 44,
                    ),
                    title: name.replaceFirst(':', ' '),
                    sub: name == '비급'
                        ? '$help · ${p.secretArts}/${Profile.maxSecretArts}'
                        : help,
                    trailing: _trailing(p, name, price),
                  ),
              ],
            ),
    );
  }
}
