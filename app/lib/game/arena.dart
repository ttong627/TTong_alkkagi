import 'dart:math' as math;
import 'dart:ui';

import 'package:alkkagi_physics/alkkagi_physics.dart';

/// 대전장. 마을·맵마다 바닥 그림과 미끄러운 정도가 다르다(설계서 v2 §9.1).
///
/// [floorFactor] 는 돌 감속에 곱하는 바닥 배수다. 처음 값이며 플레이해 보며 조정한다.
enum Arena {
  dustyYard(
    '흙먼지 마을 공터',
    chapter: '1장 · 하산의 길',
    feel: '거칠어서 빨리 멈춤',
    floorFactor: 1.4,
    boundary: Boundary.square,
  ),
  oilyTable(
    '통통 객잔 원탁',
    chapter: '2장 · 기름진 난장',
    feel: '기름이 튀어 잘 미끄러짐 · 둥근 판',
    floorFactor: 0.7,
    boundary: Boundary.circle,
  ),
  turtleMarket(
    '거북 장터 돌바닥',
    chapter: '3장 · 거북 장터 난투',
    feel: '보통',
    floorFactor: 1.0,
    boundary: Boundary.square,
  ),
  kubiForest(
    '쿠비 산채 숲길',
    chapter: '4장 · 야성의 숲',
    feel: '낙엽에 조금 걸림',
    floorFactor: 1.15,
    boundary: Boundary.square,
  ),
  logicMarble(
    '로직 학당 대리석',
    chapter: '5장 · 철벽의 진인',
    feel: '매끄러움',
    floorFactor: 0.85,
    boundary: Boundary.square,
  ),
  murimIce(
    '무림맹 본단 빙판',
    chapter: '6장 · 천하제일 탄지대회',
    feel: '얼어 있어 아주 잘 미끄러짐 · 둥근 판',
    floorFactor: 0.6,
    boundary: Boundary.circle,
  );

  const Arena(
    this.label, {
    required this.chapter,
    required this.feel,
    required this.floorFactor,
    required this.boundary,
  });

  final String label;
  final String chapter;
  final String feel;
  final double floorFactor;
  final Boundary boundary;

  /// 판 둘레 밖(장외 쪽) 색.
  Color get outside => switch (this) {
    Arena.dustyYard => const Color(0xFF3A2C1E),
    Arena.oilyTable => const Color(0xFF2A1A12),
    Arena.turtleMarket => const Color(0xFF2E2A26),
    Arena.kubiForest => const Color(0xFF1E2A1C),
    Arena.logicMarble => const Color(0xFF22222A),
    Arena.murimIce => const Color(0xFF141E2C),
  };

  /// 돌 아래 바닥 대표 색(가까이 보기 화면 배경).
  Color get floor => switch (this) {
    Arena.dustyYard => const Color(0xFFB8925F),
    Arena.oilyTable => const Color(0xFF8A5530),
    Arena.turtleMarket => const Color(0xFF8F877C),
    Arena.kubiForest => const Color(0xFF5E5A33),
    Arena.logicMarble => const Color(0xFFE6E2DA),
    Arena.murimIce => const Color(0xFFB9DCEB),
  };
}

/// 판 바닥을 그린다. [toScreen] 은 판 좌표(cm) → 화면 좌표, [scale] 은 1cm 의 화면 길이.
void paintArena(
  Canvas canvas,
  Arena arena,
  Offset Function(double x, double y) toScreen,
  double scale,
) {
  const h = PhysicsConstants.halfBoard;
  final center = toScreen(0, 0);
  final rect = Rect.fromPoints(toScreen(-h, -h), toScreen(h, h));
  final round = arena.boundary == Boundary.circle;
  final shape = Path();
  if (round) {
    shape.addOval(Rect.fromCircle(center: center, radius: h * scale));
  } else {
    shape.addRect(rect);
  }

  // 테두리(장외 경계 바로 바깥).
  final rim = Paint()..color = _rimColor(arena);
  if (round) {
    canvas.drawCircle(center, (h + 0.8) * scale, rim);
  } else {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(0.8 * scale),
        Radius.circular(0.5 * scale),
      ),
      rim,
    );
  }

  canvas.save();
  canvas.clipPath(shape);
  canvas.drawRect(rect, Paint()..color = arena.floor);
  final rand = math.Random(arena.index * 7919 + 17);
  switch (arena) {
    case Arena.dustyYard:
      _dirt(canvas, rect, scale, rand);
    case Arena.oilyTable:
      _table(canvas, center, rect, scale, rand);
    case Arena.turtleMarket:
      _paving(canvas, rect, scale, rand);
    case Arena.kubiForest:
      _forest(canvas, rect, scale, rand);
    case Arena.logicMarble:
      _marble(canvas, center, rect, scale, rand);
    case Arena.murimIce:
      _ice(canvas, center, rect, scale, rand);
  }
  // 가장자리 그늘: 장외가 가까워지는 것을 느끼게 한다.
  canvas.drawPath(
    shape,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale
      ..color = const Color(0x33000000),
  );
  canvas.restore();
}

