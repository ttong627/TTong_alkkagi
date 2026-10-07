import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart' as phys;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/arena.dart';
import '../game/board_paint.dart';
import '../game/flick.dart';
import '../game/match.dart';

/// 재질마다 기(氣) 빛깔.
const _qiColors = {
  phys.StoneMaterial.cheongok: Color(0xFF5FE0B0),
  phys.StoneMaterial.wood: Color(0xFFFFB84D),
  phys.StoneMaterial.hyeoncheol: Color(0xFF9FA8FF),
  phys.StoneMaterial.ice: Color(0xFF8FE8FF),
};

/// 고른 돌을 가까이 보며 손가락으로 튕기는 화면.
///
/// - 손끝이 돌에 닿은 **높이**가 타격점(위 = 밀어치기, 가운데 = 강타, 아래 = 끌어치기)
/// - 튕긴 **방향**이 판 위 방향(화면 위 = 판 위)
/// - 튕긴 **빠르기**가 세기(내공)
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
  final void Function(FlickShot shot) onShot;
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
  final _samples = <FlickSample>[];

  StoneFace? _face;
  Offset? _contact;
  double _power = 0;
  double? _aimAngle;
  String? _hint;

  /// 쏘고 난 뒤 돌이 날아가는 연출(0~1). null 이면 아직 안 쏨.
  double? _launch;
  FlickShot? _shot;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  Color get _qi => _qiColors[widget.stone.material]!;

  void _tick(Duration now) {
    final dt = math.min(0.05, (now - _last).inMicroseconds / 1e6);
    _last = now;
    final face = _face;
    if (face != null) {
      // 손을 대고 있으면 내공만큼, 아니면 은은하게 기가 피어오른다.
      final rate = _launch != null
          ? 0
          : (_samples.isEmpty ? 1 : 2 + _power * 14);
      for (var i = 0; i < rate; i++) {
        final a = _rand.nextDouble() * math.pi * 2;
        final from = Offset(
          face.center.dx + math.cos(a) * face.rx,
          face.center.dy + face.thickness / 2 + math.sin(a) * face.ry,
        );
        final out = Offset(math.cos(a), math.sin(a) * 0.6);
        _particles.add(
          _Particle(
            from,
            out * (20 + _power * 120) + Offset(0, -30 - _power * 90),
            0.6 + _rand.nextDouble() * 0.6,
            2 + _rand.nextDouble() * (3 + _power * 5),
            Color.lerp(_qi, const Color(0xFFFFE8A0), _rand.nextDouble() * 0.5)!,
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
        widget.onShot(shot);
      }
    }
    _frame.value++;
  }

  /// 이벤트가 실제로 일어난 시각(초). 화면이 바빠 처리가 늦어도 빠르기가 틀어지지 않는다.
  static double _at(PointerEvent e) => e.timeStamp.inMicroseconds / 1e6;

  void _down(PointerDownEvent e) {
    if (_launch != null) return;
    _samples
      ..clear()
      ..add(FlickSample(e.localPosition, _at(e)));
    _contact = null;
    _hint = null;
    _checkContact();
    setState(() {});
  }

  void _move(PointerMoveEvent e) {
    if (_launch != null || _samples.isEmpty) return;
    _samples.add(FlickSample(e.localPosition, _at(e)));
    _checkContact();
    final v = flickVelocity(_samples);
    if (v != null && v.$2 > 1) {
      _power = flickPower(v.$2);
      _aimAngle = math.atan2(v.$1.dy, v.$1.dx);
    }
  }

  void _checkContact() {
    final face = _face;
    if (_contact != null || face == null) return;
    final c = firstContact(_samples, face);
    if (c == null) return;
    _contact = c;
    HapticFeedback.lightImpact();
  }

  void _up(PointerUpEvent e) {
    if (_launch != null || _samples.isEmpty || _face == null) return;
    // 뗀 자리가 마지막 움직임과 다를 때만 점으로 넣는다(같은 자리면 빠르기를 깎는다).
    if (e.localPosition != _samples.last.pos) {
      _samples.add(FlickSample(e.localPosition, _at(e)));
    }
    final r = readFlick(_samples, _face!, releaseAt: _at(e));
    _samples.clear();
    if (r is FlickShot) {
      HapticFeedback.heavyImpact();
      _burst(r);
      setState(() {
        _shot = r;
        _power = r.power;
        _aimAngle = r.angle;
        _launch = 0;
      });
    } else {
      setState(() {
        _hint = (r as FlickMiss).hint;
        _power = 0;
        _aimAngle = null;
        _contact = null;
      });
    }
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
          Color.lerp(_qi, const Color(0xFFFFF2C0), _rand.nextDouble())!,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final arena = widget.match.config.arena;
    final pct = (_power * 100).round();
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
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.27,
              child: ValueListenableBuilder<int>(
                valueListenable: _frame,
                builder: (_, _, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _MiniBoardPainter(
                    widget.match,
                    widget.stone,
                    _aimAngle,
                    _power,
                  ),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final r = math.min(box.maxWidth * 0.30, box.maxHeight * 0.28);
                  _face = StoneFace.of(
                    widget.stone.shape,
                    Offset(box.maxWidth / 2, box.maxHeight * 0.48),
                    r,
                  );
                  return Listener(
                    key: const Key('flick-pad'),
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _down,
                    onPointerMove: _move,
                    onPointerUp: _up,
                    onPointerCancel: (_) => _samples.clear(),
                    child: ValueListenableBuilder<int>(
                      valueListenable: _frame,
                      builder: (_, _, _) => CustomPaint(
                        size: Size.infinite,
                        painter: _CloseUpPainter(
                          face: _face!,
                          arena: arena,
                          stone: widget.stone,
                          qi: _qi,
                          power: _power,
                          particles: _particles,
                          contact: _contact,
                          launch: _launch,
                          launchAngle: _aimAngle ?? -math.pi / 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                children: [
                  Text(
                    _samples.isNotEmpty || _launch != null
                        ? '내공 $pct%'
                        : (_hint ?? '손끝으로 돌을 튕기세요'),
                    style: t.titleLarge?.copyWith(
                      color: _hint != null && _samples.isEmpty
                          ? const Color(0xFFFFB0A0)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '돌 윗부분을 치면 밀고 나가고, 아랫부분을 치면 끌려옵니다',
                    style: t.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 위쪽 작은 지도: 판 전체 + 고른 돌 + 지금 튕기는 방향.
class _MiniBoardPainter extends CustomPainter {
  _MiniBoardPainter(this.match, this.stone, this.angle, this.power);
  final Match match;
  final phys.Stone stone;
  final double? angle;
  final double power;

  @override
  void paint(Canvas canvas, Size size) {
    const span = phys.PhysicsConstants.board + 3.2;
    final scale = math.min(size.width, size.height) / span;
    final o = Offset(size.width / 2, size.height / 2);
    Offset at(double x, double y) => o + Offset(x, y) * scale;
    paintArena(canvas, match.config.arena, at, scale);
    for (final s in match.table.stones) {
      if (s.out) continue;
      paintTopStone(
        canvas,
        at(s.position.x, s.position.y),
        phys.PhysicsConstants.stoneRadius * scale,
        s.team,
        s.material,
        selected: identical(s, stone),
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

/// 가까이 본 입체 돌 + 기(氣) 연출.
class _CloseUpPainter extends CustomPainter {
  _CloseUpPainter({
    required this.face,
    required this.arena,
    required this.stone,
    required this.qi,
    required this.power,
    required this.particles,
    required this.contact,
    required this.launch,
    required this.launchAngle,
  });

  final StoneFace face;
  final Arena arena;
  final phys.Stone stone;
  final Color qi;
  final double power;
  final List<_Particle> particles;
  final Offset? contact;
  final double? launch;
  final double launchAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.clipRect(rect);
    // 바닥: 대전장 바닥색에 가운데 빛, 가장자리 어둠.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.1),
          radius: 0.9,
          colors: [arena.floor, Color.lerp(arena.floor, Colors.black, 0.75)!],
        ).createShader(rect),
    );

    // 날아가는 연출: 튕긴 방향으로 빠르게 멀어지며 작아진다.
    final l = launch ?? 0;
    final shift =
        Offset(math.cos(launchAngle), math.sin(launchAngle)) *
        (l * l * size.longestSide);
    final sc = 1 - 0.5 * l;

    // 기 둘레 빛. 돌 한가운데(pivot)를 기준으로 옮기고 줄인다.
    final pivot = face.center.translate(0, face.thickness / 2);
    final glowC = pivot + shift;
    final glowR = face.rx * (1.5 + power * 0.9);
    canvas.drawCircle(
      glowC,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            qi.withValues(alpha: 0.25 + power * 0.45),
            qi.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: glowC, radius: glowR)),
    );

    canvas.save();
    canvas.translate(glowC.dx, glowC.dy);
    canvas.scale(sc);
    canvas.translate(-pivot.dx, -pivot.dy);
    _paintStone(canvas);
    canvas.restore();

    for (final p in particles) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(
        p.pos,
        p.size * (0.5 + a * 0.5),
        Paint()
          ..color = p.color.withValues(alpha: a * 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    final c = contact;
    if (c != null && launch == null) {
      canvas.drawCircle(
        c,
        face.rx * 0.18,
        Paint()
          ..color = const Color(0x99FFF2C0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  void _paintStone(Canvas canvas) {
    final f = face;
    final team = stone.team;
    final base = stoneBase(team);
    final shine = stoneShine(team);
    final side = Color.lerp(base, Colors.black, team == 0 ? 0.28 : 0.35)!;
    final ring = materialColors[stone.material]!;

    // 바닥 그림자.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(f.center.dx + f.rx * 0.1, f.bottom - f.ry * 0.25),
        width: f.rx * 2.3,
        height: f.ry * 1.3 + f.rx * 0.15,
      ),
      Paint()
        ..color = const Color(0x77000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    if (f.thickness <= 0) {
      // 구형 돌.
      final c = f.center;
      canvas.drawCircle(
        c,
        f.rx,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.45),
            radius: 1.0,
            colors: [shine, base, side],
            stops: const [0, 0.55, 1],
          ).createShader(Rect.fromCircle(center: c, radius: f.rx)),
      );
      canvas.drawOval(
        Rect.fromCenter(center: c, width: f.rx * 2, height: f.rx * 0.55),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = f.rx * 0.12
          ..color = ring,
      );
      return;
    }

    final top = Rect.fromCenter(
      center: f.center,
      width: f.rx * 2,
      height: f.ry * 2,
    );
    final bottom = top.shift(Offset(0, f.thickness));
    // 옆면: 윗면 가운데 줄 ~ 아랫면 타원의 아래 반.
    final sidePath = Path()
      ..moveTo(top.left, f.center.dy)
      ..lineTo(bottom.left, f.center.dy + f.thickness)
      ..arcTo(bottom, math.pi, -math.pi, false)
      ..lineTo(top.right, f.center.dy)
      ..close();
    canvas.drawPath(
      sidePath,
      Paint()
        ..shader =
            LinearGradient(
              colors: [side, Color.lerp(side, shine, 0.35)!, side],
              stops: const [0, 0.35, 1],
            ).createShader(
              Rect.fromLTRB(top.left, top.top, top.right, bottom.bottom),
            ),
    );
    canvas.drawOval(
      top,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.5),
          radius: 1.1,
          colors: [shine, base],
        ).createShader(top),
    );
    canvas.drawOval(
      top.deflate(f.rx * 0.12),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = f.rx * 0.16
        ..color = ring,
    );
    // 반짝임.
    canvas.drawOval(
      Rect.fromCenter(
        center: f.center.translate(-f.rx * 0.35, -f.ry * 0.35),
        width: f.rx * 0.6,
        height: f.ry * 0.35,
      ),
      Paint()..color = Colors.white.withValues(alpha: team == 0 ? 0.6 : 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
