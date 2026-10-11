import 'package:flutter/material.dart';

import '../game/match.dart';
import '../progress/store.dart';
import '../story/puzzles.dart';
import 'encounter_flow.dart';
import 'game_screen.dart';
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

/// 목인항 묘수풀이(설계서 §8.1): 정해진 수 안에 표적을 모두 떨어뜨린다. 처음 풀면 수련 포인트.
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key});

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
          firstVisit(context, 'puzzle', '정해진 수 안에 표적을 모두 떨어뜨려라. 처음 풀면 수련 포인트!'),
    );
  }

  final _store = ProfileStore.instance;

  Future<void> _play(Puzzle z) async {
    final p = _store.profile;
    final won = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          title: '묘수풀이 · ${z.title}',
          info: () => '${z.help} (${z.shots}수)',
          config: MatchConfig(
            mode: MatchMode.practice,
            arena: puzzleArena,
            layout: z.layout,
            shotLimit: z.shots,
            myMaterial: p.material,
            myShape: p.shape,
            powerScale: p.maxSpeed / baseMaxSpeed,
            spinScale: p.spinScale,
          ),
        ),
      ),
    );
    if (won == null || !mounted) return;
    final first = won && p.puzzles.add(z.id);
    if (first) p.trainingPoints += z.reward;
    await _store.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          won
              ? (first ? '풀었다! 수련 포인트 +${z.reward}' : '다시 풀었다')
              : '못 풀었다 — 다시 해 보세요',
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
              ('tp', '처음 풀면 수련 포인트를 받아요'),
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
        ],
      ),
    );
  }
}
