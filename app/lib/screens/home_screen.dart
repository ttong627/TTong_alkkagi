import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';

import '../game/arena.dart';
import '../game/match.dart';
import '../update/updater.dart';
import '../version.dart';
import 'game_screen.dart';

/// 첫 화면: 모드·난이도·대전장·내 돌(재질·모양)을 고른다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _updater = Updater();
  Difficulty _difficulty = Difficulty.easy;
  StoneMaterial _material = StoneMaterial.cheongok;
  StoneShape _shape = StoneShape.round;
  Arena _arena = Arena.dustyYard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updater.addListener(_onUpdate);
    _updater.run();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updater
      ..removeListener(_onUpdate)
      ..dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _updater.resumed();
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
            UpdateBanner(updater: _updater),
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
            const SizedBox(height: 16),
            Text(
              versionLabel,
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(
                color: t.bodySmall?.color?.withValues(alpha: 0.6),
              ),
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

/// 시험판 자동 업데이트 알림 줄. 할 일이 없으면 보이지 않는다.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key, required this.updater});
  final Updater updater;

  @override
  Widget build(BuildContext context) {
    final u = updater;
    final build = u.target?.build;
    final (String text, Widget? action) = switch (u.stage) {
      UpdateStage.idle || UpdateStage.checking => ('', null),
      UpdateStage.needsPermission => (
        '새 판(빌드 $build)이 있습니다. 처음 한 번만 「이 출처 허용」을 켜 주세요. '
            '그다음부터는 저절로 업데이트됩니다.',
        FilledButton(onPressed: u.openPermission, child: const Text('허용하러 가기')),
      ),
      UpdateStage.downloading => ('새 판(빌드 $build) 받는 중 ${u.percent}%', null),
      UpdateStage.installing => (
        '새 판(빌드 $build) 설치 중 — 끝나면 앱이 닫힙니다. 다시 열어 주세요.',
        null,
      ),
      UpdateStage.failed => (
        '업데이트하지 못했습니다: ${u.message}',
        TextButton(onPressed: u.run, child: const Text('다시 시도')),
      ),
    };
    if (text.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(text, style: TextStyle(color: scheme.onSecondaryContainer)),
              if (u.stage == UpdateStage.downloading) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: u.percent / 100),
              ],
              if (action != null) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
