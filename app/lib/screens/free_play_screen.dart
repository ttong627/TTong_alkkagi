import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';

import '../game/arena.dart';
import '../game/fx_colors.dart';
import '../game/match.dart';
import '../game/schools.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'game_screen.dart';
import 'shop_screen.dart' show stoneIcon;

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
    return GameScaffold(
      background: 'dustyYard',
      appBar: AppBar(title: const Text('자유 대전')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _Section(
            title: '난이도',
            icon: 'rank',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in Difficulty.values)
                  GameChip(
                    label: d.label,
                    selected: _difficulty == d,
                    onTap: () => setState(() => _difficulty = d),
                  ),
              ],
            ),
          ),
          _Section(
            title: '대전장',
            icon: 'campaign',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in Arena.values)
                      GameChip(
                        leading: CircleAvatar(
                          radius: 9,
                          backgroundColor: a.floor,
                        ),
                        label: a.label,
                        selected: _arena == a,
                        onTap: () => setState(() => _arena = a),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_arena.chapter} · ${_arena.feel}',
                  style: const TextStyle(fontSize: 14, color: Palette.dim),
                ),
              ],
            ),
          ),
          _Section(
            title: '내 돌',
            icon: 'shop',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in StoneMaterial.values)
                      GameChip(
                        leading: stoneIcon(m, _shape),
                        label: m.label,
                        selected: _material == m,
                        onTap: () => setState(() => _material = m),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in StoneShape.values)
                      GameChip(
                        leading: stoneIcon(_material, s),
                        label: s.label,
                        selected: _shape == s,
                        onTap: () => setState(() => _shape = s),
                      ),
                  ],
                ),
              ],
            ),
          ),
          _Section(
            title: '문파 무공',
            icon: 'naegong',
            trailing: HelpButton(
              title: _martial.label,
              lines: [(null, martialHelp(_martial))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (t, school) in schools)
                      GameChip(
                        leading: CircleAvatar(
                          radius: 9,
                          backgroundColor: techniqueColor(t),
                        ),
                        label: school,
                        selected: _martial == t,
                        onTap: () => setState(() => _martial = t),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _martial.label,
                  style: const TextStyle(fontSize: 16, color: Palette.dim),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GameButton(
            label: '혼자 하기',
            icon: 'arena',
            height: 64,
            onTap: () => _start(MatchMode.vsAi),
          ),
          const SizedBox(height: 8),
          GameButton(
            label: '둘이 하기',
            icon: 'free',
            color: Palette.jade,
            height: 64,
            onTap: () => _start(MatchMode.twoPlayer),
          ),
          const SizedBox(height: 8),
          GameButton(
            label: '연습',
            icon: 'training',
            color: Palette.sky,
            height: 56,
            fontSize: 22,
            onTap: () => _start(MatchMode.practice),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 18, color: Palette.dim),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  '성장·보상 없는 놀이터',
                  style: TextStyle(fontSize: 15, color: Palette.dim),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 설정 한 묶음: 어두운 판 + 그림 머리글.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });
  final String title;
  final String icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHead(title, icon: icon, trailing: trailing),
          child,
        ],
      ),
    ),
  );
}
