import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart' show Colors;

import 'match.dart';

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

/// 재질·편마다 돌 겉면 색 (밝은 쪽, 어두운 쪽). 편 0 = 밝은 돌, 편 1 = 어두운 돌, 편 2 = 백성 돌(짚빛).
(Color, Color) _faceColors(StoneMaterial m, int team) => switch ((m, team)) {
  (_, 2) => (const Color(0xFFF0DFA8), const Color(0xFFB8964E)),
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
  double scale,
) {
  final c = at(f.x, f.y);
  final r = f.size * scale;
  switch (f.kind) {
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
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFF3FAF6A));
      canvas.drawCircle(
        c,
        r * 0.7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.15
          ..color = const Color(0xFF9BE8B5),
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
