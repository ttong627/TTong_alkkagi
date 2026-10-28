import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../progress/quests.dart';
import '../progress/store.dart';
import '../story/chapters.dart';
import '../story/course.dart';
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'campaign_screen.dart';
import 'encounter_flow.dart';
import 'game_screen.dart';

/// 장 하나의 코스(2026-10-14 형 「단계별 코스에 졸개나 중간 단계를 7~9단계로 구성하고
/// 3, 4단계마다 중간보스 등장, 마지막 단계에서 보스 등장」): 졸개 → 중간 보스 → … → 보스.
class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key, required this.course});
  final Course course;

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  final _store = ProfileStore.instance;

  Course get c => widget.course;

  /// 단계 제목: 이야기 판이면 그 고수 이름.
  String _foe(int i) {
    final s = c.steps[i];
    if (s.stageId case final id?) {
      final st = campaign.firstWhere((x) => x.id == id);
      return st.rival != null ? '숙적 ${st.boss}' : st.boss;
    }
    if (s.rematch case final st?) return '환영 · ${st.boss}';
    return s.foe ?? c.minion;
  }

  Future<void> _open(int i) async {
    final s = c.steps[i];
    if (s.stageId case final id?) {
      await playStage(context, campaign.indexWhere((x) => x.id == id));
    } else {
      await _playStep(i);
    }
    if (mounted) setState(() {});
  }

  /// 졸개·중간 보스·재대결 한 판.
  Future<void> _playStep(int i) async {
    final p = _store.profile;
    final s = c.steps[i];
    await showPrologueOnce(context);
    if (!mounted) return;
    if (s.kind != StepKind.minion) Sound.play('jingle_chapter');
    final again = s.rematch;
    final won = await Navigator.of(context).push<bool>(
      gameRoute(
        GameScreen(
          config: CourseRules.configFor(p, c, i, easy: p.easyMode),
          title: '${c.chapter}장 ${i + 1}단계 · ${_foe(i)}',
          boss: s.kind != StepKind.minion,
          stageId: c.idOf(i),
          quips: again?.quips ?? const [],
        ),
      ),
    );
    if (won == null || !mounted) return;
    final r = CourseRules.finish(p, c, i, won: won);
    await _store.save();
    if (!mounted) return;
    await showRewardDialog(
      context,
      title: won ? '승리!' : '패배',
      won: won,
      items: [
        if (r.coins > 0) ('coin', '+${r.coins}'),
        for (final e in r.bag.entries)
          ('chest', '${Bag.label(e.key)} +${e.value}'),
      ],
      note: won ? null : '${_foe(i)}에게 졌다. 다시!',
    );
    if (won && mounted) await afterRound(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = _store.profile;
    return GameScaffold(
      title: '${c.chapter}장 코스',
      background: c.boss.arena.name,
      dim: 0.55,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedText(
              '${c.boss.title} — ${CourseRules.doneCount(p, c)}/${c.steps.length} 단계',
              size: 18,
              title: true,
            ),
          ),
          for (var i = 0; i < c.steps.length; i++)
            _StepTile(
              key: Key('step-${c.idOf(i)}'),
              n: i + 1,
              kind: c.steps[i].kind,
              foe: _foe(i),
              stones: c.steps[i].stones,
              stars: p.stars[c.idOf(i)] ?? 0,
              done: p.done.contains(c.idOf(i)),
              lock: CourseRules.lockReason(p, c, i),
              onTap: () => _open(i),
            ),
        ],
      ),
    );
  }
}

/// 코스 한 칸: 단계 번호 · 종류(색) · 상대 · 돌 수 · 별.
class _StepTile extends StatelessWidget {
  const _StepTile({
    super.key,
    required this.n,
    required this.kind,
    required this.foe,
    required this.stones,
    required this.stars,
    required this.done,
    required this.lock,
    required this.onTap,
  });
  final int n;
  final StepKind kind;
  final String foe;
  final int stones;
  final int stars;
  final bool done;
  final String? lock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      StepKind.minion => const Color(0xFF8A8F9C),
      StepKind.mid => const Color(0xFFE08A2E),
      StepKind.boss => Palette.red,
    };
    final big = kind != StepKind.minion;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: lock == null
            ? () {
                Sound.play('ui_open');
                onTap();
              }
            : () => Sound.play('error', 0.6),
        child: Opacity(
          opacity: lock == null ? 1 : 0.55,
          child: GlassPanel(
            radius: 16,
            padding: EdgeInsets.all(big ? 12 : 8),
            child: Row(
              children: [
                Container(
                  width: big ? 52 : 42,
                  height: big ? 52 : 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? Palette.gold : color,
                    border: Border.all(color: Colors.white70, width: 2),
                  ),
                  child: Text(
                    '$n',
                    style: TextStyle(
                      fontFamily: titleFont,
                      fontSize: big ? 24 : 20,
                      color: const Color(0xFF2A1A12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${kind.label} · $foe',
                        style: TextStyle(
                          fontFamily: titleFont,
                          fontSize: big ? 19 : 16,
                          color: big ? color : Palette.text,
                        ),
                      ),
                      Text(
                        lock ?? '상대 돌 $stones개',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Palette.dim,
                        ),
                      ),
                    ],
                  ),
                ),
                for (var k = 0; k < 3; k++)
                  Image.asset(
                    Art.icon(k < stars ? 'star' : 'star_empty'),
                    width: 20,
                  ),
                const SizedBox(width: 6),
                Icon(
                  lock != null
                      ? Icons.lock
                      : (done ? Icons.check_circle : Icons.play_circle_fill),
                  color: lock != null
                      ? Colors.white38
                      : (done ? Palette.jade : Palette.gold),
                  size: 32,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
