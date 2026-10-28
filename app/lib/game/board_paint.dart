import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart' show Colors;

import 'match.dart';
import '../ui/art.dart';

import 'package:alkkagi_physics/alkkagi_physics.dart';

/// 재질마다 돌 테두리 색.
const materialColors = {
  StoneMaterial.cheongok: Color(0xFF3E9C7D),
  StoneMaterial.wood: Color(0xFFB07A3B),
  StoneMaterial.hyeoncheol: Color(0xFF5A6270),
  StoneMaterial.ice: Color(0xFF8FD3EE),
  StoneMaterial.obsidian: Color(0xFF6A4E9A),
  StoneMaterial.granite: Color(0xFF8C8478),
  StoneMaterial.diamond: Color(0xFFCDEFFF),
  StoneMaterial.jageum: Color(0xFFB07CE0),
  StoneMaterial.uncheol: Color(0xFF8A4A3A),
  StoneMaterial.hancheol: Color(0xFF6E9AC8),
  StoneMaterial.warmJade: Color(0xFFF0D2B0),
  StoneMaterial.dragonScale: Color(0xFFE8B040),
  StoneMaterial.taegeuk: Color(0xFFE8E8F0),
};

/// 편 색: 0 = 흰 돌, 1 = 검은 돌.
Color stoneBase(int team) =>
    team == 0 ? const Color(0xFFF4F1EA) : const Color(0xFF1E1E22);
Color stoneShine(int team) =>
    team == 0 ? const Color(0xFFFFFFFF) : const Color(0xFF55555E);

/// 재질·편마다 돌 겉면 색 (밝은 쪽, 어두운 쪽). 편 0 = 밝은 돌, 편 1 = 어두운 돌, 편 2 = 백성 돌(짚빛).
(Color, Color) _faceColors(StoneMaterial m, int team) => switch ((m, team)) {
  (_, 2) => (const Color(0xFFF0DFA8), const Color(0xFFB8964E)),
  // 편 3 = 점수전 보주(붉은 구슬).
  (_, 3) => (const Color(0xFFFF8A80), const Color(0xFF9B1B1B)),
  (StoneMaterial.cheongok, 0) => (
    const Color(0xFFD9F2E6),
    const Color(0xFF6DBB97),
  ),
  (StoneMaterial.cheongok, _) => (
    const Color(0xFF3F8A6C),
    const Color(0xFF0F3324),
  ),
  (StoneMaterial.wood, 0) => (const Color(0xFFF1D3A0), const Color(0xFFB57D3C)),
  (StoneMaterial.wood, _) => (const Color(0xFF7A4E2A), const Color(0xFF2E190B)),
  (StoneMaterial.hyeoncheol, 0) => (
    const Color(0xFFF2F4F7),
    const Color(0xFF8C939D),
  ),
  (StoneMaterial.hyeoncheol, _) => (
    const Color(0xFF6B727B),
    const Color(0xFF1C1F23),
  ),
  (StoneMaterial.ice, 0) => (const Color(0xFFF7FDFF), const Color(0xFF9FD8EF)),
  (StoneMaterial.ice, _) => (const Color(0xFF4C88A6), const Color(0xFF122F42)),
  // 2026-10-14 새 재질: 흑요석(보랏빛 검은 유리) · 반석(얼룩진 회색 돌) · 금강석(무지개 반짝임).
  (StoneMaterial.obsidian, 0) => (
    const Color(0xFFE8E0F2),
    const Color(0xFF8A78A8),
  ),
  (StoneMaterial.obsidian, _) => (
    const Color(0xFF3A2E4A),
    const Color(0xFF0C0812),
  ),
  (StoneMaterial.granite, 0) => (
    const Color(0xFFE6E1D8),
    const Color(0xFF9A9286),
  ),
  (StoneMaterial.granite, _) => (
    const Color(0xFF5E5850),
    const Color(0xFF221F1A),
  ),
  (StoneMaterial.diamond, 0) => (
    const Color(0xFFFFFFFF),
    const Color(0xFFBFE6F5),
  ),
  (StoneMaterial.diamond, _) => (
    const Color(0xFF7FA6C8),
    const Color(0xFF1E3550),
  ),
  // 2026-10-14 등급 돌: 자금석(보랏빛 금) · 운철(검붉은 쇠) · 한철(푸른 쇠) ·
  // 천년온옥(따뜻한 흰 옥) · 용린석(금빛 비늘) · 태극석(흑백).
  (StoneMaterial.jageum, 0) => (
    const Color(0xFFF2E2FF),
    const Color(0xFFA77BD0),
  ),
  (StoneMaterial.jageum, _) => (
    const Color(0xFF5A3A7A),
    const Color(0xFF1C0F2A),
  ),
  (StoneMaterial.uncheol, 0) => (
    const Color(0xFFEDE0DA),
    const Color(0xFF9A7A6C),
  ),
  (StoneMaterial.uncheol, _) => (
    const Color(0xFF5A3A32),
    const Color(0xFF1E100C),
  ),
  (StoneMaterial.hancheol, 0) => (
    const Color(0xFFE6F0FA),
    const Color(0xFF7F9AB6),
  ),
  (StoneMaterial.hancheol, _) => (
    const Color(0xFF3E5670),
    const Color(0xFF0E1A28),
  ),
  (StoneMaterial.warmJade, 0) => (
    const Color(0xFFFFF6EC),
    const Color(0xFFE8C9A8),
  ),
  (StoneMaterial.warmJade, _) => (
    const Color(0xFF9A7A5A),
    const Color(0xFF3A2614),
  ),
  (StoneMaterial.dragonScale, 0) => (
    const Color(0xFFFFF2C8),
    const Color(0xFFD9A43A),
  ),
  (StoneMaterial.dragonScale, _) => (
    const Color(0xFF8A5E1A),
    const Color(0xFF2E1C06),
  ),
  (StoneMaterial.taegeuk, 0) => (
    const Color(0xFFFFFFFF),
    const Color(0xFFB8B8C0),
  ),
  (StoneMaterial.taegeuk, _) => (
    const Color(0xFF3A3A44),
    const Color(0xFF0A0A0E),
  ),
};

