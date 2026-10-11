import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';

import '../game/arena.dart';
import '../game/fx_colors.dart';
import '../game/match.dart';
import '../game/schools.dart';
import 'game_screen.dart';

/// 자유 대전: 모드·난이도·대전장·돌(재질·모양)·무공을 마음대로 골라 친다(성장·보상 없음).
class FreePlayScreen extends StatefulWidget {
  const FreePlayScreen({super.key, this.autoPractice = false});

  /// 시험 판(E2E_FLICK): 켜자마자 연습 판을 연다.
  final bool autoPractice;

  @override
  State<FreePlayScreen> createState() => _FreePlayScreenState();
}

class _FreePlayScreenState extends State<FreePlayScreen> {
  Difficulty _difficulty = Difficulty.easy;
  StoneMaterial _material = StoneMaterial.cheongok;
  StoneShape _shape = StoneShape.round;
  Arena _arena = Arena.dustyYard;
  Technique _martial = Technique.swordQi;

  @override
  void initState() {
    super.initState();
    if (widget.autoPractice) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _start(MatchMode.practice),
      );
    }
  }

  void _start(MatchMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          config: MatchConfig(
            mode: mode,
            difficulty: _difficulty,
            myMaterial: _material,
            myShape: _shape,
            arena: _arena,
            martial: _martial,
            opponentMartial: mode == MatchMode.twoPlayer
                ? _martial
                : Technique.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('자유 대전')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const SizedBox(height: 28),
            _Section(
              title: 'AI 난이도',
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<Difficulty>(
                  showSelectedIcon: false,
                  segments: [
                    for (final d in Difficulty.values)
                      ButtonSegment(value: d, label: Text(d.label)),
                  ],
                  selected: {_difficulty},
                  onSelectionChanged: (s) =>
                      setState(() => _difficulty = s.first),
                ),
              ),
            ),
            _Section(
              title: '대전장',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in Arena.values)
                        ChoiceChip(
                          avatar: CircleAvatar(backgroundColor: a.floor),
                          label: Text(a.label),
                          selected: _arena == a,
                          onSelected: (_) => setState(() => _arena = a),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_arena.chapter} · ${_arena.feel}',
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
            _Section(
              title: '내 돌 재질',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in StoneMaterial.values)
                    ChoiceChip(
                      label: Text(m.label),
                      selected: _material == m,
                      onSelected: (_) => setState(() => _material = m),
                    ),
                ],
              ),
            ),
            _Section(
              title: '내 돌 모양',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in StoneShape.values)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _shape == s,
                      onSelected: (_) => setState(() => _shape = s),
                    ),
                ],
              ),
            ),
            _Section(
              title: '문파 무공 (내공 타격 때 발동)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (t, school) in schools)
                        ChoiceChip(
                          avatar: CircleAvatar(
                            backgroundColor: techniqueColor(t),
                          ),
                          label: Text('$school · ${t.label}'),
                          selected: _martial == t,
                          onSelected: (_) => setState(() => _martial = t),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(martialHelp(_martial), style: t.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _start(MatchMode.vsAi),
              child: const _BigLabel('혼자 하기 (AI 대전)'),
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: () => _start(MatchMode.twoPlayer),
              child: const _BigLabel('둘이 하기 (한 기기)'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _start(MatchMode.practice),
              child: const _BigLabel('연습'),
            ),
            const SizedBox(height: 16),
            Text('자유 대전은 성장·보상이 없습니다. 강호행·목인항에서 실력을 키우세요.', style: t.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _BigLabel extends StatelessWidget {
  const _BigLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Text(text, style: const TextStyle(fontSize: 18)),
  );
}
