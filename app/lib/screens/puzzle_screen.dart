import 'package:flutter/material.dart';

import '../game/match.dart';
import '../progress/profile.dart';
import '../progress/store.dart';
import '../story/puzzles.dart';
import '../story/trickshots.dart';
import 'encounter_flow.dart';
import 'game_screen.dart';
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

/// 묘수풀이(설계서 §8.1 · §16.15): 정해진 수 안에 표적을 모두 떨어뜨린다.
/// 목인항 기본 4판 + 트릭샷 6묶음 × 10판(시간 제한 · 남은 시간으로 별 셋).
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key});

  /// 묶음을 여는 데 앞 묶음에서 풀어야 할 판 수.
  static const int unlockTier = 5;

  /// 트릭샷 [z] 를 지금 할 수 있나: 묶음 첫 판은 앞 묶음 [unlockTier] 판, 그다음은 바로 앞 판을 풀어야 한다.
  static bool trickOpen(Profile p, Puzzle z) {
    final i = trickshots.indexOf(z);
    if (i <= 0) return true;
    final tier = (z.id - 1000) ~/ 10;
    if ((z.id - 1000) % 10 == 0) {
      final prev = trickshots.where((x) => (x.id - 1000) ~/ 10 == tier - 1);
      return prev.where((x) => p.puzzles.contains(x.id)).length >= unlockTier;
    }
    return p.puzzles.contains(trickshots[i - 1].id);
  }

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  @override
  void initState() {
    super.initState();
    // 첫 방문 안내(설계서 §16.13).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) =>
          firstVisit(context, 'puzzle', '정해진 수 안에 표적을 모두 떨어뜨려라. 빨리 풀수록 별이 많다!'),
    );
  }

  final _store = ProfileStore.instance;

  Future<void> _play(Puzzle z, {bool trick = false}) async {
    final p = _store.profile;
    final base = MatchConfig(
      mode: MatchMode.practice,
      myMaterial: p.material,
      myShape: p.shape,
      myTrail: p.trailOrNull,
      powerScale: p.maxSpeed / baseMaxSpeed,
      spinScale: p.spinScale,
    );
    GameScreen.lastStars = 0;
    final won = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          title: '${trick ? '트릭샷' : '묘수풀이'} · ${z.title}',
          info: () => z.help,
          config: z.config(base),
          timeLimit: z.seconds,
        ),
      ),
    );
    if (won == null || !mounted) return;
    final first = won && p.puzzles.add(z.id);
    if (first) p.trainingPoints += z.reward;
    var bonus = 0;
    if (trick && won) {
      final before = p.puzzleStars[z.id] ?? 0;
      p.recordPuzzleStars(z.id, GameScreen.lastStars);
      // 처음 별 셋이면 엽전 덤.
      if (before < 3 && (p.puzzleStars[z.id] ?? 0) == 3) {
        bonus = 20;
        p.coins += bonus;
      }
    }
    await _store.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          won
              ? [
                  if (trick) '★' * GameScreen.lastStars,
                  first ? '풀었다! 수련 +${z.reward}' : '다시 풀었다',
                  if (bonus > 0) '별 셋 덤 엽전 +$bonus',
                ].join(' · ')
              : '못 풀었다 — 다시!',
        ),
      ),
    );
    setState(() {});
    // 기연은 처음 풀었을 때만 뽑는다(열었다 닫기로 뽑던 구멍 — 2026-10-11).
    if (first) await afterRound(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    return GameScaffold(
      background: 'turtleMarket',
      appBar: AppBar(
        title: const Text('묘수풀이'),
        actions: [
          HelpButton(
            title: '묘수풀이',
            lines: [
              ('puzzle', '정해진 수 안에 표적을 모두 떨어뜨려요'),
              ('star', '트릭샷은 빨리 풀수록 별이 많아요(시간은 겨누는 동안만 흘러요)'),
              (null, '짚빛 백성 돌을 떨어뜨리면 실패'),
              ('lock', '묶음마다 앞 묶음 ${PuzzleScreen.unlockTier}판을 풀면 열려요'),
              ('tp', '처음 풀면 수련 포인트 · 처음 별 셋이면 엽전'),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          SectionHead(
            '목인항',
            icon: 'puzzle',
            trailing: InfoPill(
              text:
                  '${puzzles.where((z) => p.puzzles.contains(z.id)).length}/${puzzles.length}',
            ),
          ),
          for (final z in puzzles)
            RowCard(
              leading: Image.asset(
                Art.icon(p.puzzles.contains(z.id) ? 'star' : 'puzzle'),
                width: 44,
              ),
              title: '${z.id}. ${z.title}',
              sub: '${z.shots}수',
              trailing: p.puzzles.contains(z.id)
                  ? const Icon(
                      Icons.check_circle,
                      color: Palette.jade,
                      size: 36,
                    )
                  : InfoPill(icon: 'tp', text: '+${z.reward}'),
              onTap: () => _play(z),
            ),
          for (var t = 0; t < trickTierNames.length; t++) ..._tier(p, t),
        ],
      ),
    );
  }

  List<Widget> _tier(Profile p, int t) {
    final list = trickshots.where((z) => (z.id - 1000) ~/ 10 == t).toList();
    if (list.isEmpty) return const [];
    final stars = list.fold<int>(0, (a, z) => a + (p.puzzleStars[z.id] ?? 0));
    return [
      SectionHead(
        '트릭샷 · ${trickTierNames[t]}',
        icon: 'star',
        trailing: InfoPill(icon: 'star', text: '$stars/${list.length * 3}'),
      ),
      LayoutBuilder(
        builder: (context, c) {
          // 한 줄에 5칸(좁은 폰은 칸을 줄인다).
          final w = ((c.maxWidth - 4 * 8) / 5).clamp(52.0, 84.0);
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final z in list)
                _TrickTile(
                  key: Key('trick-${z.id}'),
                  width: w,
                  number: (z.id - 1000) % 10 + 1,
                  floor: z.arena.floor,
                  stars: p.puzzleStars[z.id] ?? 0,
                  solved: p.puzzles.contains(z.id),
                  open: PuzzleScreen.trickOpen(p, z),
                  onTap: () => _play(z, trick: true),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 6),
    ];
  }
}

/// 트릭샷 한 칸: 번호 · 별 셋 · 잠금.
class _TrickTile extends StatelessWidget {
  const _TrickTile({
    super.key,
    required this.width,
    required this.number,
    required this.floor,
    required this.stars,
    required this.solved,
    required this.open,
    required this.onTap,
  });
  final double width;
  final int number;
  final Color floor;
  final int stars;
  final bool solved;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: open ? '$number번 판 · 별 $stars' : '$number번 판 · 잠김',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: open
          ? onTap
          : () =>
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('앞 판을 먼저 풀어요'))),
      child: Container(
        width: width,
        height: width * 1.08,
        decoration: BoxDecoration(
          color: Color.lerp(floor, Colors.black, open ? 0.35 : 0.75),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: solved
                ? Palette.gold
                : Colors.white.withValues(alpha: open ? 0.4 : 0.15),
            width: solved ? 2.5 : 1.5,
          ),
        ),
        child: open
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    child: OutlinedText('$number', size: 26, title: true),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Image.asset(
                          Art.icon(i < stars ? 'star' : 'star_empty'),
                          width: width * 0.24,
                        ),
                    ],
                  ),
                ],
              )
            : Center(child: Image.asset(Art.icon('lock'), width: width * 0.42)),
      ),
    ),
  );
}
