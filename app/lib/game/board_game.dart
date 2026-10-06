import 'dart:math' as math;
import 'dart:ui';

import 'package:alkkagi_physics/alkkagi_physics.dart' as phys;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';

import 'match.dart';

/// 재질마다 돌 테두리 색.
const materialColors = {
  phys.StoneMaterial.cheongok: Color(0xFF3E9C7D),
  phys.StoneMaterial.wood: Color(0xFFB07A3B),
  phys.StoneMaterial.hyeoncheol: Color(0xFF5A6270),
  phys.StoneMaterial.ice: Color(0xFF8FD3EE),
};

/// 바둑판과 돌을 그리고, 손가락으로 끌어 쏘기를 받는다.
///
/// 물리는 고정 1/60초로 진행하고, 화면은 그 결과를 그린다(설계서 §3.1).
class BoardGame extends FlameGame with DragCallbacks {
  BoardGame(this.match, {required this.hit, required this.canTouch});

  final Match match;

  /// 지금 고른 타격점(−1 하 · 0 중 · +1 상).
  final double Function() hit;

  /// 지금 손가락으로 쏠 수 있는 차례인가(AI 차례면 false).
  final bool Function() canTouch;

  double _acc = 0;
  double _scale = 1;
  Offset _origin = Offset.zero;

  phys.Stone? _aimStone;
  Offset? _dragPos;

  /// 판 둘레 여백(cm).
  static const double margin = 1.6;

  @override
  Color backgroundColor() => const Color(0xFF2B2118);

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

  (double, double) _toWorld(Offset p) =>
      ((p.dx - _origin.dx) / _scale, (p.dy - _origin.dy) / _scale);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _drawBoard(canvas);
    for (final s in match.table.stones) {
      if (!s.out) _drawStone(canvas, s);
    }
    _drawAim(canvas);
  }

  void _drawBoard(Canvas canvas) {
    const half = phys.PhysicsConstants.halfBoard;
    final rect = Rect.fromPoints(
      _toScreen(-half, -half),
      _toScreen(half, half),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(_scale * 0.6),
        Radius.circular(_scale * 0.6),
      ),
      Paint()..color = const Color(0xFF8A5A2B),
    );
    canvas.drawRect(rect, Paint()..color = const Color(0xFFDDB06A));
    final line = Paint()
      ..color = const Color(0xFF5B3A1A)
      ..strokeWidth = math.max(1, _scale * 0.06);
    const n = 19;
    const first = -(n - 1) / 2 * gridGap;
    for (var i = 0; i < n; i++) {
      final v = first + i * gridGap;
      canvas.drawLine(_toScreen(first, v), _toScreen(-first, v), line);
      canvas.drawLine(_toScreen(v, first), _toScreen(v, -first), line);
    }
    final star = Paint()..color = const Color(0xFF5B3A1A);
    for (final i in [3, 9, 15]) {
      for (final j in [3, 9, 15]) {
        canvas.drawCircle(
          _toScreen(first + i * gridGap, first + j * gridGap),
          _scale * 0.22,
          star,
        );
      }
    }
  }

  void _drawStone(Canvas canvas, phys.Stone s) {
    final p = s.position;
    final c = _toScreen(p.x, p.y);
    final r = phys.PhysicsConstants.stoneRadius * _scale;
    canvas.drawCircle(
      c.translate(r * 0.12, r * 0.18),
      r,
      Paint()..color = const Color(0x55000000),
    );
    final base = s.team == 0
        ? const Color(0xFFF4F1EA)
        : const Color(0xFF1E1E22);
    final shine = s.team == 0
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF4A4A52);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = Gradient.radial(c.translate(-r * 0.35, -r * 0.35), r * 1.3, [
          shine,
          base,
        ]),
    );
    canvas.drawCircle(
      c,
      r * 0.86,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.22
        ..color = materialColors[s.material]!,
    );
    if (match.canShoot(s) && canTouch()) {
      canvas.drawCircle(
        c,
        r * 1.25,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, r * 0.1)
          ..color = const Color(0xAAFFE08A),
      );
    }
  }

  /// 끈 반대 방향으로 쏜다. 화살표 길이는 세기.
  void _drawAim(Canvas canvas) {
    final s = _aimStone, d = _dragPos;
    if (s == null || d == null) return;
    final shot = _shotFromDrag(s, d);
    if (shot == null) return;
    final (angle, speed) = shot;
    final p = s.position;
    final from = _toScreen(p.x, p.y);
    final len = 3 + speed / baseMaxSpeed * 12;
    final to = _toScreen(
      p.x + math.cos(angle) * len,
      p.y + math.sin(angle) * len,
    );
    final power = speed / baseMaxSpeed;
    final color = Color.lerp(
      const Color(0xFFFFE08A),
      const Color(0xFFE5482F),
      power,
    )!;
    final paint = Paint()
      ..color = color
      ..strokeWidth = math.max(2, _scale * 0.25)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
    final head = _scale * 1.0;
    for (final a in [angle + 2.6, angle - 2.6]) {
      canvas.drawLine(
        to,
        to.translate(math.cos(a) * head, math.sin(a) * head),
        paint,
      );
    }
    canvas.drawLine(
      from,
      d,
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..strokeWidth = math.max(1, _scale * 0.08),
    );
  }

  (double, double)? _shotFromDrag(phys.Stone s, Offset drag) {
    final (wx, wy) = _toWorld(drag);
    final p = s.position;
    final dx = p.x - wx, dy = p.y - wy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.6) return null;
    return (math.atan2(dy, dx), Match.dragToSpeed(len));
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!canTouch() || match.isMoving || match.isOver) return;
    final pos = event.canvasPosition.toOffset();
    final (wx, wy) = _toWorld(pos);
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
    _aimStone = best;
    _dragPos = best == null ? null : pos;
    if (best != null) HapticFeedback.selectionClick();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (_aimStone != null) _dragPos = event.canvasEndPosition.toOffset();
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final s = _aimStone, d = _dragPos;
    _aimStone = null;
    _dragPos = null;
    if (s == null || d == null) return;
    final shot = _shotFromDrag(s, d);
    if (shot == null || shot.$2 < 3) return;
    HapticFeedback.mediumImpact();
    match.shoot(s, shot.$1, shot.$2, hit());
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _aimStone = null;
    _dragPos = null;
  }
}
