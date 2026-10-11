import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 시범 손가락(설계서 §16.10): 글 대신 손이 직접 보여 준다.
/// 반투명 흰 손이 검지를 세워 돌을 튕기거나, 눌러야 할 곳을 톡톡 누른다.

/// 손끝이 [tip], 검지가 [angle](라디안, 손끝이 향하는 쪽) 방향인 손 하나를 그린다. [s] 는 손 길이(화소).
void paintHand(
  Canvas c,
  Offset tip,
  double angle,
  double s,
  double alpha, {
  bool pressed = false,
}) {
  if (alpha <= 0) return;
  c.save();
  c.translate(tip.dx, tip.dy);
  // 손 그림은 위(−y)를 가리키게 그렸으므로 angle 에 맞춰 돌린다.
  c.rotate(angle + math.pi / 2);
  c.scale(s);
  if (pressed) c.scale(0.94);
  final fill = Paint()..color = Colors.white.withValues(alpha: 0.92 * alpha);
  final line = Paint()
    ..color = const Color(0xFF2A1A12).withValues(alpha: 0.9 * alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.035
    ..strokeJoin = StrokeJoin.round;
  final shadow = Paint()
    ..color = Colors.black.withValues(alpha: 0.25 * alpha)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.04);
  final finger = RRect.fromRectAndRadius(
    const Rect.fromLTWH(-0.11, 0, 0.22, 0.62),
    const Radius.circular(0.11),
  );
  final palm = RRect.fromRectAndRadius(
    const Rect.fromLTWH(-0.2, 0.42, 0.56, 0.52),
    const Radius.circular(0.16),
  );
  final thumb = RRect.fromRectAndRadius(
    const Rect.fromLTWH(-0.36, 0.5, 0.26, 0.17),
    const Radius.circular(0.085),
  );
  for (final r in [palm, thumb, finger]) {
    c.drawRRect(r.shift(const Offset(0.03, 0.04)), shadow);
  }
  for (final r in [palm, thumb]) {
    c.drawRRect(r, fill);
    c.drawRRect(r, line);
  }
  // 굽힌 손가락 마디 셋.
  for (var i = 0; i < 3; i++) {
    final k = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.1 + i * 0.0, 0.46 + i * 0.13, 0.28, 0.14),
      const Radius.circular(0.07),
    );
    c.drawRRect(k, fill);
    c.drawRRect(k, line);
  }
  c.drawRRect(finger, fill);
  c.drawRRect(finger, line);
  // 손톱.
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(-0.06, 0.04, 0.12, 0.1),
      const Radius.circular(0.05),
    ),
    Paint()..color = const Color(0xFFFFD6CC).withValues(alpha: alpha),
  );
  c.restore();
}

/// 돌을 튕기는 시범: [from] 에서 [to] 로 손끝이 빠르게 지나간다. [t] 는 초(계속 흐름).
class GhostFlickPainter extends CustomPainter {
  GhostFlickPainter({
    required this.from,
    required this.to,
    required this.t,
    this.size = 90,
  });
  final Offset from;
  final Offset to;
  final double t;
  final double size;

  static const period = 1.9;

  @override
  void paint(Canvas canvas, Size _) {
    final u = (t % period) / period;
    final dir = to - from;
    final angle = math.atan2(dir.dy, dir.dx);
    // 0~0.18 나타남 · 0.18~0.42 빠르게 튕김 · 0.42~0.62 사라짐.
    double alpha;
    double k;
    if (u < 0.18) {
      alpha = u / 0.18;
      k = 0;
    } else if (u < 0.42) {
      alpha = 1;
      k = Curves.easeIn.transform(((u - 0.18) / 0.24).clamp(0.0, 1.0));
    } else if (u < 0.62) {
      alpha = 1 - (u - 0.42) / 0.2;
      k = 1 + 0.25 * (u - 0.42) / 0.2;
    } else {
      return;
    }
    final tip = from + dir * k;
    // 지나온 자리 빛줄기.
    if (k > 0) {
      final a = from + dir * math.max(0, k - 0.5);
      canvas.drawLine(
        a,
        tip,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              const Color(0xFFFFE08A).withValues(alpha: 0.9 * alpha),
            ],
          ).createShader(Rect.fromPoints(a, tip))
          ..strokeWidth = size * 0.16
          ..strokeCap = StrokeCap.round,
      );
    }
    paintHand(canvas, tip, angle, size, alpha);
  }

  @override
  bool shouldRepaint(covariant GhostFlickPainter old) => true;
}

/// 여기를 누르세요: 퍼지는 고리 + 톡톡 누르는 손.
class GhostTapPainter extends CustomPainter {
  GhostTapPainter({
    required this.at,
    required this.t,
    this.size = 80,
    this.ring = 34,
  });
  final Offset at;
  final double t;
  final double size;
  final double ring;

  @override
  void paint(Canvas canvas, Size _) {
    final u = (t % 1.2) / 1.2;
    for (final d in [0.0, 0.5]) {
      final v = (u + d) % 1;
      canvas.drawCircle(
        at,
        ring * (0.6 + v * 0.9),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFFFFE08A).withValues(alpha: 1 - v),
      );
    }
    final press = u < 0.25 ? math.sin(u / 0.25 * math.pi) : 0.0;
    // 손은 오른쪽 아래에서 비스듬히 누른다.
    final tip =
        at + Offset(4, 6 + press * -2) + Offset(1, 1) * (1 - press) * 10;
    paintHand(canvas, tip, -math.pi / 2 - 0.45, size, 1, pressed: press > 0.5);
  }

  @override
  bool shouldRepaint(covariant GhostTapPainter old) => true;
}

/// 계속 흐르는 시간으로 다시 그리는 틀.
class Ghost extends StatefulWidget {
  const Ghost({super.key, required this.builder});
  final CustomPainter Function(double t) builder;

  @override
  State<Ghost> createState() => _GhostState();
}

class _GhostState extends State<Ghost> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();
  final _start = DateTime.now();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        key: const Key('ghost-hand'),
        painter: widget.builder(
          DateTime.now().difference(_start).inMilliseconds / 1000,
        ),
      ),
    ),
  );
}
