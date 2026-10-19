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
    final bosses = {for (final s in campaign) s.boss};
    // 한 칸: 가진 것은 그림 + 이름, 못 만난 것은 흐리게 + 「???」.
    Widget entry(bool have, Widget icon, String name) => Opacity(
      opacity: have ? 1 : 0.3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 4),
          Text(have ? name : '???', style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
    // 묶음: 어두운 판 + 그림 머리글(가진 수 / 전체 수).
    Widget group(String title, String icon, List<Widget> items, [String? n]) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassPanel(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHead(
                  title,
                  icon: icon,
                  trailing: n == null ? null : InfoPill(text: n),
                ),
                Wrap(spacing: 16, runSpacing: 12, children: items),
              ],
            ),
          ),
        );
    return GameScaffold(
      background: 'logicMarble',
      appBar: AppBar(
        title: const Text('도감'),
        actions: [
          InfoPill(icon: 'codex', text: '+${p.codexBonus}'),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          group('재질', 'shop', [
            for (final m in StoneMaterial.values)
              entry(
                p.materials.contains(m),
                stoneIcon(m, StoneShape.round),
                m.label,
              ),
          ], '${p.materials.length}/${StoneMaterial.values.length}'),
          group('모양', 'stats', [
            for (final s in StoneShape.values)
              entry(
                p.shapes.contains(s),
                stoneIcon(StoneMaterial.cheongok, s),
                s.label,
              ),
          ], '${p.shapes.length}/${StoneShape.values.length}'),
          group('캐릭터', 'free', [
            for (final h in Fighter.values)
              entry(
                p.heroes.contains(h),
                _face(h.name, p.heroes.contains(h)),
                h.label,
              ),
          ], '${p.heroes.length}/${Fighter.values.length}'),
          group('고수', 'arena', [
            for (final b in bosses)
              entry(
                p.codex.contains('고수:$b'),
                _face(Art.bossId(b), p.codex.contains('고수:$b')),
                b,
              ),
          ]),
          group('천기 · 지물', 'wander', [
            for (final w in Weather.values.skip(1))
              entry(
                p.codex.contains('천기:${w.name}'),
                Image.asset(Art.icon('weather'), width: 36),
                w.label,
              ),
            for (final f in FeatureKind.values)
              entry(
                p.codex.contains('지물:${f.name}'),
                Image.asset(Art.icon('terrain'), width: 36),
                f.label,
              ),
          ]),
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