/// 반지름 100 으로 그려 둔 돌 그림(재질·모양·편마다 한 장). 프레임마다 다시 그리지 않는다.
final _stonePictures = <(StoneMaterial, StoneShape, int), Picture>{};

Picture _stonePicture(StoneMaterial m, StoneShape shape, int team) =>
    _stonePictures.putIfAbsent((m, shape, team), () {
      final rec = PictureRecorder();
      _drawStone(Canvas(rec), m, shape, team);
      return rec.endRecording();
    });

/// 반지름 100, 가운데 (0, 0) 에 입체 돌 하나를 그린다.
///
/// 위에서 조금 비스듬히 본다: 납작한 돌·둥근 돌은 아래쪽에 두께(옆면)가 보이고, 구형 돌은
/// 둥글게 그늘진다. 겉면에는 재질 무늬(청옥 결·나무 나이테·현철 깎은 결·얼음 금)를 넣는다.
void _drawStone(Canvas c, StoneMaterial m, StoneShape shape, int team) {
  const r = 100.0;
  final (light, dark) = _faceColors(m, team);
  final rand = math.Random(m.index * 31 + shape.index * 7 + team);
  // 바닥 그림자.
  c.drawOval(
    Rect.fromCenter(
      center: const Offset(14, 24),
      width: r * 2.1,
      height: r * 1.9,
    ),
    Paint()
      ..color = const Color(0x66000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
  );
  // 옆면(두께): 높이에 비례해 아래로 보인다. 구형 돌은 없다.
  final band = switch (shape) {
    StoneShape.flat => r * 0.14,
    StoneShape.round => r * 0.2,
    StoneShape.sphere => 0.0,
  };
  if (band > 0) {
    final side = Color.lerp(dark, Colors.black, 0.35)!;
    c.drawCircle(
      Offset(0, band),
      r,
      Paint()
        ..shader = Gradient.linear(
          const Offset(-r, 0),
          const Offset(r, 0),
          [side, Color.lerp(side, light, 0.35)!, side],
          const [0, 0.4, 1],
        ),
    );
  }
  // 윗면.
  final face = Rect.fromCircle(center: Offset.zero, radius: r);
  final faceShader = switch (shape) {
    StoneShape.sphere => Gradient.radial(
      const Offset(-35, -40),
      r * 1.45,
      [
        Color.lerp(light, Colors.white, 0.5)!,
        light,
        dark,
        Color.lerp(dark, Colors.black, 0.5)!,
      ],
      const [0, 0.25, 0.75, 1],
    ),
    StoneShape.round => Gradient.radial(
      const Offset(-30, -35),
      r * 1.5,
      [Color.lerp(light, Colors.white, 0.3)!, light, dark],
      const [0, 0.45, 1],
    ),
    StoneShape.flat => Gradient.linear(
      const Offset(-r, -r),
      const Offset(r, r),
      [
        Color.lerp(light, Colors.white, 0.15)!,
        Color.lerp(light, dark, 0.45)!,
        dark,
      ],
      const [0, 0.6, 1],
    ),
  };
  c.drawOval(face, Paint()..shader = faceShader);

  // 재질 무늬(윗면 안에서만).
  c.save();
  c.clipPath(Path()..addOval(face));
  final ink = Color.lerp(dark, Colors.black, team == 0 ? 0.1 : 0.4)!;
  switch (m) {
    case StoneMaterial.cheongok:
      // 옥의 흐린 결: 굽이치는 옅은 띠.
      for (var i = 0; i < 4; i++) {
        final y0 = -70 + i * 45 + rand.nextDouble() * 20;
        final path = Path()..moveTo(-110, y0);
        for (var x = -110.0; x <= 110; x += 20) {
          path.lineTo(
            x,
            y0 + math.sin(x / 30 + i) * 12 + rand.nextDouble() * 6,
          );
        }
        c.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6 + rand.nextDouble() * 8
            ..color = Colors.white.withValues(alpha: team == 0 ? 0.28 : 0.12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
    case StoneMaterial.wood:
      // 나이테: 한쪽으로 치우친 고리 + 결.
      const o = Offset(-40, 30);
      for (var k = 1; k <= 9; k++) {
        c.drawOval(
          Rect.fromCenter(center: o, width: k * 34.0, height: k * 24.0),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = ink.withValues(alpha: 0.35),
        );
      }
      for (var i = 0; i < 14; i++) {
        final y = -100 + i * 15.0 + rand.nextDouble() * 6;
        c.drawLine(
          Offset(-110, y),
          Offset(110, y + 8),
          Paint()
            ..strokeWidth = 1
            ..color = ink.withValues(alpha: 0.15),
        );
      }
    case StoneMaterial.hyeoncheol:
      // 쇠를 깎은 둥근 결 + 비스듬한 빛줄기.
      for (var k = 8; k <= 96; k += 6) {
        c.drawCircle(
          Offset.zero,
          k.toDouble(),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = (k % 12 == 0 ? Colors.white : ink).withValues(
              alpha: 0.18,
            ),
        );
      }
      c.drawLine(
        const Offset(-90, 40),
        const Offset(40, -90),
        Paint()
          ..strokeWidth = 22
          ..color = Colors.white.withValues(alpha: team == 0 ? 0.35 : 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    case StoneMaterial.ice:
      // 얼음 금과 서리.
      for (var i = 0; i < 5; i++) {
        var p = Offset(
          rand.nextDouble() * 120 - 60,
          rand.nextDouble() * 120 - 60,
        );
        final path = Path()..moveTo(p.dx, p.dy);
        final a0 = rand.nextDouble() * math.pi * 2;
        for (var k = 0; k < 5; k++) {
          final a = a0 + (rand.nextDouble() - 0.5) * 1.4;
          p += Offset(math.cos(a), math.sin(a)) * (14 + rand.nextDouble() * 18);
          path.lineTo(p.dx, p.dy);
        }
        c.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Colors.white.withValues(alpha: 0.75),
        );
      }
      for (var i = 0; i < 40; i++) {
        c.drawCircle(
          Offset(rand.nextDouble() * 200 - 100, rand.nextDouble() * 200 - 100),
          1 + rand.nextDouble() * 2,
          Paint()..color = Colors.white.withValues(alpha: 0.35),
        );
      }
    case StoneMaterial.obsidian:
      // 흑요석: 유리처럼 깨진 날카로운 면 · 보랏빛 반사.
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3 + rand.nextDouble() * 0.4;
        c.drawLine(
          Offset.zero,
          Offset(math.cos(a), math.sin(a)) * 110,
          Paint()
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: team == 0 ? 0.3 : 0.16),
        );
      }
      c.drawLine(
        const Offset(-80, -10),
        const Offset(10, -80),
        Paint()
          ..strokeWidth = 16
          ..color = const Color(0xFFB79CFF).withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    case StoneMaterial.granite:
      // 반석: 얼룩덜룩한 알갱이.
      for (var i = 0; i < 90; i++) {
        c.drawCircle(
          Offset(rand.nextDouble() * 200 - 100, rand.nextDouble() * 200 - 100),
          2 + rand.nextDouble() * 5,
          Paint()
            ..color = (rand.nextBool() ? ink : Colors.white).withValues(
              alpha: 0.18 + rand.nextDouble() * 0.15,
            ),
        );
      }
    case StoneMaterial.diamond:
      // 금강석: 깎은 면(팔각) + 무지개 반짝임.
      final cut = Path();
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4 + math.pi / 8;
        final p = Offset(math.cos(a), math.sin(a)) * 62;
        k == 0 ? cut.moveTo(p.dx, p.dy) : cut.lineTo(p.dx, p.dy);
      }
      cut.close();
      c.drawPath(
        cut,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white.withValues(alpha: 0.7),
      );
      const rainbow = [
        Color(0xFFFF8A8A),
        Color(0xFFFFE08A),
        Color(0xFF8AFFB0),
        Color(0xFF8AC8FF),
        Color(0xFFD08AFF),
      ];
      for (var i = 0; i < 10; i++) {
        c.drawCircle(
          Offset(rand.nextDouble() * 160 - 80, rand.nextDouble() * 160 - 80),
          2 + rand.nextDouble() * 3,
          Paint()..color = rainbow[i % rainbow.length].withValues(alpha: 0.8),
        );
      }
    case StoneMaterial.jageum ||
        StoneMaterial.uncheol ||
        StoneMaterial.hancheol:
      // 쇠 무리: 깎은 둥근 결 + 금(자금석)·불티(운철)·서리(한철).
      for (var k = 10; k <= 96; k += 7) {
        c.drawCircle(
          Offset.zero,
          k.toDouble(),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = ink.withValues(alpha: 0.2),
        );
      }
      final spark = switch (m) {
        StoneMaterial.jageum => const Color(0xFFFFD25A),
        StoneMaterial.uncheol => const Color(0xFFFF7A3A),
        _ => const Color(0xFFDFF4FF),
      };
      for (var i = 0; i < 16; i++) {
        c.drawCircle(
          Offset(rand.nextDouble() * 170 - 85, rand.nextDouble() * 170 - 85),
          1.5 + rand.nextDouble() * 3,
          Paint()..color = spark.withValues(alpha: 0.75),
        );
      }
    case StoneMaterial.warmJade:
      // 천년온옥: 가운데서 번지는 따스한 빛.
      c.drawCircle(
        const Offset(-20, -20),
        70,
        Paint()
          ..color = const Color(0xFFFFE0C0).withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
      );
    case StoneMaterial.dragonScale:
      // 용린석: 겹친 비늘.
      for (var row = -2; row <= 2; row++) {
        for (var col = -3; col <= 3; col++) {
          final o = Offset(col * 34.0 + (row.isOdd ? 17 : 0), row * 30.0);
          c.drawArc(
            Rect.fromCircle(center: o, radius: 20),
            0,
            math.pi,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = ink.withValues(alpha: 0.45),
          );
        }
      }
    case StoneMaterial.taegeuk:
      // 태극석: 음양.
      const r = 70.0;
      final dark = Paint()..color = const Color(0xFF15151A);
      final light = Paint()..color = const Color(0xFFF6F6F8);
      c.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r),
        -math.pi / 2,
        math.pi,
        true,
        dark,
      );
      c.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r),
        math.pi / 2,
        math.pi,
        true,
        light,
      );
      c.drawCircle(const Offset(0, -r / 2), r / 2, dark);
      c.drawCircle(const Offset(0, r / 2), r / 2, light);
      c.drawCircle(const Offset(0, -r / 2), r / 7, light);
      c.drawCircle(const Offset(0, r / 2), r / 7, dark);
  }
  c.restore();

  // 모서리: 둥근 돌은 빛 받는 쪽이 밝은 테, 납작한 돌은 가는 테.
  if (shape != StoneShape.sphere) {
    c.drawCircle(
      Offset.zero,
      r * (shape == StoneShape.round ? 0.92 : 0.97),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * (shape == StoneShape.round ? 0.14 : 0.05)
        ..shader = Gradient.linear(
          const Offset(-r, -r),
          const Offset(r, r),
          [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.35),
          ],
          const [0, 0.5, 1],
        ),
    );
  }
  // 반짝임.
  c.drawOval(
    Rect.fromCenter(
      center: const Offset(-38, -44),
      width: shape == StoneShape.flat ? 70 : 46,
      height: shape == StoneShape.flat ? 26 : 30,
    ),
    Paint()
      ..color = Colors.white.withValues(
        alpha: switch (m) {
          StoneMaterial.hyeoncheol || StoneMaterial.ice => 0.8,
          _ => team == 0 ? 0.6 : 0.3,
        },
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );
}

