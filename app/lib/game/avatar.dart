import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../progress/profile.dart';

/// 내 캐릭터 얼굴(설계서 §2.5): 얼굴형·머리 모양·도복 색. 능력치와는 상관없다.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.face,
    required this.hair,
    required this.robe,
    this.size = 72,
  });

  Avatar.of(Profile p, {super.key, this.size = 72})
    : face = p.face,
      hair = p.hair,
      robe = p.robe;

  final int face;
  final int hair;
  final int robe;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _AvatarPainter(face, hair, robe)),
  );
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.face, this.hair, this.robe);
  final int face;
  final int hair;
  final int robe;

  static const skin = Color(0xFFF1CFA8);
  static const ink = Color(0xFF1B1410);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h * 0.42);
    final r = w * 0.24;
    // 도복(어깨).
    final robeColor = Color(robeColors[robe % robeColors.length]);
    final body = Path()
      ..moveTo(w * 0.1, h)
      ..quadraticBezierTo(w * 0.12, h * 0.68, w / 2, h * 0.66)
      ..quadraticBezierTo(w * 0.88, h * 0.68, w * 0.9, h)
      ..close();
    canvas.drawPath(body, Paint()..color = robeColor);
    // 깃(흰 동정).
    final collar = Paint()
      ..color = const Color(0xFFF5F0E4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035;
    canvas.drawLine(Offset(w * 0.4, h * 0.68), Offset(w / 2, h * 0.86), collar);
    canvas.drawLine(Offset(w * 0.6, h * 0.68), Offset(w / 2, h * 0.86), collar);
    // 얼굴형.
    final facePaint = Paint()..color = skin;
    switch (face % faceShapes.length) {
      case 0:
        canvas.drawCircle(c, r, facePaint);
      case 1:
        canvas.drawOval(
          Rect.fromCenter(center: c, width: r * 1.75, height: r * 2.25),
          facePaint,
        );
      default:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: r * 2, height: r * 2.1),
            Radius.circular(r * 0.35),
          ),
          facePaint,
        );
    }
    // 눈·눈썹·입.
    final eye = Paint()..color = ink;
    canvas.drawCircle(c + Offset(-r * 0.38, -r * 0.05), r * 0.09, eye);
    canvas.drawCircle(c + Offset(r * 0.38, -r * 0.05), r * 0.09, eye);
    final line = Paint()
      ..color = ink
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      c + Offset(-r * 0.58, -r * 0.32),
      c + Offset(-r * 0.2, -r * 0.27),
      line,
    );
    canvas.drawLine(
      c + Offset(r * 0.58, -r * 0.32),
      c + Offset(r * 0.2, -r * 0.27),
      line,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: c + Offset(0, r * 0.38),
        width: r * 0.5,
        height: r * 0.25,
      ),
      0.2,
      math.pi - 0.4,
      false,
      line..strokeWidth = r * 0.06,
    );
    // 머리.
    final hairPaint = Paint()..color = ink;
    final top = c.dy - r;
    switch (hair % hairStyles.length) {
      case 0: // 상투
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 1.04),
          math.pi,
          math.pi,
          true,
          hairPaint,
        );
        canvas.drawCircle(Offset(c.dx, top - r * 0.25), r * 0.3, hairPaint);
      case 1: // 총각머리(가운데 가르마 + 뒤로 땋음)
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 1.05),
          math.pi * 0.95,
          math.pi * 1.1,
          true,
          hairPaint,
        );
        canvas.drawLine(
          Offset(c.dx, top),
          Offset(c.dx, c.dy - r * 0.5),
          Paint()
            ..color = skin
            ..strokeWidth = r * 0.06,
        );
      case 2: // 풀어 내린 머리
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 1.08),
          math.pi,
          math.pi,
          true,
          hairPaint,
        );
        for (final s in [-1.0, 1.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                c.dx + s * r * 0.9 - r * 0.22,
                c.dy - r * 0.2,
                r * 0.44,
                r * 1.6,
              ),
              Radius.circular(r * 0.2),
            ),
            hairPaint,
          );
        }
      case 3: // 민머리(빛 반사)
        canvas.drawArc(
          Rect.fromCircle(
            center: c + Offset(-r * 0.3, -r * 0.6),
            radius: r * 0.25,
          ),
          math.pi,
          math.pi * 0.6,
          false,
          Paint()
            ..color = Colors.white70
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.06,
        );
      case 4: // 쌍상투
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 1.04),
          math.pi,
          math.pi,
          true,
          hairPaint,
        );
        canvas.drawCircle(
          Offset(c.dx - r * 0.6, top - r * 0.1),
          r * 0.28,
          hairPaint,
        );
        canvas.drawCircle(
          Offset(c.dx + r * 0.6, top - r * 0.1),
          r * 0.28,
          hairPaint,
        );
      default: // 무사 묶음(머리띠 + 뒤 꽁지)
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 1.05),
          math.pi,
          math.pi,
          true,
          hairPaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(c.dx - r * 1.02, c.dy - r * 0.62, r * 2.04, r * 0.18),
          Paint()..color = const Color(0xFFC0392B),
        );
        canvas.drawLine(
          Offset(c.dx + r, c.dy - r * 0.55),
          Offset(c.dx + r * 1.5, c.dy - r * 0.1),
          Paint()
            ..color = const Color(0xFFC0392B)
            ..strokeWidth = r * 0.12
            ..strokeCap = StrokeCap.round,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) =>
      old.face != face || old.hair != hair || old.robe != robe;
}
