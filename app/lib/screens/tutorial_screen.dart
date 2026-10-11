import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../game/arena.dart';
import '../game/match.dart';
import '../progress/store.dart';
import '../ui/art.dart';
import '../ui/ghost_hand.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'game_screen.dart';
import 'hero_pick_screen.dart';

/// 입문 한 판(설계서 §16.10): 사부의 한마디와 판 모양.
class Lesson {
  const Lesson(this.title, this.line, this.config);
  final String title;
  final String line;
  final MatchConfig config;
}

/// 입문 판 넷. 글로 설명하지 않고, 시범 손가락을 보고 따라 해서 성공해야 다음으로 간다.
const lessons = [
  Lesson(
    '수련 1 · 톡!',
    '내 돌을 누르고, 검지로 톡! 튕겨 보거라.',
    MatchConfig(
      mode: MatchMode.practice,
      arena: Arena.dustyYard,
      layout: [Placement(0, 8, team: 0), Placement(0, -8)],
      shotLimit: 3,
    ),
  ),
  Lesson(
    '수련 2 · 비스듬히',
    '저 돌을 노려라. 가는 쪽으로 튕기면 된다.',
    MatchConfig(
      mode: MatchMode.practice,
      arena: Arena.dustyYard,
      layout: [Placement(0, 8, team: 0), Placement(-9, -8)],
      shotLimit: 3,
    ),
  ),
  Lesson(
    '수련 3 · 일타쌍피',
    '두 개를 한 번에 떨어뜨려라!',
    MatchConfig(
      mode: MatchMode.practice,
      arena: Arena.dustyYard,
      // 표적을 판 끝 가까이(측정: 곧게 ±10° 친 수의 23%가 한 번에 둘 다 · 2026-10-11).
      layout: [Placement(0, 0, team: 0), Placement(-1.15, -18), Placement(1.15, -18)],
      shotLimit: 3,
    ),
  ),
  Lesson(
    '수련 4 · 첫 대결',
    '이제 나와 한 판! 내 돌을 모두 떨어뜨려 보거라.',
    MatchConfig(
      mode: MatchMode.vsAi,
      difficulty: Difficulty.easy,
      arena: Arena.dustyYard,
      opponentName: '사부',
      layout: [
        Placement(-5, 10, team: 0),
        Placement(5, 10, team: 0),
        Placement(0, 14, team: 0),
        Placement(-5, -10),
        Placement(5, -10),
      ],
    ),
  ),
];

/// 처음 켜면 반드시 거치는 입문(형 지시 2026-10-11: 처음 할 일을 시뮬레이션으로 강제로 익히게).
/// 사부 인사 → 수련 넷(성공해야 다음) → 캐릭터 고르기 → 끝. 뒤로 가기로 빠져나갈 수 없다.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  static const _intro = [
    '어서 오너라. 손가락 하나로 천하를 다투는 곳 — 탄지무림이다.',
    '말보다 손이다. 보고 따라 하거라.',
  ];

  int _line = 0;
  int _done = 0;
  bool _busy = false;
  final _strike = ValueNotifier<int>(0);

  @override
  void dispose() {
    _strike.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_busy) return;
    Sound.play('ui_tap');
    if (_line < _intro.length - 1) {
      setState(() => _line++);
      _strike.value++;
      return;
    }
    _busy = true;
    final nav = Navigator.of(context);
    for (var i = _done; i < lessons.length; i++) {
      final l = lessons[i];
      var won = false;
      // 입문 판은 이길 때까지(GameScreen coach 가 지면 저절로 다시 둔다).
      while (!won && mounted) {
        won = await nav.push<bool>(
              gameRoute(
                GameScreen(
                  key: ValueKey('lesson-$i'),
                  config: l.config,
                  title: l.title,
                  coach: true,
                  coachLines: [l.line],
                ),
              ),
            ) ??
            false;
      }
      if (!mounted) return;
      Sound.play('tutorial_ok');
      setState(() => _done = i + 1);
    }
    if (!mounted) return;
    final store = ProfileStore.instance;
    // 캐릭터가 아직 없을 때만 고른다(다시 하기·옛 저장은 그대로).
    if (store.profile.hero == null) {
      await nav.push(gameRoute<void>(const HeroPickScreen(fromTutorial: true)));
    }
    store.profile.tutorialDone = true;
    await store.save();
    if (mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busy;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SceneBackground(
          asset: Art.background('dustyYard'),
          dim: 0.25,
          motes: Motes.petals,
          child: SafeArea(
            child: GestureDetector(
              key: const Key('tutorial-next'),
              behavior: HitTestBehavior.opaque,
              onTap: busy ? null : _next,
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  const OutlinedText('입문 수련', size: 34, title: true, color: Palette.gold),
                  const SizedBox(height: 6),
                  // 진행: 수련 넷 중 몇 개.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < lessons.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Image.asset(Art.icon(i < _done ? 'star' : 'star_empty'), width: 34),
                        ),
                    ],
                  ),
                  const Spacer(),
                  CharacterSprite(id: 'sabu', height: 330, attack: _strike),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Container(
                      key: const Key('tutorial-line'),
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                      decoration: BoxDecoration(
                        color: Palette.paper,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF2A1A12), width: 3),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('사부', style: TextStyle(fontFamily: titleFont, fontSize: 16, color: Palette.redDeep)),
                          Text(
                            busy ? '좋다. 다음 수련이다!' : _intro[_line],
                            style: const TextStyle(fontFamily: bodyFont, fontSize: 22, color: Color(0xFF2A1A12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 110,
                    child: busy
                        ? null
                        // 아무 데나 누르면 다음 — 말 대신 톡톡 누르는 손이 알려 준다.
                        : Center(
                            child: SizedBox(
                              width: 140,
                              height: 100,
                              child: Ghost(
                                builder: (t) => GhostTapPainter(at: const Offset(60, 36), t: t, size: 60, ring: 26),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