/// 장수전의 장수 돌 표시: 금테 두 겹과 위쪽 작은 왕관(세 꼭지).
void paintGeneralMark(Canvas canvas, Offset c, double r) {
  canvas.drawCircle(
    c,
    r * 1.08,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.22
      ..color = const Color(0xFF3A2400),
  );
  canvas.drawCircle(
    c,
    r * 1.08,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.13
      ..color = const Color(0xFFFFD25A),
  );
  final w = r * 0.9, h = r * 0.55, top = c.translate(0, -r * 1.35);
  final crown = Path()
    ..moveTo(top.dx - w / 2, top.dy + h / 2)
    ..lineTo(top.dx - w / 2, top.dy - h / 2)
    ..lineTo(top.dx - w / 4, top.dy)
    ..lineTo(top.dx, top.dy - h / 2)
    ..lineTo(top.dx + w / 4, top.dy)
    ..lineTo(top.dx + w / 2, top.dy - h / 2)
    ..lineTo(top.dx + w / 2, top.dy + h / 2)
    ..close();
  canvas.drawPath(
    crown,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.16
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF3A2400),
  );
  canvas.drawPath(crown, Paint()..color = const Color(0xFFFFD25A));
}

/// 위에서 본 입체 돌 하나(재질·모양·편대로). [ring] 이면 고를 수 있는 돌 표시, [selected] 면 고른 돌.
void paintTopStone(
  Canvas canvas,
  Offset c,
  double r,
  int team,
  StoneMaterial material, {
  StoneShape shape = StoneShape.round,
  bool ring = false,
  bool selected = false,
}) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(r / 100);
  canvas.drawPicture(_stonePicture(material, shape, team));
  canvas.restore();
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