Color _rimColor(Arena a) => switch (a) {
  Arena.dustyYard => const Color(0xFF7A5A34),
  Arena.oilyTable => const Color(0xFF4E2C16),
  Arena.turtleMarket => const Color(0xFF5C564E),
  Arena.kubiForest => const Color(0xFF4A3A22),
  Arena.logicMarble => const Color(0xFFB08A3E),
  Arena.murimIce => const Color(0xFF6F8FA8),
};

Offset _rp(Rect r, math.Random rand) => Offset(
  r.left + rand.nextDouble() * r.width,
  r.top + rand.nextDouble() * r.height,
);

/// 흙: 얼룩·자갈·발자국 금.
void _dirt(Canvas c, Rect r, double s, math.Random rand) {
  for (var i = 0; i < 40; i++) {
    c.drawCircle(
      _rp(r, rand),
      (1 + rand.nextDouble() * 2.5) * s,
      Paint()
        ..color = (rand.nextBool()
            ? const Color(0x10FFFFFF)
            : const Color(0x12000000))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.2 * s),
    );
  }
  for (var i = 0; i < 220; i++) {
    c.drawCircle(
      _rp(r, rand),
      (0.06 + rand.nextDouble() * 0.12) * s,
      Paint()..color = const Color(0x55402A14),
    );
  }
  for (var i = 0; i < 18; i++) {
    final p = _rp(r, rand);
    final rr = (0.25 + rand.nextDouble() * 0.35) * s;
    c.drawCircle(p, rr, Paint()..color = const Color(0xFF8D7A62));
    c.drawCircle(
      p.translate(-rr * 0.3, -rr * 0.3),
      rr * 0.4,
      Paint()..color = const Color(0x55FFFFFF),
    );
  }
  final crack = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.08 * s
    ..color = const Color(0x55402A14);
  for (var i = 0; i < 7; i++) {
    var p = _rp(r, rand);
    final path = Path()..moveTo(p.dx, p.dy);
    for (var k = 0; k < 4; k++) {
      p = p.translate(
        (rand.nextDouble() - 0.5) * 4 * s,
        (rand.nextDouble() - 0.5) * 4 * s,
      );
      path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path, crack);
  }
}

/// 원탁: 나무 결·판자 이음·기름 얼룩.
void _table(Canvas c, Offset o, Rect r, double s, math.Random rand) {
  final grain = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.1 * s;
  for (var i = 1; i < 30; i++) {
    grain.color = i.isEven ? const Color(0x33000000) : const Color(0x18FFFFFF);
    c.drawCircle(o, i * 0.75 * s + rand.nextDouble() * 0.3 * s, grain);
  }
  final seam = Paint()
    ..strokeWidth = 0.12 * s
    ..color = const Color(0x55301A0C);
  for (var k = -3; k <= 3; k++) {
    final x = o.dx + k * 6 * s;
    c.drawLine(Offset(x, r.top), Offset(x, r.bottom), seam);
  }
  for (var i = 0; i < 9; i++) {
    final p = _rp(r.deflate(4 * s), rand);
    final w = (2 + rand.nextDouble() * 4) * s;
    final oval = Rect.fromCenter(center: p, width: w, height: w * 0.6);
    c.drawOval(oval, Paint()..color = const Color(0x40F0C060));
    c.drawOval(
      Rect.fromCenter(
        center: p.translate(-w * 0.15, -w * 0.1),
        width: w * 0.35,
        height: w * 0.15,
      ),
      Paint()..color = const Color(0x66FFFFFF),
    );
  }
}

/// 장터 돌바닥: 엇갈려 깐 판석과 이끼 낀 줄눈.
void _paving(Canvas c, Rect r, double s, math.Random rand) {
  const rowH = 4.2;
  final joint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.22 * s
    ..color = const Color(0xFF5E5A44);
  var y = r.top;
  var row = 0;
  while (y < r.bottom) {
    var x = r.left - (row.isOdd ? 2.6 * s : 0);
    while (x < r.right) {
      final w = (4 + rand.nextDouble() * 3) * s;
      final stone = Rect.fromLTWH(x, y, w, rowH * s);
      final tone = 0x7A + rand.nextInt(0x24);
      c.drawRect(
        stone,
        Paint()..color = Color.fromARGB(255, tone, tone - 6, tone - 14),
      );
      c.drawRect(stone, joint);
      x += w;
    }
    y += rowH * s;
    row++;
  }
}

