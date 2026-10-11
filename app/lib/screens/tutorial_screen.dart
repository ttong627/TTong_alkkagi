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
      layout: [
        Placement(0, 0, team: 0),
        Placement(-1.15, -18),
        Placement(1.15, -18),
      ],
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
/// 사부 인사 → 캐릭터 고르기 → 수련 넷(성공해야 다음) → 끝.
/// 처음에는 뒤로 가기로 빠져나갈 수 없다. 설정에서 다시 하는 [replay] 는 언제든 「나가기」.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, this.replay = false});

  /// 설정에서 다시 하기: 시스템 뒤로 가기와 「나가기」 단추로 빠질 수 있다.
  final bool replay;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

/// 한 수련 판을 이 번 넘게 지면 「넘어가기」가 나온다.
const lessonSkipAfter = 2;

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
    setState(() {});
    final nav = Navigator.of(context);
    final store = ProfileStore.instance;
    // 캐릭터를 먼저 고른다 — 수련 판부터 내 무인으로 친다(다시 하기·옛 저장은 그대로).
    if (store.profile.hero == null) {
      await nav.push(gameRoute<void>(const HeroPickScreen(fromTutorial: true)));
      if (!mounted) return;
    }
    for (var i = _done; i < lessons.length; i++) {
      final l = lessons[i];
      var passed = false;
      // 입문 판은 이길 때까지(GameScreen coach 가 지면 저절로 다시 둔다).
      // 두 번 지면 「넘어가기」가 나온다.
      while (!passed && mounted) {
        final r = await nav.push<bool>(
          gameRoute(_LessonPage(index: i, lesson: l, replay: widget.replay)),
        );
        if (!mounted) return;
        if (r == null && widget.replay) {
          nav.pop(); // 다시 하기에서 「나가기」.
          return;
        }
        passed = r ?? false;
      }
      if (!mounted) return;
      Sound.play('tutorial_ok');
      setState(() => _done = i + 1);
    }
    if (!mounted) return;
    store.profile.tutorialDone = true;
    await store.save();
    if (mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busy;
    return PopScope(
      canPop: widget.replay,
      child: Scaffold(
        body: SceneBackground(
          asset: Art.background('dustyYard'),
          dim: 0.25,
          motes: Motes.petals,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                final h = box.maxHeight;
                final compact = h < 620;
                // 사부 그림은 남는 높이에 맞춘다(큰 화면 330 · 작은 화면은 높이의 40%).
                final master = (h * 0.4).clamp(120.0, 330.0);
                return Stack(
                  children: [
                    GestureDetector(
                      key: const Key('tutorial-next'),
                      behavior: HitTestBehavior.opaque,
                      onTap: busy ? null : _next,
                      child: Column(
                        children: [
                          SizedBox(height: compact ? 8 : 18),
                          OutlinedText(
                            '입문 수련',
                            size: compact ? 28 : 34,
                            title: true,
                            color: Palette.gold,
                          ),
                          const SizedBox(height: 6),
                          // 진행: 수련 넷 중 몇 개.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < lessons.length; i++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Image.asset(
                                    Art.icon(i < _done ? 'star' : 'star_empty'),
                                    width: compact ? 28 : 34,
                                  ),
                                ),
                            ],
                          ),
                          // 남는 자리에 사부 — 모자라면 작아질 뿐 넘치지 않는다.
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: CharacterSprite(
                                  id: 'sabu',
                                  height: master,
                                  attack: _strike,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Container(
                              key: const Key('tutorial-line'),
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                12,
                                18,
                                14,
                              ),
                              decoration: BoxDecoration(
                                color: Palette.paper,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF2A1A12),
                                  width: 3,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '사부',
                                    style: TextStyle(
                                      fontFamily: titleFont,
                                      fontSize: 16,
                                      color: Palette.redDeep,
                                    ),
                                  ),
                                  Text(
                                    busy ? '좋다. 다음 수련이다!' : _intro[_line],
                                    style: const TextStyle(
                                      fontFamily: bodyFont,
                                      fontSize: 22,
                                      color: Color(0xFF2A1A12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 아무 데나 누르면 다음 — 말 대신 톡톡 누르는 손이 알려 준다.
                          SizedBox(
                            height: (h * 0.14).clamp(56.0, 110.0),
                            child: busy
                                ? null
                                : Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: SizedBox(
                                        width: 140,
                                        height: 100,
                                        child: Ghost(
                                          builder: (t) => GhostTapPainter(
                                            at: const Offset(60, 36),
                                            t: t,
                                            size: 60,
                                            ring: 26,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.replay)
                      Positioned(
                        // 제목과 안 겹치게 아래 오른쪽(손 그림은 가운데).
                        bottom: 6,
                        right: 8,
                        child: _ExitButton(
                          key: const Key('tutorial-exit'),
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 눈에 띄는 「나가기」 단추(손가락으로 누르기 쉬운 크기).
class _ExitButton extends StatelessWidget {
  const _ExitButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GameButton(
    label: '나가기',
    color: Palette.skyDeep,
    height: 42,
    width: 104,
    fontSize: 18,
    sound: 'ui_back',
    onTap: onTap,
  );
}

/// 수련 판 한 판: 대전 화면 위에 「넘어가기」(두 번 진 뒤) · 「나가기」(다시 하기일 때)를 얹는다.
/// 닫을 때 값: true = 깼거나 넘어감 · false = 졌음 · null = 나가기.
class _LessonPage extends StatefulWidget {
  const _LessonPage({
    required this.index,
    required this.lesson,
    required this.replay,
  });
  final int index;
  final Lesson lesson;
  final bool replay;

  @override
  State<_LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<_LessonPage> {
  int _fails = 0;

  /// 한 수가 끝날 때마다 불린다 — 판이 끝났는데 내가 못 이겼으면 한 번 진 것.
  void _onTurnEnd(Match m) {
    if (mounted && m.isOver && !(m.winner == 0 && !m.isDraw)) {
      setState(() => _fails++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    final canSkip = _fails >= lessonSkipAfter;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          GameScreen(
            key: ValueKey('lesson-${widget.index}'),
            config: l.config,
            title: l.title,
            coach: true,
            coachLines: [l.line],
            onTurnEnd: _onTurnEnd,
          ),
          if (canSkip || widget.replay)
            Positioned(
              left: 12,
              right: 12,
              bottom: 8,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.replay)
                      _ExitButton(
                        key: const Key('lesson-exit'),
                        onTap: () => Navigator.of(context).pop(),
                      )
                    else
                      const SizedBox.shrink(),
                    if (canSkip)
                      GameButton(
                        key: const Key('lesson-skip'),
                        label: '넘어가기 ▶',
                        color: Palette.jade,
                        height: 42,
                        width: 140,
                        fontSize: 18,
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