/// 떠 있는 돌의 바닥 그림자. 높이 [z](cm)가 클수록 옅고 작다.
void paintAirShadow(Canvas canvas, Offset ground, double r, double z) {
  final k = 1 / (1 + z * 0.35);
  canvas.drawOval(
    Rect.fromCenter(center: ground, width: r * 2 * k, height: r * 1.6 * k),
    Paint()
      ..color = Color.fromRGBO(0, 0, 0, 0.45 * k)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25),
  );
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

/// 판 위 지물 하나(설계서 §9.4·§10.2).
void paintFeature(
  Canvas canvas,
  Feature f,
  Offset Function(double x, double y) at,
  double scale, {
  (double, double, double)? pose,
}) {
  final c = at(f.x, f.y);
  final r = f.size * scale;
  switch (f.kind) {
    // 새 장애물(2026-10-28)은 코덱스 그림을 위에서 본 모양으로 그린다. 그림이 없으면 색 동그라미.
    case FeatureKind.quicksand ||
        FeatureKind.barrel ||
        FeatureKind.whirlpool ||
        FeatureKind.lavaPit ||
        FeatureKind.cloud:
      _paintObstacle(canvas, f.kind, c, r, scale);
    case FeatureKind.pillar:
      // 회전 기둥: 지금 자리·각도로 다각형 돌기둥(금빛 테 · 가운데 소용돌이 · 2026-10-20).
      final (px, py, pa) = pose ?? (f.x, f.y, f.angle);
      final pc = at(px, py);
      final n = f.sides.clamp(3, 8);
      Path poly(double rr) {
        final path = Path();
        for (var k = 0; k < n; k++) {
          final a = pa + k * 2 * math.pi / n;
          final p = pc + Offset(math.cos(a), math.sin(a)) * rr;
          if (k == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        return path..close();
      }

      canvas.drawPath(
        poly(r * 1.12).shift(Offset(r * 0.12, r * 0.18)),
        Paint()..color = const Color(0x77000000),
      );
      canvas.drawPath(poly(r * 1.08), Paint()..color = const Color(0xFF2A1A0A));
      canvas.drawPath(
        poly(r),
        Paint()
          ..shader = Gradient.radial(pc, r, const [
            Color(0xFFE9C46A),
            Color(0xFF9A6A2A),
          ]),
      );
      canvas.drawPath(
        poly(r * 0.62),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, r * 0.1)
          ..color = const Color(0xCC5A3A12),
      );
      // 도는 쪽을 알려 주는 소용돌이 한 줄.
      canvas.drawArc(
        Rect.fromCircle(center: pc, radius: r * 0.35),
        pa,
        math.pi * 1.2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(1.5, r * 0.12)
          ..color = const Color(0xFFFFF1C2),
      );
    case FeatureKind.fence:
      // 담장: 나무 널빤지 벽 한 토막(위에서 본 모습 · 2026-10-20). 부딪히는 안쪽 면은 그대로 두고
      // 판 바깥쪽으로만 두껍게 그려 눈에 띄게 한다.
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(f.angle);
      final h = TerrainConstants.fenceHalfThickness * 2 * scale;
      final normal = Offset(-math.sin(f.angle), math.cos(f.angle));
      final sign = (f.x * normal.dx + f.y * normal.dy) >= 0 ? 1.0 : -1.0;
      final thick = h * 2.6;
      final inner = -sign * h / 2;
      final rect = Rect.fromLTWH(
        -r,
        sign > 0 ? inner : inner - thick,
        r * 2,
        thick,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.inflate(h * 0.2),
          Radius.circular(h * 0.4),
        ),
        Paint()..color = const Color(0xE62A1608),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(h * 0.3)),
        Paint()..color = const Color(0xFFB07A44),
      );
      final seam = Paint()
        ..color = const Color(0xFF5A3A1C)
        ..strokeWidth = math.max(1, h * 0.1);
      for (var x = -r + r / 3; x < r; x += r / 3) {
        canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), seam);
      }
      canvas.drawLine(
        Offset(-r, inner + sign * h * 0.3),
        Offset(r, inner + sign * h * 0.3),
        Paint()
          ..color = const Color(0x99FFE2B0)
          ..strokeWidth = math.max(1.5, h * 0.2),
      );
      for (final x in [-r, r]) {
        canvas.drawCircle(
          Offset(x, rect.center.dy),
          thick * 0.55,
          Paint()..color = const Color(0xFF3A2410),
        );
        canvas.drawCircle(
          Offset(x, rect.center.dy),
          thick * 0.38,
          Paint()..color = const Color(0xFFC8925A),
        );
      }
      canvas.restore();
    case FeatureKind.rock:
      // 바위: 짙은 그림자 · 회색 몸 · 진한 테 · 밝은 윗면.
      canvas.drawCircle(
        c.translate(r * 0.12, r * 0.18),
        r * 1.08,
        Paint()..color = const Color(0x66000000),
      );
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFF7A756B));
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, r * 0.12)
          ..color = const Color(0xFF2E2B26),
      );
      canvas.drawCircle(
        c.translate(-r * 0.25, -r * 0.3),
        r * 0.5,
        Paint()..color = const Color(0x55FFFFFF),
      );
    case FeatureKind.branch:
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(f.angle);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: r * 2,
        height: TerrainConstants.branchHalfThickness * 2 * scale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
        Paint()..color = const Color(0xFF6B4423),
      );
      for (final x in [-0.5, 0.2, 0.7]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x * r, -rect.height),
            width: rect.height * 2.2,
            height: rect.height * 1.2,
          ),
          Paint()..color = const Color(0xFF4F8A3A),
        );
      }
      canvas.restore();
    case FeatureKind.pebble:
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFF8C8578));
      canvas.drawCircle(
        c.translate(-r * 0.3, -r * 0.3),
        r * 0.35,
        Paint()..color = const Color(0x55FFFFFF),
      );
    case FeatureKind.bamboo:
      // 위에서 본 청죽 단면: 튕겨 내는 기운(옅은 테) · 진한 테두리 · 속 빈 마디.
      // 실제 크기(반지름 0.8cm)로만 그리면 숲 바닥에서 잘 안 보였다(2026-10-11 화면 확인).
      canvas.drawCircle(
        c,
        r * 2.1,
        Paint()
          ..shader = Gradient.radial(c, r * 2.1, const [
            Color(0x669BE8B5),
            Color(0x009BE8B5),
          ]),
      );
      canvas.drawCircle(c, r * 1.12, Paint()..color = const Color(0xFF123D22));
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFF3FAF6A));
      canvas.drawCircle(c, r * 0.62, Paint()..color = const Color(0xFFDDF5C9));
      canvas.drawCircle(
        c,
        r * 0.62,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.14
          ..color = const Color(0xFF2E8A50),
      );
    case FeatureKind.gong:
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = Gradient.radial(c.translate(-r * 0.3, -r * 0.3), r * 1.4, [
            const Color(0xFFF2CF7A),
            const Color(0xFF9A6B1F),
          ]),
      );
      for (final k in [0.45, 0.75]) {
        canvas.drawCircle(
          c,
          r * k,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.06
            ..color = const Color(0xFF6B4A12),
        );
      }
    case FeatureKind.blackHole:
      final rr = TerrainConstants.holeRadius * scale;
      canvas.drawCircle(
        c,
        rr,
        Paint()
          ..shader = Gradient.radial(
            c,
            rr,
            const [Color(0xFF000000), Color(0xAA2A0A4A), Color(0x002A0A4A)],
            const [0.15, 0.5, 1],
          ),
      );
    case FeatureKind.mine:
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFF3A1A1A));
      final p = Paint()
        ..color = const Color(0xFFE53935)
        ..strokeWidth = r * 0.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        c.translate(-r * 0.5, -r * 0.5),
        c.translate(r * 0.5, r * 0.5),
        p,
      );
      canvas.drawLine(
        c.translate(r * 0.5, -r * 0.5),
        c.translate(-r * 0.5, r * 0.5),
        p,
      );
  }
}

