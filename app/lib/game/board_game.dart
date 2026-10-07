import 'dart:math' as math;
import 'dart:ui';

import 'package:alkkagi_physics/alkkagi_physics.dart' as phys;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';

import 'arena.dart';
import 'board_paint.dart';
import 'match.dart';

/// 대전장과 돌을 그리고, 손가락으로 누른 돌을 "공격할 돌"로 고른다.
///
/// 물리는 고정 1/60초로 진행하고, 화면은 그 결과를 그린다(설계서 §3.1).
/// 쏘기는 고른 돌을 가까이 보는 화면에서 손가락으로 튕겨서 한다.
class BoardGame extends FlameGame with TapCallbacks {
  BoardGame(
    this.match, {
    required this.canTouch,
    required this.onSelect,
    required this.selected,
  });

  final Match match;

  /// 지금 손가락으로 돌을 고를 수 있는 차례인가(AI 차례면 false).
  final bool Function() canTouch;

  /// 돌을 골랐을 때.
  final void Function(phys.Stone stone) onSelect;

  /// 지금 고른 돌(없으면 null).
  final phys.Stone? Function() selected;

  double _acc = 0;
  double _scale = 1;
  Offset _origin = Offset.zero;

  /// 판 둘레 여백(cm).
  static const double margin = 1.6;

  Arena get arena => match.config.arena;

  @override
  Color backgroundColor() => arena.outside;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    const span = phys.PhysicsConstants.board + margin * 2;
    _scale = math.min(size.x, size.y) / span;
    _origin = Offset(size.x / 2, size.y / 2);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!match.isMoving) return;
    _acc += math.min(dt, 0.1);
    while (_acc >= phys.PhysicsConstants.step && match.isMoving) {
      _acc -= phys.PhysicsConstants.step;
      match.step();
    }
    if (!match.isMoving) _acc = 0;
  }

  Offset _toScreen(double x, double y) =>
      Offset(_origin.dx + x * _scale, _origin.dy + y * _scale);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    paintArena(canvas, arena, _toScreen, _scale);
    final pick = canTouch() ? selected() : null;
    for (final s in match.table.stones) {
      if (s.out) continue;
      paintTopStone(
        canvas,
        _toScreen(s.position.x, s.position.y),
        phys.PhysicsConstants.stoneRadius * _scale,
        s.team,
        s.material,
        ring: canTouch() && match.canShoot(s),
        selected: identical(s, pick),
      );
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    if (!canTouch() || match.isMoving || match.isOver) return;
    final p = event.canvasPosition;
    final wx = (p.x - _origin.dx) / _scale, wy = (p.y - _origin.dy) / _scale;
    phys.Stone? best;
    var bestD = phys.PhysicsConstants.stoneRadius * 2.4;
    for (final s in match.table.stones) {
      if (!match.canShoot(s)) continue;
      final d = Match.distance(s.position, wx, wy);
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    if (best == null) return;
    HapticFeedback.selectionClick();
    onSelect(best);
  }
}
