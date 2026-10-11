import 'package:flutter/material.dart';

import '../game/avatar.dart';
import '../progress/profile.dart';
import '../progress/store.dart';
import '../ui/kit.dart';

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
  ).showSnackBar(const SnackBar(content: Text('은자가 모자랍니다 (강호행 장을 처음 깨면 5개)')));

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    final t = Theme.of(context).textTheme;
    Widget chip(String label, bool on, bool owned, VoidCallback tap) =>
        ChoiceChip(
          label: Text(owned ? label : '$label · 은자 $lookPrice'),
          selected: on,
          onSelected: (_) => tap(),
        );
    return GameScaffold(
      background: 'lobby',
      appBar: AppBar(title: Text('외형 · 은자 ${p.silver}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: Avatar.of(p, size: 140)),
          const SizedBox(height: 16),
          Text('얼굴형', style: t.titleMedium),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < faceShapes.length; i++)
                chip(faceShapes[i], p.face == i, true, () => _pick(face: i)),
            ],
          ),
          const SizedBox(height: 12),
          Text('머리 모양', style: t.titleMedium),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < hairStyles.length; i++)
                chip(
                  hairStyles[i],
                  p.hair == i,
                  p.hairs.contains(i),
                  () => _pick(hair: i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('도복 색', style: t.titleMedium),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < robeColors.length; i++)
                chip(
                  robeNames[i],
                  p.robe == i,
                  p.robes.contains(i),
                  () => _pick(robe: i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('외형은 능력치에 영향이 없습니다. 환생해도 그대로 남습니다.'),
        ],
      ),
    );
  }
}