/// 새 장애물 한 개: 그림이 있으면 그림(구역 지물은 구역 크기 · 부딪히는 지물은 살짝 크게), 없으면 색 동그라미.
void _paintObstacle(
  Canvas canvas,
  FeatureKind k,
  Offset c,
  double r,
  double scale,
) {
  final zone = k == FeatureKind.quicksand || k == FeatureKind.whirlpool;
  // 용암 구멍은 끌어당기는 둘레까지 붉게 번진다(가까이 가면 위험한 것이 보이게).
  if (k == FeatureKind.lavaPit) {
    final rr = TerrainConstants.lavaRadius * scale;
    canvas.drawCircle(
      c,
      rr,
      Paint()
        ..shader = Gradient.radial(c, rr, const [
          Color(0x88FF5A1E),
          Color(0x00FF5A1E),
        ]),
    );
  }
  final img = Art.obstacleImage(k);
  final draw = zone ? r : r * 1.15;
  if (img != null) {
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromCircle(center: c, radius: draw),
      Paint()..filterQuality = FilterQuality.medium,
    );
    return;
  }
  final (inner, outer) = switch (k) {
    FeatureKind.quicksand => (const Color(0xCC8A5A20), const Color(0x33D9A85A)),
    FeatureKind.barrel => (const Color(0xFF8A5A2E), const Color(0xFF4A2E14)),
    FeatureKind.whirlpool => (const Color(0xAA8FD3EE), const Color(0x228FD3EE)),
    FeatureKind.lavaPit => (const Color(0xFFFFB03A), const Color(0xFF2A1410)),
    _ => (const Color(0xFFFFFFFF), const Color(0xFFE8D9A0)),
  };
  canvas.drawCircle(
    c,
    draw,
    Paint()..shader = Gradient.radial(c, draw, [inner, outer]),
  );
}

