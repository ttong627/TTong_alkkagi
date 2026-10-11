import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';

import '../progress/profile.dart';
import '../progress/store.dart';
import '../story/chapters.dart';
import 'shop_screen.dart';
import '../ui/art.dart';
import '../ui/theme.dart';
import '../ui/kit.dart';

/// 도감(설계서 §8.7): 모은 재질·모양·캐릭터·만난 고수. 재질 4종·모양 3종을 다 모으면
/// 각각 모든 능력치 +1.
class CodexScreen extends StatelessWidget {
  const CodexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = ProfileStore.instance.profile;
    final t = Theme.of(context).textTheme;
    final bosses = {for (final s in campaign) s.boss};
    Widget entry(bool have, Widget icon, String name) => Opacity(
      opacity: have ? 1 : 0.3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [icon, const SizedBox(height: 4), Text(have ? name : '???')],
      ),
    );
    return GameScaffold(
      background: 'logicMarble',
      appBar: AppBar(title: Text('도감 · 세트 보너스 +${p.codexBonus}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '재질 ${p.materials.length}/${StoneMaterial.values.length}',
            style: t.titleMedium,
          ),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final m in StoneMaterial.values)
                entry(
                  p.materials.contains(m),
                  stoneIcon(m, StoneShape.round),
                  m.label,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '모양 ${p.shapes.length}/${StoneShape.values.length}',
            style: t.titleMedium,
          ),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final s in StoneShape.values)
                entry(
                  p.shapes.contains(s),
                  stoneIcon(StoneMaterial.cheongok, s),
                  s.label,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '캐릭터 ${p.heroes.length}/${Fighter.values.length}',
            style: t.titleMedium,
          ),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final h in Fighter.values)
                entry(
                  p.heroes.contains(h),
                  _face(h.name, p.heroes.contains(h)),
                  h.label,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('만난 고수', style: t.titleMedium),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final b in bosses)
                entry(
                  p.codex.contains('고수:$b'),
                  _face(Art.bossId(b), p.codex.contains('고수:$b')),
                  b,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('겪은 천기 · 지물', style: t.titleMedium),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final w in Weather.values.skip(1))
                entry(
                  p.codex.contains('천기:${w.name}'),
                  const Icon(Icons.cloud, size: 36),
                  w.label,
                ),
              for (final f in FeatureKind.values)
                entry(
                  p.codex.contains('지물:${f.name}'),
                  const Icon(Icons.landscape, size: 36),
                  f.label,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 도감 얼굴: 아직 못 만난 사람은 검은 그림자.
Widget _face(String? id, bool known) {
  final f = Portrait(
    id: id,
    size: 58,
    ring: known ? Palette.gold : Colors.white24,
  );
  return known
      ? f
      : ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Color(0xFF0E0A12),
            BlendMode.srcATop,
          ),
          child: f,
        );
}
