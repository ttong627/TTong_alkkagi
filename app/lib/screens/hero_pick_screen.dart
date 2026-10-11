import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../progress/profile.dart';
import '../progress/store.dart';
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

/// 캐릭터 고르기(설계서 §2.1): 처음 셋 가운데 하나. 좌우로 넘기며 그림을 보고 고른다.
class HeroPickScreen extends StatefulWidget {
  const HeroPickScreen({super.key, this.fromTutorial = false});

  /// 입문 끝에서 부르면 뒤로 가기를 막는다(반드시 고른다).
  final bool fromTutorial;

  @override
  State<HeroPickScreen> createState() => _HeroPickScreenState();
}

class _HeroPickScreenState extends State<HeroPickScreen> {
  final _heroes = Fighter.values.where((h) => h.starter).toList();
  final _page = PageController(viewportFraction: 0.82);
  final _strike = ValueNotifier<int>(0);
  int _i = 0;

  /// 셋의 성격을 그림으로: 힘·재주·집중 막대.
  static const _bars = {
    Fighter.seokdu: (5, 2, 3),
    Fighter.yeonbi: (3, 5, 2),
    Fighter.cheongmyeong: (2, 3, 5),
  };

  @override
  void dispose() {
    _page.dispose();
    _strike.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final h = _heroes[_i];
    final store = ProfileStore.instance;
    store.profile
      ..hero = h
      ..heroes.add(h)
      ..codex.add('캐릭터:${h.name}');
    await store.save();
    Sound.play('unlock');
    if (mounted) Navigator.of(context).pop(h);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          !widget.fromTutorial && ProfileStore.instance.profile.hero != null,
      child: Scaffold(
        body: SceneBackground(
          asset: Art.background('lobby'),
          dim: 0.35,
          motes: Motes.petals,
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                const OutlinedText(
                  '누구로 강호에 나설까?',
                  size: 28,
                  title: true,
                  color: Palette.gold,
                ),
                Expanded(
                  child: PageView.builder(
                    key: const Key('hero-pages'),
                    controller: _page,
                    itemCount: _heroes.length,
                    onPageChanged: (i) {
                      Sound.play('whoosh', 0.6);
                      setState(() => _i = i);
                      _strike.value++;
                    },
                    itemBuilder: (_, i) {
                      final h = _heroes[i];
                      final (pw, fi, fo) = _bars[h]!;
                      final on = i == _i;
                      return AnimatedScale(
                        scale: on ? 1 : 0.86,
                        duration: const Duration(milliseconds: 250),
                        child: AnimatedOpacity(
                          opacity: on ? 1 : 0.55,
                          duration: const Duration(milliseconds: 250),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CharacterSprite(
                                id: h.name,
                                height: 330,
                                attack: on ? _strike : null,
                                onTap: () => Sound.play('whoosh'),
                              ),
                              OutlinedText(h.label, size: 40, title: true),
                              const SizedBox(height: 8),
                              GlassPanel(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  10,
                                  16,
                                  12,
                                ),
                                child: Column(
                                  children: [
                                    _Bar(icon: 'stats', value: pw),
                                    _Bar(icon: 'free', value: fi),
                                    _Bar(icon: 'naegong', value: fo),
                                    const SizedBox(height: 6),
                                    Text(
                                      h.trait.split(' · ').last,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 20),
                  child: GameButton(
                    key: const Key('hero-pick'),
                    label: '이 무인으로!',
                    color: Palette.red,
                    height: 70,
                    fontSize: 28,
                    onTap: _pick,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.icon, required this.value});
  final String icon;
  final int value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(Art.icon(icon), width: 26),
        const SizedBox(width: 8),
        for (var i = 0; i < 5; i++)
          Container(
            width: 26,
            height: 12,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i < value ? Palette.gold : Colors.white12,
              border: Border.all(color: Colors.black45),
            ),
          ),
      ],
    ),
  );
}
