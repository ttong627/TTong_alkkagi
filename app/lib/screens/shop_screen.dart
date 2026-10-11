import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';

import '../game/board_paint.dart';
import '../progress/profile.dart';
import '../progress/store.dart';

/// 만물상(설계서 §6.2A): 엽전으로 재질·모양을 산다. 산 것은 「능력치 · 내 돌」에서 고른다.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _store = ProfileStore.instance;

  Future<void> _buy(bool ok, String what) async {
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('엽전이 모자랍니다 — 강호행에서 벌어 오세요')));
      return;
    }
    await _store.save();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$what 을(를) 샀습니다')));
  }

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('만물상 · 엽전 ${p.coins}')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('재질', style: t.titleMedium),
          for (final m in StoneMaterial.values)
            Card(
              child: ListTile(
                leading: _StoneIcon(m, StoneShape.round),
                title: Text(m.label),
                subtitle: Text(_materialHelp(m)),
                trailing: p.materials.contains(m)
                    ? const Text('가짐')
                    : FilledButton(
                        onPressed: () => _buy(p.buyMaterial(m), m.label),
                        child: Text('엽전 ${materialPrices[m]}'),
                      ),
              ),
            ),
          const SizedBox(height: 12),
          Text('모양', style: t.titleMedium),
          for (final s in StoneShape.values)
            Card(
              child: ListTile(
                leading: _StoneIcon(StoneMaterial.cheongok, s),
                title: Text(s.label),
                subtitle: Text(_shapeHelp(s)),
                trailing: p.shapes.contains(s)
                    ? const Text('가짐')
                    : FilledButton(
                        onPressed: () => _buy(p.buyShape(s), s.label),
                        child: Text('엽전 ${shapePrices[s]}'),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

String _materialHelp(StoneMaterial m) => switch (m) {
  StoneMaterial.cheongok => '표준 · 다루기 쉬움',
  StoneMaterial.wood => '가볍고 빠르나 밀어내는 힘이 약함',
  StoneMaterial.hyeoncheol => '무거워 덜 구르지만 맞힌 돌을 멀리 밀어냄',
  StoneMaterial.ice => '잘 미끄러져 연쇄 충돌',
};

String _shapeHelp(StoneShape s) => switch (s) {
  StoneShape.flat => '초급 · 잘 멈추고 예측이 쉬움',
  StoneShape.round => '중급',
  StoneShape.sphere => '고급 · 잘 구르고 회전 영향이 큼',
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
