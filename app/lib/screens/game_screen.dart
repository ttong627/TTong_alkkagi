import 'dart:async';

import 'package:alkkagi_physics/alkkagi_physics.dart' as phys;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/ai.dart';
import '../game/board_game.dart';
import '../game/flick.dart';
import '../game/match.dart';
import 'flick_view.dart';

/// 한 판 화면: 위에 차례·남은 돌, 가운데 대전장.
/// 내 돌을 누르면 그 돌을 가까이 보는 화면으로 바뀌고, 거기서 손끝으로 튕긴다.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.config});
  final MatchConfig config;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late Match _match;
  late BoardGame _game;
  phys.Stone? _selected;
  bool _aiThinking = false;
  bool _resultShown = false;

  bool get _aiTurn => widget.config.mode == MatchMode.vsAi && _match.turn == 1;

  @override
  void initState() {
    super.initState();
    _newMatch();
  }

  void _newMatch() {
    _match = Match(widget.config)..addListener(_onMatch);
    _game = BoardGame(
      _match,
      canTouch: () => !_aiTurn && !_aiThinking,
      onSelect: (s) => setState(() => _selected = s),
      selected: () => _selected,
    );
    _selected = null;
    _resultShown = false;
  }

  void _restart() {
    setState(() {
      _match
        ..removeListener(_onMatch)
        ..dispose();
      _newMatch();
    });
  }

  void _onMatch() {
    if (!mounted) return;
    setState(() {});
    if (_match.isOver && !_match.isMoving && !_resultShown) {
      _resultShown = true;
      Future<void>.delayed(const Duration(milliseconds: 400), _showResult);
      return;
    }
    if (_aiTurn && !_match.isMoving && !_aiThinking && !_match.isOver) {
      unawaited(_playAi());
    }
  }

  void _shoot(FlickShot shot) {
    final s = _selected;
    setState(() => _selected = null);
    if (s == null) return;
    _match.shoot(s, shot.angle, shot.speed, shot.hit);
  }

  /// 고른 돌이 판 어디 있는지에 맞춰 가까이 보기 화면이 그 자리에서 커져 나온다.
  Alignment get _zoomFrom {
    final s = _selected;
    if (s == null) return Alignment.center;
    const h = phys.PhysicsConstants.halfBoard;
    return Alignment(s.position.x / h * 0.85, s.position.y / h * 0.6);
  }

  Future<void> _playAi() async {
    setState(() => _aiThinking = true);
    final started = DateTime.now();
    final shot = await chooseAiShot(_match);
    final waited = DateTime.now().difference(started);
    if (waited < const Duration(milliseconds: 700)) {
      await Future<void>.delayed(const Duration(milliseconds: 700) - waited);
    }
    if (!mounted) return;
    setState(() => _aiThinking = false);
    _match.shoot(
      _match.table.stones[shot.stoneId],
      shot.angle,
      shot.speed,
      shot.hit,
    );
  }

  Future<void> _showResult() async {
    if (!mounted) return;
    final String title;
    if (_match.isDraw) {
      title = '비겼습니다';
    } else if (widget.config.mode == MatchMode.practice) {
      title = '연습 끝';
    } else if (widget.config.mode == MatchMode.vsAi) {
      title = _match.winner == 0 ? '이겼습니다!' : '졌습니다';
    } else {
      title = _match.winner == 0 ? '흰 돌 승리' : '검은 돌 승리';
    }
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(
          '${_match.turnCount}수 · 남은 돌 흰 ${_match.alive(0)} : 검 ${_match.alive(1)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('처음으로'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('한 판 더'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (again == true) {
      _restart();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _match
      ..removeListener(_onMatch)
      ..dispose();
    super.dispose();
  }

  String get _status {
    if (_match.isOver) return '판이 끝났습니다';
    if (_match.isMoving) return '돌이 움직이는 중…';
    switch (widget.config.mode) {
      case MatchMode.practice:
        return '어느 돌로 공격할까요?';
      case MatchMode.vsAi:
        return _match.turn == 0
            ? '어느 돌로 공격할까요?'
            : (_aiThinking ? '상대가 수를 읽는 중…' : '상대 차례');
      case MatchMode.twoPlayer:
        return _match.turn == 0 ? '흰 돌 · 어느 돌로 공격할까요?' : '검은 돌 · 어느 돌로 공격할까요?';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.config.mode == MatchMode.vsAi
              ? '${widget.config.mode.label} · ${widget.config.difficulty.label}'
              : widget.config.mode.label,
        ),
        actions: [
          IconButton(
            onPressed: _restart,
            icon: const Icon(Icons.refresh),
            tooltip: '다시 시작',
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _Count(
                        label: widget.config.mode == MatchMode.vsAi
                            ? '상대'
                            : '검',
                        n: _match.alive(1),
                        dark: true,
                      ),
                      Expanded(
                        child: Text(
                          _status,
                          textAlign: TextAlign.center,
                          style: t.titleMedium,
                        ),
                      ),
                      _Count(
                        label: widget.config.mode == MatchMode.vsAi ? '나' : '흰',
                        n: _match.alive(0),
                        dark: false,
                      ),
                    ],
                  ),
                ),
                Expanded(child: GameWidget(game: _game)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Text(
                    '${widget.config.arena.chapter} · ${widget.config.arena.label}',
                    style: t.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween(begin: 0.25, end: 1.0).animate(anim),
                  alignment: _zoomFrom,
                  child: child,
                ),
              ),
              child: _selected == null
                  ? const SizedBox.shrink()
                  : FlickView(
                      key: ValueKey(_selected),
                      match: _match,
                      stone: _selected!,
                      onShot: _shoot,
                      onCancel: () => setState(() => _selected = null),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.n, required this.dark});
  final String label;
  final int n;
  final bool dark;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 9,
        backgroundColor: dark
            ? const Color(0xFF1E1E22)
            : const Color(0xFFF4F1EA),
      ),
      const SizedBox(width: 6),
      Text('$label $n', style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}
