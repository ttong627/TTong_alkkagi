import 'dart:math' as math;
import 'dart:ui';

import 'package:alkkagi_physics/alkkagi_physics.dart' as phys;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart' as w show Matrix4, MatrixUtils;

import 'arena.dart';
import 'board_paint.dart';
import 'camera.dart';
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

  /// 돌을 따라가는 카메라(설정 「카메라 연출」로 끔).
  final cam = BattleCamera();
  int _seenTurns = 0;
  w.Matrix4 _cam = w.Matrix4.identity();

  /// 어기어석으로 꺾는 중 손가락 자리(화면).
  Offset? _steerTo;
  Offset _origin = Offset.zero;

  /// 판 둘레 여백(cm).
  static const double margin = 1.6;

  Arena get arena => match.config.arena;

  // 판 밖은 비워 두고(투명) 뒤의 대전장 배경 그림이 보이게 한다.
  @override
  Color backgroundColor() => const Color(0x00000000);

  /// 판 좌표(cm) → 이 게임 화면 안 좌표(입문 손가락 자리) — 카메라까지 넣어서.
  Offset screenOf(double x, double y) =>
      w.MatrixUtils.transformPoint(_cam, _toScreen(x, y));

  /// 화면 자리 → 판 좌표(cm). 카메라가 움직여 있어도 판 위 같은 자리.
  Offset worldOf(Offset screen) {
    final p = BattleCamera.unproject(_cam, screen);
    return Offset((p.dx - _origin.dx) / _scale, (p.dy - _origin.dy) / _scale);
  }

  /// 돌 반지름의 화면 길이.
  double get stoneRadiusPx => phys.PhysicsConstants.stoneRadius * _scale;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // 경기장마다 판 크기가 다르다(2026-10-14) — 판 전체가 보이게.
    final span = match.table.half * 2 + margin * 2;
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
      if (s != null) {
        fx.onShot(match, s);
        cam.onShot(
          Offset(s.position.x, s.position.y),
          big: match.lastCritical || match.lastMode != StrikeMode.plain,
        );
      }
    }
    cam.enabled = Settings.instance.camera;
    cam.update(real, [
      for (final s in match.table.stones)
        if (!s.out && s.velocity.length > 3)
          (Offset(s.position.x, s.position.y), s.velocity.length.toDouble()),
    ]);
    _cam = cam.matrix(_origin, _scale);
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
      for (final i in match.table.impacts) {
        cam.onImpact(Offset(i.x, i.y), i.speed);
      }
      for (final s in match.table.stones) {
        if (s.out && !wasOut.contains(s.id)) {
          cam.onOut(Offset(s.position.x, s.position.y));
        }
      }
      if (ended) fx.onTurnEnd(match);
    }
    if (!match.isMoving) _acc = 0;
  }

  /// 돌 표정 고르기: 쏜 돌은 힘줌, 맞아 튕기는 돌은 어질어질, 내가 돌을 고르면 상대 돌은 겁먹음, 나머지는 깜빡깜빡.
  void _face(
    Canvas canvas,
    phys.Stone s,
    Offset at,
    double r,
    phys.Stone? pick,
  ) {
    if (s.team > 1) return; // 백성 돌·보주는 얼굴 없음.
    final moving = match.isMoving;
    final speed = s.velocity.length;
    final StoneMood mood;
    if (moving && identical(s, match.table.shooter) && speed > 3) {
      mood = StoneMood.fierce;
    } else if (moving && speed > 6) {
      mood = StoneMood.dizzy;
    } else if (!moving && pick != null && s.team != pick.team) {
      mood = StoneMood.scared;
    } else {
      mood = StoneMood.calm;
    }
    final phase = (fx.clock + s.id * 0.73) % 3.7;
    paintStoneFace(
      canvas,
      at,
      r,
      s.team,
      mood,
      blink: phase < 0.12 ? 1 : 0,
      t: fx.clock,
    );
  }

  Offset _toScreen(double x, double y) =>
      Offset(_origin.dx + x * _scale, _origin.dy + y * _scale);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    final shake = fx.shakeOffset();
    canvas.translate(shake.dx, shake.dy);
    canvas.transform(_cam.storage);
    paintArena(canvas, arena, _toScreen, _scale, h: match.table.half);
    if (match.fireFloor) {
      // 6장 불꽃 바닥: 붉게.
      canvas.drawRect(
        Rect.fromPoints(
          _toScreen(-match.table.half - 4, -match.table.half - 4),
          _toScreen(match.table.half + 4, match.table.half + 4),
        ),
        Paint()..color = const Color(0x33FF5A1F),
      );
    }
    if (match.config.demonWorld) {
      // 환생 세계: 같은 판이 어두운 마교 세계로(설계서 §10.2).
      canvas.drawRect(
        Rect.fromPoints(
          _toScreen(-match.table.half - 4, -match.table.half - 4),
          _toScreen(match.table.half + 4, match.table.half + 4),
        ),
        Paint()..color = const Color(0x664A1460),
      );
    }
    for (final f in match.table.features) {
      paintFeature(canvas, f, _toScreen, _scale, pose: match.table.poseOf(f));
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
      _face(canvas, s, _toScreen(s.position.x, s.position.y), r * _scale, pick);
      if (match.isGeneral(s)) {
        paintGeneralMark(
          canvas,
          _toScreen(s.position.x, s.position.y),
          r * _scale,
        );
      }
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
      _face(
        canvas,
        s,
        ground.translate(0, -s.z * _scale),
        r * _scale * (1 + s.z * 0.08),
        pick,
      );
      if (match.isGeneral(s)) {
        paintGeneralMark(
          canvas,
          ground.translate(0, -s.z * _scale),
          r * _scale * (1 + s.z * 0.08),
        );
      }
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
        // 손가락 자리는 화면 좌표 — 카메라 안 그림 좌표로 되돌린다.
        BattleCamera.unproject(_cam, to),
        Paint()
          ..color = ultimateColor
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    // 판 밖으로 떨어지는 돌: 작아지며 흐려진다.
    for (final f in fx.falls) {
      final k = (f.t / FallingStone.life).clamp(0.0, 1.0);
      final at = _toScreen(f.pos.dx, f.pos.dy);
      final rr = r * _scale * (1 - 0.6 * k);
      // 흐리게 할 칸은 돌 둘레만(경계 없는 칸은 화면 전체 크기 임시 그림판을 돌마다 만들었다 · 2026-10-14 점검).
      canvas.saveLayer(
        Rect.fromCircle(center: at, radius: rr * 2),
        Paint()..color = Color.fromRGBO(255, 255, 255, 1 - k),
      );
      paintTopStone(canvas, at, rr, f.team, f.material, shape: f.shape);
      if (f.team <= 1) paintStoneFace(canvas, at, rr, f.team, StoneMood.eek);
      canvas.restore();
    }
    fx.paintOver(canvas, Size(size.x, size.y), _toScreen, _scale);
    canvas.restore();
    fx.paintScreen(canvas, Size(size.x, size.y));
    // 큰 장면: 위아래 검은 띠(영화처럼).
    if (cam.letterbox > 0.01) {
      final h = size.y * 0.06 * cam.letterbox;
      final band = Paint()..color = const Color(0xB3000000);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, h), band);
      canvas.drawRect(Rect.fromLTWH(0, size.y - h, size.x, h), band);
    }
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
    final w = worldOf(to);
    final a = math.atan2(w.dy - s.position.y, w.dx - s.position.x);
    Buzz.heavy();
    match.steer(a);
    if (match.steersLeft <= 0) fx.steerLeft = 0;
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    if (!canTouch() || match.isMoving || match.isOver) return;
    final p = event.canvasPosition;
    final w = worldOf(Offset(p.x, p.y));
    final wx = w.dx, wy = w.dy;
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
