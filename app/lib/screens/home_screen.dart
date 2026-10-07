import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';

import '../game/arena.dart';
import '../game/match.dart';
import 'game_screen.dart';

/// 첫 화면: 모드·난이도·대전장·내 돌(재질·모양)을 고른다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Difficulty _difficulty = Difficulty.easy;
  StoneMaterial _material = StoneMaterial.cheongok;
  StoneShape _shape = StoneShape.round;
  Arena _arena = Arena.dustyYard;

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
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          children: [
            Text(
              '탄지 무림',
              textAlign: TextAlign.center,
              style: t.displaySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '손끝으로 펼치는 무협 알까기',
              textAlign: TextAlign.center,
              style: t.titleMedium,
            ),
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
            const SizedBox(height: 24),
            Text(
              '공격할 내 돌을 누르면 그 돌을 가까이 보는 화면으로 바뀝니다.\n'
              '손끝으로 돌을 튕기세요. 튕긴 방향으로, 빠르게 튕길수록 세게 나갑니다.\n'
              '돌 윗부분을 치면 맞힌 뒤 밀고 나가고, 아랫부분을 치면 끌려옵니다.\n'
              '상대 돌을 모두 판 밖으로 떨어뜨리면 이깁니다.',
              style: t.bodyMedium?.copyWith(height: 1.5),
            ),
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
