import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';

import '../game/board_paint.dart';
import '../progress/profile.dart';
import '../progress/store.dart';
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

/// 만물상(설계서 §6.2A): 엽전으로 재질·모양을 산다. 산 돌은 여기서 바로 끼울 수 있다.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  @override
  void initState() {
    super.initState();
    // 첫 방문 안내(설계서 §16.13).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) =>
          firstVisit(context, 'shop', '엽전으로 새 돌을 사거라. 무거운 돌, 잘 구르는 돌, 미끄러운 돌…'),
    );
  }

  final _store = ProfileStore.instance;

  /// 산 뒤 「지금 끼울까요?」. [equip] 은 고른 돌을 끼우는 일.
  Future<void> _bought(String what, VoidCallback equip) async {
    await _store.save();
    if (!mounted) return;
    setState(() {});
    final now = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('$what 구입!'),
        content: const Text('지금 끼울까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('끼우기'),
          ),
        ],
      ),
    );
    if (now != true) return;
    equip();
    await _store.save();
    if (mounted) setState(() {});
  }

  Future<void> _buyMaterial(StoneMaterial m) async {
    final p = _store.profile;
    if (!p.buyMaterial(m)) return;
    await _bought(m.label, () => p.material = m);
  }

  Future<void> _buyShape(StoneShape s) async {
    final p = _store.profile;
    if (!p.buyShape(s)) return;
    await _bought(s.label, () => p.shape = s);
  }

  Future<void> _equip(VoidCallback equip) async {
    equip();
    await _store.save();
    if (mounted) setState(() {});
  }

  /// 오른쪽 칸: 끼운 중 / 끼우기 / 값(엽전이 모자라면 흐린 값).
  Widget _trailing({
    required bool owned,
    required bool equipped,
    required int price,
    required VoidCallback onBuy,
    required VoidCallback onEquip,
  }) {
    final coins = _store.profile.coins;
    if (equipped) {
      return const StateBadge('끼운 중');
    }
    if (owned) {
      return SizedBox(
        width: 92,
        child: GameButton(
          label: '끼우기',
          color: Palette.jade,
          height: 44,
          fontSize: 18,
          onTap: onEquip,
        ),
      );
    }
    final can = coins >= price;
    return SizedBox(
      width: 100,
      child: GameButton(
        height: 44,
        color: Palette.red,
        onTap: can ? onBuy : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(Art.icon('coin'), height: 26),
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
    final cheapest = [
      for (final m in StoneMaterial.values)
        if (!p.materials.contains(m)) materialPrices[m]!,
      for (final s in StoneShape.values)
        if (!p.shapes.contains(s)) shapePrices[s]!,
    ];
    final poor =
        cheapest.isNotEmpty &&
        p.coins < cheapest.reduce((a, b) => a < b ? a : b);
    return GameScaffold(
      background: 'turtleMarket',
      appBar: AppBar(
        title: const Text('만물상'),
        actions: [
          CurrencyPill(icon: 'coin', value: p.coins),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          if (poor)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: _Hint('엽전이 모자라요 · 강호행에서 모아요'),
            ),
          const SectionHead('재질', icon: 'shop'),
          for (final m in StoneMaterial.values)
            RowCard(
              leading: _StoneIcon(m, StoneShape.round),
              title: m.label,
              sub: _materialHelp(m),
              trailing: _trailing(
                owned: p.materials.contains(m),
                equipped: p.material == m,
                price: materialPrices[m]!,
                onBuy: () => _buyMaterial(m),
                onEquip: () => _equip(() => p.material = m),
              ),
            ),
          const SizedBox(height: 8),
          const SectionHead('모양', icon: 'stats'),
          for (final s in StoneShape.values)
            RowCard(
              leading: _StoneIcon(StoneMaterial.cheongok, s),
              title: s.label,
              sub: _shapeHelp(s),
              trailing: _trailing(
                owned: p.shapes.contains(s),
                equipped: p.shape == s,
                price: shapePrices[s]!,
                onBuy: () => _buyShape(s),
                onEquip: () => _equip(() => p.shape = s),
              ),
            ),
        ],
      ),
    );
  }
}

/// 한 줄 안내(아이콘 + 짧은 글).
class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Image.asset(Art.icon('coin'), width: 24),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Palette.dim),
        ),
      ),
    ],
  );
}

String _materialHelp(StoneMaterial m) => switch (m) {
  StoneMaterial.cheongok => '표준 · 다루기 쉬움',
  StoneMaterial.wood => '가볍고 빠름 · 미는 힘 약함',
  StoneMaterial.hyeoncheol => '무거움 · 상대를 멀리 밀어냄',
  StoneMaterial.ice => '잘 미끄러짐 · 연쇄 충돌',
  StoneMaterial.obsidian => '조금 무거움 · 맞힌 돌을 세게 튕겨 냄',
  StoneMaterial.granite => '아주 무겁고 빨리 멈춤 · 버티는 돌',
  StoneMaterial.diamond => '가볍고 반발 최고 · 잘 미끄러짐',
};

String _shapeHelp(StoneShape s) => switch (s) {
  StoneShape.flat => '초급 · 잘 멈춤',
  StoneShape.round => '중급',
  StoneShape.sphere => '고급 · 잘 구르고 회전 큼',
};

/// 입체 돌 그림 아이콘.
class _StoneIcon extends StatelessWidget {
  const _StoneIcon(this.material, this.shape);
  final StoneMaterial material;
  final StoneShape shape;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 40,
    height: 40,
    child: CustomPaint(painter: _StonePainter(material, shape)),
  );
}

class _StonePainter extends CustomPainter {
  _StonePainter(this.material, this.shape);
  final StoneMaterial material;
  final StoneShape shape;

  @override
  void paint(Canvas canvas, Size size) => paintTopStone(
    canvas,
    size.center(Offset.zero),
    size.shortestSide * 0.4,
    0,
    material,
    shape: shape,
  );

  @override
  bool shouldRepaint(covariant _StonePainter old) =>
      old.material != material || old.shape != shape;
}

/// 다른 화면에서도 쓰는 돌 아이콘.
Widget stoneIcon(StoneMaterial m, StoneShape s) => _StoneIcon(m, s);
