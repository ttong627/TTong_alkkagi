import 'dart:async';
import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart' as phys;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../e2e.dart';
import '../game/arena.dart';
import '../game/board_paint.dart';
import '../game/fx_colors.dart';
import '../game/flick.dart';
import '../game/match.dart';
import '../game/predict.dart';
import '../input/touch_feed.dart';

/// 재질마다 기(氣) 빛깔.
const _qiColors = {
  phys.StoneMaterial.cheongok: Color(0xFF5FE0B0),
  phys.StoneMaterial.wood: Color(0xFFFFB84D),
  phys.StoneMaterial.hyeoncheol: Color(0xFF9FA8FF),
  phys.StoneMaterial.ice: Color(0xFF8FE8FF),
};

/// 고른 돌 둘레의 대전장 바닥을 크게 내려다보며 손끝으로 돌을 치는 화면.
///
/// 폰을 바닥에 눕혀 놓은 대전장으로 본다. 손끝이 화면 위를 미끄러지다 돌에 닿는 순간
/// 부딪힌 자리와 빠르기로 돌이 밀려 나간다([StrikeReader]).
/// - 돌 **가운데**를 맞히면 손끝 방향 그대로, **가장자리**를 맞히면 비스듬히 나간다.
/// - 닿을 때 손끝이 **빠를수록** 세다(내공). 살살 밀어도 나간다.
class FlickView extends StatefulWidget {
  const FlickView({
    super.key,
    required this.match,
    required this.stone,
    required this.onShot,
    required this.onCancel,
  });

  final Match match;
  final phys.Stone stone;

  /// 쳐 냈을 때: 결과와 고른 방식(평타·내공 타격·흡성탄지·어기어석).
  final void Function(FlickShot shot, StrikeMode mode) onShot;
  final VoidCallback onCancel;

  @override
  State<FlickView> createState() => _FlickViewState();
}

class _Particle {
  _Particle(this.pos, this.vel, this.life, this.size, this.color);
  Offset pos;
  Offset vel;
  double life;
  final double maxLife = 1;
  final double size;
  final Color color;
}

