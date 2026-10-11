import 'package:flutter/material.dart';

import '../game/avatar.dart';
import '../progress/profile.dart';
import '../progress/store.dart';
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

/// 외형 꾸미기(설계서 §2.5): 얼굴형·머리·도복 색. 앞 3가지는 처음부터, 나머지는 은자 3개씩.
class LookScreen extends StatefulWidget {
  const LookScreen({super.key});

  @override
  State<LookScreen> createState() => _LookScreenState();
}

class _LookScreenState extends State<LookScreen> {
  final _store = ProfileStore.instance;

  Future<void> _pick({int? face, int? hair, int? robe}) async {
    final p = _store.profile;
    if (hair != null && !p.hairs.contains(hair)) {
      if (!p.buyHair(hair)) return _need();
    }
    if (robe != null && !p.robes.contains(robe)) {
      if (!p.buyRobe(robe)) return _need();
    }
    if (face != null) p.face = face;
    if (hair != null) p.hair = hair;
    if (robe != null) p.robe = robe;
    await _store.save();
    if (mounted) setState(() {});
  }

  void _need() => ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('은자가 모자라요 — 강호행 장을 처음 깨면 받아요')));

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    final poor = p.silver < lookPrice;
    // 얼굴·머리·도복 한 칸: 못 가진 것은 자물쇠 + 은자 값(모자라면 붉게).
    Widget chip(String label, bool on, bool owned, VoidCallback tap) =>
        GameChip(
          label: label,
          selected: on,
          locked: !owned,
          onTap: tap,
          trailing: owned
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(Art.icon('silver'), width: 22),
                    Text(
                      '$lookPrice',
                      style: TextStyle(
                        fontFamily: titleFont,
                        fontSize: 15,
                        color: poor ? const Color(0xFFFF8A75) : Palette.text,
                      ),
                    ),
                  ],
                ),
        );
    Widget group(String title, String icon, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHead(title, icon: icon),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ),
      ),
    );
    return GameScaffold(
      background: 'lobby',
      appBar: AppBar(
        title: const Text('꾸미기'),
        actions: [
          CurrencyPill(icon: 'silver', value: p.silver),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Center(
            child: GlassPanel(
              radius: 90,
              padding: const EdgeInsets.all(14),
              child: Avatar.of(p, size: 140),
            ),
          ),
          const SizedBox(height: 16),
          group('얼굴', 'look', [
            for (var i = 0; i < faceShapes.length; i++)
              chip(faceShapes[i], p.face == i, true, () => _pick(face: i)),
          ]),
          group('머리', 'look', [
            for (var i = 0; i < hairStyles.length; i++)
              chip(
                hairStyles[i],
                p.hair == i,
                p.hairs.contains(i),
                () => _pick(hair: i),
              ),
          ]),
          group('도복', 'look', [
            for (var i = 0; i < robeColors.length; i++)
              chip(
                robeNames[i],
                p.robe == i,
                p.robes.contains(i),
                () => _pick(robe: i),
              ),
          ]),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 18, color: Palette.dim),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  '능력치와 무관 · 환생해도 유지',
                  style: TextStyle(fontSize: 15, color: Palette.dim),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
