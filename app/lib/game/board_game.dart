import 'dart:math' as math;
import 'dart:ui';

import 'package:alkkagi_physics/alkkagi_physics.dart' as phys;
import 'package:flame/events.dart';
import 'package:flame/game.dart';

import 'arena.dart';
import 'board_paint.dart';
import '../audio/sound.dart';
import 'fx.dart';
import '../progress/settings.dart';
import 'fx_colors.dart';
import 'match.dart';

/// 대전장과 돌을 그리고, 손가락으로 누른 돌을 "공격할 돌"로 고른다.
///
/// 물리는 고정 1/60초로 진행하고, 화면은 그 결과를 그린다(설계서 §3.1).
/// 쏘기는 고른 돌을 가까이 보는 화면에서 손가락으로 튕겨서 한다.
class BoardGame extends FlameGame with TapCallbacks, DragCallbacks {
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

  /// 판 위 연출(잔상·불꽃·흔들림·느린 화면·무공 효과).
  final fx = BattleFx();
  int _seenTurns = 0;

  /// 어기어석으로 꺾는 중 손가락 자리(화면).
  Offset? _steerTo;
  Offset _origin = Offset.zero;

  /// 판 둘레 여백(cm).
  static const double margin = 1.6;

  Arena get arena => match.config.arena;

  // 판 밖은 비워 두고(투명) 뒤의 대전장 배경 그림이 보이게 한다.
  @override
  Color backgroundColor() => const Color(0x00000000);

  /// 판 좌표(cm) → 이 게임 화면 안 좌표(입문 손가락 자리).
  Offset screenOf(double x, double y) => _toScreen(x, y);

  /// 돌 반지름의 화면 길이.
  double get stoneRadiusPx => phys.PhysicsConstants.stoneRadius * _scale;

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
    final real = math.min(dt, 0.1);
    fx.update(real);
    if (match.turnCount != _seenTurns) {
      _seenTurns = match.turnCount;
      final s = match.table.shooter;
      if (s != null) fx.onShot(match, s);
    }
    if (fx.steerLeft <= 0 && match.steersLeft > 0) match.steersLeft = 0;
    if (!match.isMoving || match.clash != null) {
      Sound.slide(0);
      if (!match.isMoving) return;
    } else {
      // 미끄러지는 소리: 가장 빠른 돌의 빠르기(80cm/s 에서 가장 큼).
      var top = 0.0;
      for (final s in match.table.stones) {
        if (!s.out) top = math.max(top, s.velocity.length);
      }
      Sound.slide(math.min(1, top / 80) * fx.timeScale.clamp(0.3, 1));
    }
    _acc += real * fx.timeScale;
    if (match.clash != null) {
      _acc = 0;
      return;
    }
    while (_acc >= phys.PhysicsConstants.step &&
        match.isMoving &&
        match.clash == null) {
      _acc -= phys.PhysicsConstants.step;
      final wasOut = {
        for (final s in match.table.stones)
          if (s.out) s.id,
      };
      final ended = match.step();
      fx.onStep(match, wasOut);
      if (ended) fx.onTurnEnd(match);
    }
    if (!match.isMoving) _acc = 0;
  }

  Offset _toScreen(double x, double y) =>
      Offset(_origin.dx + x * _scale, _origin.dy + y * _scale);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    final shake = fx.shakeOffset();
    canvas.translate(shake.dx, shake.dy);
    paintArena(canvas, arena, _toScreen, _scale);
    if (match.fireFloor) {
      // 6장 불꽃 바닥: 붉게.
      canvas.drawRect(
        Rect.fromPoints(_toScreen(-25, -25), _toScreen(25, 25)),
        Paint()..color = const Color(0x33FF5A1F),
      );
    }
    if (match.config.demonWorld) {
      // 환생 세계: 같은 판이 어두운 마교 세계로(설계서 §10.2).
      canvas.drawRect(
        Rect.fromPoints(_toScreen(-25, -25), _toScreen(25, 25)),
        Paint()..color = const Color(0x664A1460),
      );
    }
    for (final f in match.table.features) {
      paintFeature(canvas, f, _toScreen, _scale);
    }
    fx.paintUnder(canvas, match, _toScreen, _scale);
    final pick = canTouch() ? selected() : null;
    const r = phys.PhysicsConstants.stoneRadius;
    // 바닥에 있는 돌 먼저, 떠 있는 돌은 그 위에 그린다.
    for (final s in match.table.stones) {
      if (s.out || s.airborne) continue;
      paintTopStone(
        canvas,
        _toScreen(s.position.x, s.position.y),
        r * _scale,
        s.team,
        s.material,
        shape: s.shape,
        ring: canTouch() && match.canShoot(s),
        selected: identical(s, pick),
      );
    }
    for (final s in match.table.stones) {
      if (s.out || !s.airborne) continue;
      final ground = _toScreen(s.position.x, s.position.y);
      paintAirShadow(canvas, ground, r * _scale, s.z);
      // 위에서 비스듬히 본 것처럼, 뜬 만큼 화면 위로 올리고 조금 크게.
      paintTopStone(
        canvas,
        ground.translate(0, -s.z * _scale),
        r * _scale * (1 + s.z * 0.08),
        s.team,
        s.material,
        shape: s.shape,
      );
    }
    paintWeather(
      canvas,
      Size(size.x, size.y),
      match,
      _toScreen,
      _scale,
      fx.clock,
    );
    final shooter = match.table.shooter;
    final to = _steerTo;
    if (fx.steerLeft > 0 && shooter != null && to != null) {
      canvas.drawLine(
        _toScreen(shooter.position.x, shooter.position.y),
        to,
        Paint()
          ..color = ultimateColor
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    fx.paintOver(canvas, Size(size.x, size.y), _toScreen, _scale);
    canvas.restore();
  }

  /// 어기어석: 느린 화면 동안 손가락을 끌어 놓은 쪽으로 돌을 꺾는다.
  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (fx.steerLeft > 0 && match.steersLeft > 0) {
      _steerTo = Offset(event.canvasPosition.x, event.canvasPosition.y);
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (_steerTo != null) {
      _steerTo = Offset(event.canvasEndPosition.x, event.canvasEndPosition.y);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final to = _steerTo;
    _steerTo = null;
    final s = match.table.shooter;
    if (to == null || s == null || match.steersLeft <= 0) return;
    final wx = (to.dx - _origin.dx) / _scale,
        wy = (to.dy - _origin.dy) / _scale;
    final a = math.atan2(wy - s.position.y, wx - s.position.x);
    Buzz.heavy();
    match.steer(a);
    if (match.steersLeft <= 0) fx.steerLeft = 0;
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
    Buzz.tick();
    onSelect(best);
  }
}
