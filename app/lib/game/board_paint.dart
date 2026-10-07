import 'dart:math' as math;
import 'dart:ui';

import 'package:alkkagi_physics/alkkagi_physics.dart';

/// 재질마다 돌 테두리 색.
const materialColors = {
  StoneMaterial.cheongok: Color(0xFF3E9C7D),
  StoneMaterial.wood: Color(0xFFB07A3B),
  StoneMaterial.hyeoncheol: Color(0xFF5A6270),
  StoneMaterial.ice: Color(0xFF8FD3EE),
};

/// 편 색: 0 = 흰 돌, 1 = 검은 돌.
Color stoneBase(int team) =>
    team == 0 ? const Color(0xFFF4F1EA) : const Color(0xFF1E1E22);
Color stoneShine(int team) =>
    team == 0 ? const Color(0xFFFFFFFF) : const Color(0xFF55555E);

/// 위에서 본 돌 하나. [ring] 이면 고를 수 있는 돌 표시, [selected] 면 고른 돌.
void paintTopStone(
  Canvas canvas,
  Offset c,
  double r,
  int team,
  StoneMaterial material, {
  bool ring = false,
  bool selected = false,
}) {
  canvas.drawCircle(
    c.translate(r * 0.12, r * 0.18),
    r,
    Paint()..color = const Color(0x55000000),
  );
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = Gradient.radial(c.translate(-r * 0.35, -r * 0.35), r * 1.3, [
        stoneShine(team),
        stoneBase(team),
      ]),
  );
  canvas.drawCircle(
    c,
    r * 0.86,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.22
      ..color = materialColors[material]!,
  );
  if (selected) {
    canvas.drawCircle(
      c,
      r * 1.45,
      Paint()
        ..shader = Gradient.radial(c, r * 1.45, const [
          Color(0x00FFD86A),
          Color(0xAAFFD86A),
        ]),
    );
  } else if (ring) {
    // 밝은 바닥(대리석·빙판)에서도 보이게 어두운 테를 한 번 더 두른다.
    canvas.drawCircle(
      c,
      r * 1.25,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.5, r * 0.18)
        ..color = const Color(0x66000000),
    );
    canvas.drawCircle(
      c,
      r * 1.25,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, r * 0.1)
        ..color = const Color(0xDDFFD86A),
    );
  }
}

/// 판 위 조준선(가까이 보기 화면의 작은 지도에서 쓴다).
void paintAim(
  Canvas canvas,
  Offset from,
  double angle,
  double power,
  double scale,
) {
  final len = (3 + power * 14) * scale;
  final to = from + Offset(math.cos(angle), math.sin(angle)) * len;
  final color = Color.lerp(
    const Color(0xFFFFE08A),
    const Color(0xFFE5482F),
    power,
  )!;
  final paint = Paint()
    ..color = color
    ..strokeWidth = math.max(2, scale * 0.3)
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(from, to, paint);
  final head = scale * 1.1;
  for (final a in [angle + 2.6, angle - 2.6]) {
    canvas.drawLine(to, to + Offset(math.cos(a), math.sin(a)) * head, paint);
  }
}
