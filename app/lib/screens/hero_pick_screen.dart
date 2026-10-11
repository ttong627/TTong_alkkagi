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

  /// 양옆 무인이 빼꼼 보이게(셋이라는 게 한눈에).
  final _page = PageController(viewportFraction: 0.72);
  final _strike = ValueNotifier<int>(0);
  int _i = 0;
  bool _picking = false;

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

  void _go(int i) {
    if (i < 0 || i >= _heroes.length) return;
    _page.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pick() async {
    // 빠르게 두 번 눌러도 한 번만(두 번 닫히면 입문·로비까지 닫힌다).
    if (_picking) return;
    _picking = true;
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
    final compact = MediaQuery.sizeOf(context).height < 620;
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
                SizedBox(height: compact ? 8 : 16),
                OutlinedText(
                  '누구로 강호에 나설까?',
                  size: compact ? 24 : 28,
                  title: true,
                  color: Palette.gold,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      PageView.builder(
                        key: const Key('hero-pages'),
                        controller: _page,
                        itemCount: _heroes.length,
                        onPageChanged: (i) {
                          Sound.play('whoosh', 0.6);
                          setState(() => _i = i);
                          _strike.value++;
                        },
                        itemBuilder: (_, i) => _HeroCard(
                          hero: _heroes[i],
                          bars: _bars[_heroes[i]]!,
                          on: i == _i,
                          strike: _strike,
                          onSide: () => _go(i),
                        ),
                      ),
                      // 좌우 화살표: 밀어도 되고, 눌러도 넘어간다.
                      Positioned(
                        left: 4,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _Arrow(
                            key: const Key('hero-prev'),
                            left: true,
                            enabled: _i > 0,
                            onTap: () => _go(_i - 1),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _Arrow(
                            key: const Key('hero-next'),
                            left: false,
                            enabled: _i < _heroes.length - 1,
                            onTap: () => _go(_i + 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 점: 셋 가운데 몇 번째.
                Row(
                  key: const Key('hero-dots'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _heroes.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _i ? 24 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: i == _i ? Palette.gold : Colors.white38,
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(32, compact ? 6 : 10, 32, 14),
                  child: GameButton(
                    key: const Key('hero-pick'),
                    label: '이 무인으로!',
                    color: Palette.red,
                    height: compact ? 60 : 70,
                    fontSize: compact ? 24 : 28,
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

/// 무인 한 명: 그림은 남는 높이에 맞추고, 이름·힘·재주·집중 막대가 늘 보인다.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.hero,
    required this.bars,
    required this.on,
    required this.strike,
    required this.onSide,
  });
  final Fighter hero;
  final (int, int, int) bars;
  final bool on;
  final ValueNotifier<int> strike;
  final VoidCallback onSide;

  @override
  Widget build(BuildContext context) {
    final (pw, fi, fo) = bars;
    return LayoutBuilder(
      builder: (context, box) {
        // 그림 높이: 남는 높이의 절반쯤(나머지는 이름·막대) — 크기는 330 까지.
        final art = (box.maxHeight * 0.5).clamp(80.0, 330.0);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // 옆에 보이는 무인을 누르면 그쪽으로.
          onTap: on ? null : onSide,
          child: AnimatedScale(
            scale: on ? 1 : 0.9,
            duration: const Duration(milliseconds: 250),
            child: AnimatedOpacity(
              opacity: on ? 1 : 0.55,
              duration: const Duration(milliseconds: 250),
              child: Center(
                // 어떤 글자 크기에서도 넘치지 않게: 모자라면 통째로 작아진다.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CharacterSprite(
                        id: hero.name,
                        height: art,
                        attack: on ? strike : null,
                        onTap: on ? () => Sound.play('whoosh') : null,
                      ),
                      OutlinedText(hero.label, size: 36, title: true),
                      const SizedBox(height: 6),
                      GlassPanel(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Bar(icon: 'stats', label: '힘', value: pw),
                            _Bar(icon: 'free', label: '재주', value: fi),
                            _Bar(icon: 'naegong', label: '집중', value: fo),
                            const SizedBox(height: 4),
                            Text(
                              hero.trait.split(' · ').last,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 좌우 넘김 화살표(누를 자리 52dp).
class _Arrow extends StatelessWidget {
  const _Arrow({
    super.key,
    required this.left,
    required this.enabled,
    required this.onTap,
  });
  final bool left;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: left ? '이전 무인' : '다음 무인',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () {
              Sound.play('ui_tap', 0.7);
              onTap();
            }
          : null,
      child: SizedBox(
        width: 52,
        height: 52,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.25,
          duration: const Duration(milliseconds: 200),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.6),
              border: Border.all(color: Palette.gold, width: 2),
            ),
            child: Icon(
              left ? Icons.chevron_left : Icons.chevron_right,
              color: Palette.gold,
              size: 34,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.icon, required this.label, required this.value});
  final String icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(Art.icon(icon), width: 26),
        const SizedBox(width: 4),
        SizedBox(
          width: MediaQuery.textScalerOf(context).scale(40),
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
        for (var i = 0; i < 5; i++)
          Container(
            width: 24,
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