/// 날씨 그림(설계서 §9.3). 야우: 내 돌 둘레 10cm 만 밝고 상대 돌은 실루엣 · 광풍: 바람 줄 · 혹한: 서리.
void paintWeather(
  Canvas canvas,
  Size size,
  Match match,
  Offset Function(double x, double y) at,
  double scale,
  double clock,
) {
  final rect = Offset.zero & size;
  switch (match.config.weather) {
    case Weather.clear:
      return;
    case Weather.nightRain:
      canvas.saveLayer(rect, Paint());
      canvas.drawRect(rect, Paint()..color = const Color(0xF0070A14));
      for (final s in match.table.stones) {
        if (s.out || s.team != 0) continue;
        final c = at(s.position.x, s.position.y);
        final r = 10 * scale;
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..blendMode = BlendMode.dstOut
            ..shader = Gradient.radial(
              c,
              r,
              const [Color(0xFF000000), Color(0x00000000)],
              const [0.6, 1],
            ),
        );
      }
      canvas.restore();
      // 상대 돌은 실루엣.
      for (final s in match.table.stones) {
        if (s.out || s.team == 0) continue;
        canvas.drawCircle(
          at(s.position.x, s.position.y),
          PhysicsConstants.stoneRadius * scale,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0x88B0C4FF),
        );
      }
      final rain = Paint()
        ..color = const Color(0x55A0B8FF)
        ..strokeWidth = 1;
      final rand = math.Random(7);
      for (var i = 0; i < 70; i++) {
        final x = rand.nextDouble() * size.width;
        final y = (rand.nextDouble() * size.height + clock * 600) % size.height;
        canvas.drawLine(Offset(x, y), Offset(x - 3, y + 12), rain);
      }
    case Weather.gale:
      final a = match.table.windAngle ?? 0;
      final d = Offset(math.cos(a), math.sin(a));
      final p = Paint()
        ..color = const Color(0x55FFFFFF)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      final rand = math.Random(11);
      for (var i = 0; i < 24; i++) {
        final base = Offset(
          rand.nextDouble() * size.width,
          rand.nextDouble() * size.height,
        );
        final shift = d * ((clock * 220 + i * 40) % (size.longestSide));
        final o = Offset(
          (base.dx + shift.dx) % size.width,
          (base.dy + shift.dy) % size.height,
        );
        canvas.drawLine(o, o + d * 26, p);
      }
    case Weather.frost:
      canvas.drawRect(rect, Paint()..color = const Color(0x2299DDFF));
      final rand = math.Random(5);
      final p = Paint()..color = const Color(0x66FFFFFF);
      for (var i = 0; i < 50; i++) {
        canvas.drawCircle(
          Offset(
            rand.nextDouble() * size.width,
            rand.nextDouble() * size.height,
          ),
          1 + rand.nextDouble() * 1.5,
          p,
        );
      }
  }
}