class _FlickViewState extends State<FlickView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  final _rand = math.Random();
  final _particles = <_Particle>[];

  StrikeReader? _reader;
  StoneDisc? _disc;
  bool _down = false;
  double _power = 0;
  double? _aimAngle;
  String? _hint;
  String? _hitNote;
  StrikeMode _mode = StrikeMode.plain;

  /// 쏘고 난 뒤 돌이 날아가는 연출(0~1). null 이면 아직 안 쏨.
  double? _launch;
  FlickShot? _shot;
  Duration _last = Duration.zero;

  // 안드로이드에서 따로 받은 촘촘한 손끝 점(TouchFeed). Flutter 포인터와 시각으로 짝짓는다.
  StreamSubscription<NativeTouch>? _nativeSub;
  bool _useNative = false;
  List<NativePoint>? _nPoints;
  bool _nEnded = false;
  Offset? _lDownLocal;
  double? _lDownT;
  Offset? _delta;
  int _fed = 0;
  double _dpr = 1;

  final _padKey = GlobalKey();

  /// 예상 궤적(판 좌표)과 마지막으로 계산한 시각.
  List<Offset> _path = const [];
  double _pathAt = 0;
  (double, double)? _pathFor;
  String? _e2eLast;

  /// 짝이 안 맞을 때를 대비해 Flutter 포인터 점도 모아 둔다.
  final _lSamples = <FlickSample>[];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _nativeSub = TouchFeed.instance.events.listen(_onNative);
  }

  @override
  void dispose() {
    _nativeSub?.cancel();
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  Color get _qi => _qiColors[widget.stone.material]!;

  void _tick(Duration now) {
    final dt = math.min(0.05, (now - _last).inMicroseconds / 1e6);
    _last = now;
    final disc = _disc;
    if (disc != null && _launch == null) {
      // 손을 대고 있으면 겨눈 내공만큼, 아니면 은은하게 기가 피어오른다.
      final rate = _down ? 2 + _power * 12 : 1;
      for (var i = 0; i < rate; i++) {
        final a = _rand.nextDouble() * math.pi * 2;
        final out = Offset(math.cos(a), math.sin(a));
        _particles.add(
          _Particle(
            disc.center + out * disc.radius,
            out * (25 + _power * 140),
            0.5 + _rand.nextDouble() * 0.6,
            2 + _rand.nextDouble() * (3 + _power * 5),
            Color.lerp(
              _modeQi,
              const Color(0xFFFFE8A0),
              _rand.nextDouble() * 0.5,
            )!,
          ),
        );
      }
    }
    for (final p in _particles) {
      p.pos += p.vel * dt;
      p.vel = p.vel * (1 - 1.5 * dt);
      p.life -= dt;
    }
    _particles.removeWhere((p) => p.life <= 0);
    if (_launch != null) {
      _launch = math.min(1, _launch! + dt / 0.32);
      if (_launch! >= 1 && _shot != null) {
        final shot = _shot!;
        _shot = null;
        widget.onShot(shot, _mode);
      }
    }
    _frame.value++;
  }

  /// 이벤트가 실제로 일어난 시각(초). 화면이 바빠 처리가 늦어도 빠르기가 틀어지지 않는다.
  static double _at(PointerEvent e) => e.timeStamp.inMicroseconds / 1e6;

  /// Flutter 포인터가 알려 주는 닿은 넓이(닿은 길이, 없으면 넓이 비율).
  static double? _area(PointerEvent e) =>
      e.radiusMajor > 0 ? e.radiusMajor : (e.size > 0 ? e.size : null);

  FlickSample _sample(PointerEvent e) =>
      FlickSample(e.localPosition, _at(e), area: _area(e));

  void _onDown(PointerDownEvent e) {
    final disc = _disc;
    if (_launch != null || disc == null) return;
    _reader = null;
    _lSamples
      ..clear()
      ..add(_sample(e));
    _useNative = TouchFeed.instance.active;
    if (_useNative) {
      _lDownLocal = e.localPosition;
      _lDownT = _at(e);
      _delta = null;
      _tryPair();
    } else {
      TouchProfile.shared.add(_area(e));
      _start(_lSamples.first);
    }
    setState(() {
      _down = true;
      _hint = null;
      _hitNote = null;
      _power = 0;
      _aimAngle = null;
    });
  }

  void _onMove(PointerMoveEvent e) {
    if (_launch != null || !_down) return;
    final s = _sample(e);
    _lSamples.add(s);
    if (_useNative) return;
    TouchProfile.shared.add(s.area);
    _feed(s);
  }

  void _onUp(PointerUpEvent e) {
    if (_launch != null || !_down) return;
    if (e.localPosition != _lSamples.last.pos) _lSamples.add(_sample(e));
    if (_useNative && _delta != null) {
      // 안드로이드 점의 「뗌」에서 끝낸다. 그 점이 끝내 안 오면 0.3초 뒤 여기서 끝낸다.
      final reader = _reader;
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _down && _launch == null && identical(reader, _reader)) {
          _end();
        }
      });
      return;
    }
    if (_useNative) {
      // 짝을 못 지었다 → Flutter 포인터 점으로 끝까지 읽는다.
      _useNative = false;
      _start(_lSamples.first);
      for (final s in _lSamples.skip(1)) {
        if (_feed(s)) return;
      }
    }
    _end();
  }

  /// 안드로이드 점 묶음이 왔다.
  void _onNative(NativeTouch e) {
    if (e.isDown) {
      _nPoints = [...e.points];
      _nEnded = false;
      _delta = null;
      _fed = 0;
      _tryPair();
      return;
    }
    final pts = _nPoints;
    if (pts == null) return;
    pts.addAll(e.points);
    if (e.isEnd) _nEnded = true;
    _feedNative();
  }

  /// 같은 손대기인지 시각으로 확인하고(같은 이벤트 시각), 화면 위치를 맞춘다.
  void _tryPair() {
    final pts = _nPoints, lt = _lDownT, ll = _lDownLocal;
    if (!_useNative || pts == null || lt == null || ll == null) return;
    if (_delta != null || _launch != null) return;
    if ((pts.first.t - lt).abs() > 0.002) return;
    _delta = ll - pts.first.px / _dpr;
    _start(_toLocal(pts.first));
    _fed = 1;
    _feedNative();
  }

  FlickSample _toLocal(NativePoint p) =>
      FlickSample(p.px / _dpr + _delta!, p.t, area: p.area);

  void _feedNative() {
    final pts = _nPoints;
    if (_delta == null || pts == null || _reader == null) return;
    while (_fed < pts.length) {
      if (_feed(_toLocal(pts[_fed++]))) return;
    }
    if (_nEnded && _launch == null) _end();
  }

  void _start(FlickSample first) {
    final reader = _reader = StrikeReader(_disc!);
    reader.down(first);
    if (reader.touched) HapticFeedback.selectionClick();
  }

  /// 점 하나를 넣는다. 쳐 냈으면 참.
  bool _feed(FlickSample s) {
    final reader = _reader;
    if (reader == null || _launch != null) return false;
    final wasTouched = reader.touched;
    final shot = reader.move(s);
    if (shot != null) {
      _fire(shot);
      return true;
    }
    if (!wasTouched && reader.touched) HapticFeedback.selectionClick();
    final guess = reader.predict();
    _aimAngle = guess?.$1;
    _power = guess?.$2 ?? 0;
    _updatePath(s.t);
    return false;
  }

  /// 겨눈 대로 쳤을 때의 길을 물리로 미리 계산(0.08초마다).
  void _updatePath(double t) {
    final a = _aimAngle;
    if (a == null) {
      _path = const [];
      return;
    }
    if (t - _pathAt < 0.08 && _pathFor != null) return;
    _pathAt = t;
    _pathFor = (a, _power);
    final speed =
        powerToSpeed(_power) *
        massFactor(_disc!.mass) *
        widget.match.config.powerScale;
    _path = predictPath(widget.match, widget.stone, a, speed);
  }

  void _end() {
    if (!mounted) return;
    _path = const [];
    final miss = _reader?.up();
    e2eLog('miss native=$_useNative why=${miss?.name}');
    _reader = null;
    _nPoints = null;
    setState(() {
      _down = false;
      _hint = miss?.hint;
      _power = 0;
      _aimAngle = null;
    });
  }

  void _fire(FlickShot shot) {
    e2eLog(
      'shot native=$_useNative points=${_reader?.samples.length} '
      'angle=${(shot.angle * 180 / math.pi).toStringAsFixed(1)} '
      'power=${shot.power.toStringAsFixed(3)} speed=${shot.speed.toStringAsFixed(1)} '
      'hit=${shot.hit.toStringAsFixed(2)} area=${_reader?.strikeArea} '
      'profile=${TouchProfile.shared.count}',
    );
    HapticFeedback.heavyImpact();
    _burst(shot);
    _nPoints = null;
    setState(() {
      _hitNote = [
        if (shot.critical && _mode == StrikeMode.plain) '회심! 내공 +1',
        if (_mode != StrikeMode.plain) _modeName(_mode),
        ?_describeHit(shot.hit),
      ].join(' · ');
      _down = false;
      _shot = shot;
      _power = shot.power;
      _aimAngle = shot.angle;
      _launch = 0;
    });
  }

  void _burst(FlickShot r) {
    for (var i = 0; i < 70; i++) {
      final a = r.angle + (_rand.nextDouble() - 0.5) * 2.2;
      final sp = 120 + _rand.nextDouble() * 520 * (0.4 + r.power);
      _particles.add(
        _Particle(
          r.contact,
          Offset(math.cos(a), math.sin(a)) * sp,
          0.4 + _rand.nextDouble() * 0.5,
          2 + _rand.nextDouble() * 6,
          Color.lerp(_modeQi, const Color(0xFFFFF2C0), _rand.nextDouble())!,
        ),
      );
    }
  }

  String _modeName(StrikeMode m) => switch (m) {
    StrikeMode.inner => '내공 · ${widget.match.config.martial.label}',
    _ => m.label,
  };

  /// 지금 고른 방식의 기 빛깔.
  Color get _modeQi => switch (_mode) {
    StrikeMode.plain => _qi,
    StrikeMode.inner => techniqueColor(widget.match.config.martial),
    StrikeMode.absorb => techniqueColor(phys.Technique.absorb),
    StrikeMode.ultimate => ultimateColor,
  };

  /// 위아래 타격점을 말로.
  static String? _describeHit(double hit) {
    if (TouchProfile.shared.range == null) return null;
    if (hit <= -phys.PhysicsConstants.liftThreshold) return '아래를 맞아 떠서 날아감';
    if (hit >= phys.PhysicsConstants.liftThreshold) return '위를 맞아 튀어 오름';
    if (hit < -0.15) return '조금 아래(끌어치기)';
    if (hit > 0.15) return '조금 위(밀어치기)';
    return '가운데';
  }

  String get _status {
    if (_launch != null) {
      final note = _hitNote;
      final pct = '내공 ${(_power * 100).round()}%';
      return note == null ? pct : '$pct · $note';
    }
    if (_down && _aimAngle != null) {
      return '내공 ${(_power * 100).round()}%';
    }
    return _hint ?? '손끝을 미끄러뜨려 돌을 맞히세요';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final arena = widget.match.config.arena;
    return Material(
      color: arena.outside,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _launch == null ? widget.onCancel : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('다른 돌 고르기'),
                  ),
                  const Spacer(),
                  Text(arena.label, style: t.labelLarge),
                ],
              ),
            ),
            _ModeBar(
              match: widget.match,
              team: widget.stone.team,
              mode: _mode,
              enabled: _launch == null && !_down,
              onChanged: (m) => setState(() => _mode = m),
            ),
            // 작은 지도·바닥·안내 글 전체가 손끝을 받는다(돌 아래·위 어디서 밀기 시작해도 된다).
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth, h = box.maxHeight;
                  final miniH = h * 0.3;
                  const textH = 78.0;
                  final floorH = h - miniH - textH;
                  final r = math.min(w * 0.28, floorH * 0.3);
                  final c = Offset(w / 2, miniH + floorH * 0.5);
                  _dpr = MediaQuery.devicePixelRatioOf(context);
                  if (_disc == null ||
                      _disc!.center != c ||
                      _disc!.radius != r) {
                    _disc = StoneDisc(c, r, mass: widget.stone.mass);
                  }
                  if (e2eFlick) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final box = _padKey.currentContext?.findRenderObject();
                      if (box is! RenderBox || !box.attached) return;
                      final g = box.localToGlobal(_disc!.center) * _dpr;
                      final line =
                          'disc cx=${g.dx.round()} cy=${g.dy.round()} '
                          'r=${(_disc!.radius * _dpr).round()}';
                      if (line != _e2eLast) e2eLog(_e2eLast = line);
                    });
                  }
                  return Listener(
                    key: const Key('flick-pad'),
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _onDown,
                    onPointerMove: _onMove,
                    onPointerUp: _onUp,
                    onPointerCancel: (_) {
                      if (_launch == null && _down) _end();
                    },
                    child: ValueListenableBuilder<int>(
                      key: _padKey,
                      valueListenable: _frame,
                      builder: (_, _, _) => Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _FloorPainter(
                                match: widget.match,
                                disc: _disc!,
                                top: miniH,
                                stone: widget.stone,
                                qi: _modeQi,
                                power: _power,
                                particles: _particles,
                                aim: _launch == null ? _aimAngle : null,
                                launch: _launch,
                                launchAngle: _aimAngle ?? -math.pi / 2,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: miniH,
                            child: CustomPaint(
                              painter: _MiniBoardPainter(
                                widget.match,
                                widget.stone,
                                _aimAngle,
                                _power,
                                _down ? _path : const [],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              color: const Color(0x99000000),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _status,
                                    style: t.titleLarge?.copyWith(
                                      color:
                                          _hint != null &&
                                              !_down &&
                                              _launch == null
                                          ? const Color(0xFFFFB0A0)
                                          : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '폰이 대전장 바닥이에요. 가운데를 맞히면 곧게, 가장자리를 맞히면 비스듬히 나가요',
                                    style: t.bodySmall?.copyWith(
                                      color: Colors.white70,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 손끝 자국은 맨 위에.
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _TrailPainter(
                                _down ? _reader?.samples : null,
                                _disc!.radius,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 손끝 자국.
class _TrailPainter extends CustomPainter {
  _TrailPainter(this.trail, this.radius);
  final List<FlickSample>? trail;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final tr = trail;
    if (tr == null || tr.length < 2) return;
    final n = tr.length;
    for (var i = math.max(1, n - 24); i < n; i++) {
      final k = (i - (n - 24)) / 24;
      canvas.drawLine(
        tr[i - 1].pos,
        tr[i].pos,
        Paint()
          ..color = const Color(0xFFFFF2C0)
              .withValues(alpha: (0.15 + 0.5 * k).clamp(0.0, 1.0))
          ..strokeWidth = radius * 0.1 * (0.4 + k)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 위쪽 작은 지도: 판 전체 + 고른 돌 + 지금 겨눈 방향.
class _MiniBoardPainter extends CustomPainter {
  _MiniBoardPainter(this.match, this.stone, this.angle, this.power, this.path);
  final Match match;
  final phys.Stone stone;
  final double? angle;
  final double power;

  /// 예상 궤적(판 좌표).
  final List<Offset> path;

  @override
  void paint(Canvas canvas, Size size) {
    const span = phys.PhysicsConstants.board + 3.2;
    final scale = math.min(size.width, size.height) / span;
    final o = Offset(size.width / 2, size.height / 2);
    Offset at(double x, double y) => o + Offset(x, y) * scale;
    paintArena(canvas, match.config.arena, at, scale);
    for (final f in match.table.features) {
      paintFeature(canvas, f, at, scale);
    }
    for (final s in match.table.stones) {
      if (s.out) continue;
      paintTopStone(
        canvas,
        at(s.position.x, s.position.y),
        phys.PhysicsConstants.stoneRadius * scale,
        s.team,
        s.material,
        shape: s.shape,
        selected: identical(s, stone),
      );
    }
    if (path.length > 1) {
      final paint = Paint()
        ..color = const Color(0xCCFFFFFF)
        ..strokeWidth = math.max(1.5, scale * 0.25)
        ..strokeCap = StrokeCap.round;
      // 점선으로.
      for (var i = 1; i < path.length; i += 2) {
        canvas.drawLine(
          at(path[i - 1].dx, path[i - 1].dy),
          at(path[i].dx, path[i].dy),
          paint,
        );
      }
      final end = path.last;
      canvas.drawCircle(
        at(end.dx, end.dy),
        phys.PhysicsConstants.stoneRadius * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xAAFFFFFF),
      );
    }
    final a = angle;
    if (a != null) {
      paintAim(canvas, at(stone.position.x, stone.position.y), a, power, scale);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 고른 돌 둘레의 대전장 바닥을 크게 내려다본 그림 + 기(氣)·손끝 자국.
class _FloorPainter extends CustomPainter {
  _FloorPainter({
    required this.match,
    required this.disc,
    required this.top,
    required this.stone,
    required this.qi,
    required this.power,
    required this.particles,
    required this.aim,
    required this.launch,
    required this.launchAngle,
  });

  final Match match;
  final StoneDisc disc;

  /// 바닥이 시작하는 높이(그 위는 작은 지도).
  final double top;
  final phys.Stone stone;
  final Color qi;
  final double power;
  final List<_Particle> particles;
  final double? aim;
  final double? launch;
  final double launchAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(0, top, size.width, size.height);
    canvas.clipRect(rect);
    final arena = match.config.arena;
    canvas.drawRect(rect, Paint()..color = arena.outside);

    // 판 좌표 → 화면: 고른 돌이 [disc] 자리에 오도록 크게 키운다.
    final scale = disc.radius / phys.PhysicsConstants.stoneRadius;
    final sx = stone.position.x, sy = stone.position.y;
    Offset at(double x, double y) =>
        disc.center + Offset(x - sx, y - sy) * scale;
    paintArena(canvas, arena, at, scale);
    for (final f in match.table.features) {
      paintFeature(canvas, f, at, scale);
    }
    for (final s in match.table.stones) {
      if (s.out || identical(s, stone)) continue;
      paintTopStone(
        canvas,
        at(s.position.x, s.position.y),
        disc.radius,
        s.team,
        s.material,
        shape: s.shape,
      );
    }

    // 겨눈 방향: 돌에서 나갈 길을 옅게.
    final a = aim;
    if (a != null) {
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        disc.center + dir * disc.radius,
        disc.center + dir * disc.radius * (2.2 + power * 3),
        Paint()
          ..color = qi.withValues(alpha: 0.55)
          ..strokeWidth = disc.radius * 0.08
          ..strokeCap = StrokeCap.round,
      );
    }

    // 날아가는 연출: 맞은 방향으로 빠르게 멀어지며 작아진다.
    final l = launch ?? 0;
    final shift =
        Offset(math.cos(launchAngle), math.sin(launchAngle)) *
        (l * l * size.longestSide);
    final c = disc.center + shift;
    final r = disc.radius * (1 - 0.4 * l);
    final glowR = r * (1.5 + power * 0.9);
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            qi.withValues(alpha: 0.25 + power * 0.45),
            qi.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: glowR)),
    );
    paintTopStone(canvas, c, r, stone.team, stone.material, shape: stone.shape);

    for (final p in particles) {
      final al = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(
        p.pos,
        p.size * (0.5 + al * 0.5),
        Paint()
          ..color = p.color.withValues(alpha: al * 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 내공 칸과 치는 방식 고르기(평타 · 내공 타격 · 흡성탄지 · 어기어석).
class _ModeBar extends StatelessWidget {
  const _ModeBar({
    required this.match,
    required this.team,
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final Match match;
  final int team;
  final StrikeMode mode;
  final bool enabled;
  final ValueChanged<StrikeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final qi = match.qi(team);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          for (var i = 0; i < maxQi; i++)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Icon(
                Icons.circle,
                size: 14,
                color: i < qi ? innerColor : Colors.white24,
              ),
            ),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final m in StrikeMode.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        key: Key('mode-${m.name}'),
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          m == StrikeMode.inner
                              ? '내공·${match.config.martial.label}'
                              : m.cost == 0
                              ? m.label
                              : '${m.label} ${m.cost}',
                        ),
                        selected: mode == m,
                        onSelected: enabled && match.canUse(team, m)
                            ? (_) => onChanged(m)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