/// 숲길: 흙 위 낙엽과 잔가지.
void _forest(Canvas c, Rect r, double s, math.Random rand) {
  for (var i = 0; i < 30; i++) {
    c.drawCircle(
      _rp(r, rand),
      (2 + rand.nextDouble() * 5) * s,
      Paint()..color = const Color(0x1A2E4A1E),
    );
  }
  const leafColors = [
    Color(0xCC6E8A2E),
    Color(0xCC9A6A22),
    Color(0xCCB0471E),
    Color(0xCC4E6E26),
  ];
  for (var i = 0; i < 70; i++) {
    final p = _rp(r, rand);
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(rand.nextDouble() * math.pi);
    final l = (0.5 + rand.nextDouble() * 0.6) * s;
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: l * 2, height: l),
      Paint()..color = leafColors[rand.nextInt(leafColors.length)],
    );
    c.drawLine(
      Offset(-l, 0),
      Offset(l, 0),
      Paint()
        ..strokeWidth = 0.04 * s
        ..color = const Color(0x66302010),
    );
    c.restore();
  }
  final twig = Paint()
    ..strokeWidth = 0.14 * s
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xAA4A3218);
  for (var i = 0; i < 10; i++) {
    final p = _rp(r, rand);
    final a = rand.nextDouble() * math.pi;
    final l = (1.5 + rand.nextDouble() * 2) * s;
    c.drawLine(p, p.translate(math.cos(a) * l, math.sin(a) * l), twig);
  }
}

/// 대리석: 흰 바탕의 회색 결 + 금빛 기하 문양.
void _marble(Canvas c, Offset o, Rect r, double s, math.Random rand) {
  final vein = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.1 * s
    ..color = const Color(0x40707078);
  for (var i = 0; i < 12; i++) {
    final a = _rp(r, rand), b = _rp(r, rand);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(
        r.left + rand.nextDouble() * r.width,
        r.top + rand.nextDouble() * r.height,
        b.dx,
        b.dy,
      );
    c.drawPath(path, vein);
  }
  final gold = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.14 * s
    ..color = const Color(0x99B08A3E);
  for (final rad in [6.0, 12.0, 18.0]) {
    c.drawCircle(o, rad * s, gold);
  }
  final oct = Path();
  for (var k = 0; k < 8; k++) {
    final a = k * math.pi / 4 + math.pi / 8;
    final p = o + Offset(math.cos(a), math.sin(a)) * 15 * s;
    k == 0 ? oct.moveTo(p.dx, p.dy) : oct.lineTo(p.dx, p.dy);
  }
  oct.close();
  c.drawPath(oct, gold);
  for (var k = 0; k < 8; k++) {
    final a = k * math.pi / 4;
    c.drawLine(o, o + Offset(math.cos(a), math.sin(a)) * 18 * s, gold);
  }
}

/// 빙판: 푸른 결빙·금·서리 반짝임, 가장자리 불꽃.
void _ice(Canvas c, Offset o, Rect r, double s, math.Random rand) {
  c.drawRect(
    r,
    Paint()
      ..shader = Gradient.radial(o, r.width / 2, const [
        Color(0xFFE6F6FC),
        Color(0xFF9CCBE0),
      ]),
  );
  final crack = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.07 * s
    ..color = const Color(0x88FFFFFF);
  for (var i = 0; i < 9; i++) {
    var p = _rp(r, rand);
    final path = Path()..moveTo(p.dx, p.dy);
    for (var k = 0; k < 5; k++) {
      p = p.translate(
        (rand.nextDouble() - 0.5) * 6 * s,
        (rand.nextDouble() - 0.5) * 6 * s,
      );
      path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path, crack);
  }
  for (var i = 0; i < 60; i++) {
    c.drawCircle(
      _rp(r, rand),
      (0.05 + rand.nextDouble() * 0.1) * s,
      Paint()..color = const Color(0xCCFFFFFF),
    );
  }
  for (var k = 0; k < 4; k++) {
    final a = k * math.pi / 2 + math.pi / 4;
    final p = o + Offset(math.cos(a), math.sin(a)) * 19.5 * s;
    c.drawCircle(
      p,
      3 * s,
      Paint()
        ..shader = Gradient.radial(p, 3 * s, const [
          Color(0x88FF8A2A),
          Color(0x00FF8A2A),
        ]),
    );
  }
}