/// 돌 표정(2026-10-20 형 「묘한 중독성이랑 은근히 웃기도 재미가」 · 앱 아이콘의 귀여운 흰 돌처럼).
enum StoneMood { calm, scared, fierce, dizzy, eek }

/// 돌 위에 얼굴을 그린다. [blink] 0~1(1 이면 눈 감음). 흰 돌은 짙은 이목구비, 검은 돌은 밝은 이목구비.
void paintStoneFace(
  Canvas canvas,
  Offset c,
  double r,
  int team,
  StoneMood mood, {
  double blink = 0,
  double t = 0,
}) {
  if (r < 6) return; // 너무 작으면 그리지 않는다.
  final ink = team == 0 ? const Color(0xDD2A1A12) : const Color(0xEEF4EEE2);
  final line = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1, r * 0.09)
    ..strokeCap = StrokeCap.round;
  final fill = Paint()..color = ink;
  final ex = r * 0.32, ey = -r * 0.08, er = r * 0.12;
  final l = c.translate(-ex, ey), rr = c.translate(ex, ey);
  switch (mood) {
    case StoneMood.calm:
      if (blink > 0.5) {
        for (final e in [l, rr]) {
          canvas.drawLine(e.translate(-er, 0), e.translate(er, 0), line);
        }
      } else {
        canvas.drawOval(
          Rect.fromCenter(center: l, width: er * 1.5, height: er * 2),
          fill,
        );
        canvas.drawOval(
          Rect.fromCenter(center: rr, width: er * 1.5, height: er * 2),
          fill,
        );
      }
      canvas.drawArc(
        Rect.fromCenter(
          center: c.translate(0, r * 0.22),
          width: r * 0.4,
          height: r * 0.25,
        ),
        0.2,
        math.pi - 0.4,
        false,
        line,
      );
    case StoneMood.scared:
      final white = Paint()..color = const Color(0xFFFFFFFF);
      for (final e in [l, rr]) {
        canvas.drawCircle(e, er * 1.5, white);
        canvas.drawCircle(
          e,
          er * 1.5,
          line..strokeWidth = math.max(1, r * 0.06),
        );
        canvas.drawCircle(
          e.translate(0, er * 0.3),
          er * 0.55,
          Paint()..color = const Color(0xFF1A1010),
        );
      }
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(0, r * 0.32),
          width: r * 0.18,
          height: r * 0.24,
        ),
        fill,
      );
      // 땀방울.
      final drop = c.translate(
        r * 0.62,
        -r * 0.45 + math.sin(t * 6) * r * 0.04,
      );
      canvas.drawCircle(
        drop,
        r * 0.11,
        Paint()..color = const Color(0xFF7FC8FF),
      );
    case StoneMood.fierce:
      for (final (e, s) in [(l, 1.0), (rr, -1.0)]) {
        canvas.drawCircle(e, er * 0.9, fill);
        canvas.drawLine(
          e.translate(-er * 1.4 * s, -er * 2.1),
          e.translate(er * 1.2 * s, -er * 1.2),
          line,
        );
      }
      canvas.drawArc(
        Rect.fromCenter(
          center: c.translate(0, r * 0.2),
          width: r * 0.5,
          height: r * 0.35,
        ),
        0.1,
        math.pi - 0.2,
        false,
        line,
      );
    case StoneMood.dizzy:
      for (final e in [l, rr]) {
        final p = Path();
        for (var k = 0; k <= 24; k++) {
          final a = t * 8 + k * 0.5;
          final rad = er * 1.6 * k / 24;
          final q = e + Offset(math.cos(a), math.sin(a)) * rad;
          k == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
        }
        canvas.drawPath(p, line);
      }
      final w = Path()..moveTo(c.dx - r * 0.22, c.dy + r * 0.3);
      for (var k = 1; k <= 4; k++) {
        w.lineTo(
          c.dx - r * 0.22 + k * r * 0.11,
          c.dy + r * 0.3 + (k.isOdd ? -1 : 1) * r * 0.06,
        );
      }
      canvas.drawPath(w, line);
    case StoneMood.eek:
      for (final e in [l, rr]) {
        canvas.drawLine(e.translate(-er, -er), e.translate(er, er), line);
        canvas.drawLine(e.translate(-er, er), e.translate(er, -er), line);
      }
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(0, r * 0.3),
          width: r * 0.28,
          height: r * 0.34,
        ),
        fill,
      );
  }
}
