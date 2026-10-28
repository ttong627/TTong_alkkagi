import 'dart:math' as math;
import 'dart:ui';

import 'package:alkkagi_physics/alkkagi_physics.dart';

import '../ui/art.dart';

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
    half: 21,
  ),
  oilyTable(
    '통통 객잔 원탁',
    chapter: '2장 · 기름진 난장',
    feel: '기름이 튀어 잘 미끄러짐 · 둥근 판',
    floorFactor: 0.7,
    boundary: Boundary.circle,
    half: 23,
  ),
  turtleMarket(
    '거북 장터 돌바닥',
    chapter: '3장 · 거북 장터 난투',
    feel: '보통',
    floorFactor: 1.0,
    boundary: Boundary.square,
    half: 25,
  ),
  kubiForest(
    '쿠비 산채 숲길',
    chapter: '4장 · 야성의 숲',
    feel: '낙엽에 조금 걸림',
    floorFactor: 1.15,
    boundary: Boundary.square,
    half: 22,
  ),
  logicMarble(
    '로직 학당 대리석',
    chapter: '5장 · 철벽의 진인',
    feel: '매끄러움',
    floorFactor: 0.85,
    boundary: Boundary.square,
    half: 18,
  ),
  murimIce(
    '무림맹 본단 빙판',
    chapter: '6장 · 천하제일 탄지대회',
    feel: '얼어 있어 아주 잘 미끄러짐 · 둥근 판',
    floorFactor: 0.6,
    boundary: Boundary.circle,
    half: 25,
  ),

  // 2026-10-28 형 「새로운 이야기도 6개에서 10개로 · 경기장 이미지 … 좀더 다양하게」.
  sandCanyon(
    '열사 협곡 모래판',
    chapter: '7장 · 열사의 협곡',
    feel: '모래라 빨리 멈춤 · 유사에 빠지면 더 느려짐',
    floorFactor: 1.3,
    boundary: Boundary.square,
    half: 23,
  ),
  pirateDeck(
    '흑룡선 갑판',
    chapter: '8장 · 흑룡 해적선',
    feel: '젖은 갑판이라 잘 미끄러짐 · 좁은 판',
    floorFactor: 0.75,
    boundary: Boundary.square,
    half: 19,
  ),
  lavaCave(
    '화염산 용암굴',
    chapter: '9장 · 화염산',
    feel: '뜨거운 현무암 · 용암 구멍은 장외',
    floorFactor: 1.05,
    boundary: Boundary.circle,
    half: 23,
  ),
  heavenTemple(
    '천상 탄신전',
    chapter: '10장 · 천상 탄신전',
    feel: '구름 옥바닥이라 아주 매끄러움 · 큰 둥근 판',
    floorFactor: 0.7,
    boundary: Boundary.circle,
    half: 26,
  );

  const Arena(
    this.label, {
    required this.chapter,
    required this.feel,
    required this.floorFactor,
    required this.boundary,
    required this.half,
  });

  final String label;
  final String chapter;
  final String feel;
  final double floorFactor;
  final Boundary boundary;

  /// 판 가운데에서 가장자리까지(cm) — 2026-10-14 형 「경기장 크기를 다양하게」. 예전엔 모두 21.
  /// 작은 판(학당 18)은 장외가 가깝고, 큰 판(장터·빙판 25)은 멀다.
  final double half;

  /// 판 크기 이름.
  String get sizeLabel => half <= 19
      ? '작은 판'
      : half >= 24
      ? '큰 판'
      : '보통 판';

  /// 판 둘레 밖(장외 쪽) 색.
  Color get outside => switch (this) {
    Arena.dustyYard => const Color(0xFF3A2C1E),
    Arena.oilyTable => const Color(0xFF2A1A12),
    Arena.turtleMarket => const Color(0xFF2E2A26),
    Arena.kubiForest => const Color(0xFF1E2A1C),
    Arena.logicMarble => const Color(0xFF22222A),
    Arena.murimIce => const Color(0xFF141E2C),
    Arena.sandCanyon => const Color(0xFF3E2414),
    Arena.pirateDeck => const Color(0xFF0E1A26),
    Arena.lavaCave => const Color(0xFF1E0C08),
    Arena.heavenTemple => const Color(0xFF2A3350),
  };

  /// 돌 아래 바닥 대표 색(가까이 보기 화면 배경).
  Color get floor => switch (this) {
    Arena.dustyYard => const Color(0xFFB8925F),
    Arena.oilyTable => const Color(0xFF8A5530),
    Arena.turtleMarket => const Color(0xFF8F877C),
    Arena.kubiForest => const Color(0xFF5E5A33),
    Arena.logicMarble => const Color(0xFFE6E2DA),
    Arena.murimIce => const Color(0xFFB9DCEB),
    Arena.sandCanyon => const Color(0xFFC9934F),
    Arena.pirateDeck => const Color(0xFF6B4A2E),
    Arena.lavaCave => const Color(0xFF3A3230),
    Arena.heavenTemple => const Color(0xFFE8EEE6),
  };
}

/// 판 바닥을 그린다. [toScreen] 은 판 좌표(cm) → 화면 좌표, [scale] 은 1cm 의 화면 길이.
void paintArena(
  Canvas canvas,
  Arena arena,
  Offset Function(double x, double y) toScreen,
  double scale, {
  double h = PhysicsConstants.halfBoard,
}) {
  final center = toScreen(0, 0);
  final rect = Rect.fromPoints(toScreen(-h, -h), toScreen(h, h));
  final round = arena.boundary == Boundary.circle;
  final shape = Path();
  if (round) {
    shape.addOval(Rect.fromCircle(center: center, radius: h * scale));
  } else {
    shape.addRect(rect);
  }

  // 판 아래 그림자(배경 위에 떠 있는 판).
  final shadowRect = rect.inflate(1.4 * scale).shift(Offset(0, 0.9 * scale));
  final shadow = Paint()
    ..color = const Color(0xAA000000)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.2 * scale);
  if (round) {
    canvas.drawCircle(shadowRect.center, shadowRect.width / 2, shadow);
  } else {
    canvas.drawRRect(
      RRect.fromRectAndRadius(shadowRect, Radius.circular(scale)),
      shadow,
    );
  }
  // 테두리(장외 경계 바로 바깥): 결 있는 두툼한 틀.
  final rimC = _rimColor(arena);
  final rim = Paint()
    ..shader = Gradient.linear(
      rect.topLeft,
      rect.bottomRight,
      [
        Color.lerp(rimC, const Color(0xFFFFFFFF), 0.25)!,
        rimC,
        Color.lerp(rimC, const Color(0xFF000000), 0.35)!,
      ],
      const [0, 0.5, 1],
    );
  if (round) {
    canvas.drawCircle(center, (h + 0.9) * scale, rim);
  } else {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(0.9 * scale),
        Radius.circular(0.6 * scale),
      ),
      rim,
    );
  }

  canvas.save();
  canvas.clipPath(shape);
  canvas.drawRect(rect, Paint()..color = arena.floor);
  final rand = math.Random(arena.index * 7919 + 17);
  final img = Art.floorImage(arena);
  if (img != null) {
    // 그린 바닥 그림(tool/art). 그 위에 장마다 특별한 무늬만 더한다.
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      rect,
      Paint()..filterQuality = FilterQuality.medium,
    );
    if (arena == Arena.logicMarble) _marbleGold(canvas, center, scale);
    if (arena == Arena.murimIce) _iceFire(canvas, center, scale);
  } else {
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
      // 새 경기장은 그림이 없을 때 결 있는 흙·판자·현무암·옥 무늬로 대신 그린다.
      case Arena.sandCanyon || Arena.lavaCave:
        _dirt(canvas, rect, scale, rand);
      case Arena.pirateDeck:
        _paving(canvas, rect, scale, rand);
      case Arena.heavenTemple:
        _marble(canvas, center, rect, scale, rand);
    }
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
  Arena.sandCanyon => const Color(0xFF8A5A2C),
  Arena.pirateDeck => const Color(0xFF3E2A18),
  Arena.lavaCave => const Color(0xFF5A1E10),
  Arena.heavenTemple => const Color(0xFFC9A24A),
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
  _marbleGold(c, o, s);
}

/// 학당 바닥의 금빛 기하 문양.
void _marbleGold(Canvas c, Offset o, double s) {
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
  _iceFire(c, o, s);
}

/// 빙판 가장자리 네 귀퉁이 불꽃.
void _iceFire(Canvas c, Offset o, double s) {
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

/// 대전장마다 기본으로 놓는 담장(판 바깥 가장자리)과 장애물(판 가운데 띠).
///
/// 2026-10-20 형 「판의 여기 저기에 장애물도 있고 튕겨서 다시 맞는 경우의 수와 경기장 바깥의 벽이나 담에 맞아서
/// 다시 들어와서 공격할 수 있는 부분도 … 모두 단순 장외 처리만 하지말고」. 담장이 없는 칸으로만 장외가 된다.
/// 돌이 처음 서는 줄(±12cm 안팎)을 비켜 장애물은 가운데 띠에만 둔다.
List<Feature> arenaLayout(Arena a, {bool obstacles = true}) {
  final h = a.half;
  const t = TerrainConstants.fenceHalfThickness,
      l = TerrainConstants.fenceHalfLength;
  final out = <Feature>[];
  // 네모 판 한 변(왼쪽 −1 · 오른쪽 +1)에 y 구간 [from, to] 를 막는 담장.
  void side(int sx, double from, double to) {
    for (var y = from + l; y <= to - l + 0.01; y += 2 * l) {
      out.add(Feature(FeatureKind.fence, sx * (h + t), y, angle: math.pi / 2));
    }
  }

  // 위(−1)·아래(+1) 변에 x 구간을 막는 담장.
  void edge(int sy, double from, double to) {
    for (var x = from + l; x <= to - l + 0.01; x += 2 * l) {
      out.add(Feature(FeatureKind.fence, x, sy * (h + t)));
    }
  }

  // 둥근 판: 각도 [deg] 쪽 가장자리에 접하는 담장 [n] 토막.
  void arc(double deg, int n) {
    final r = h + t;
    final step = 2 * l / r;
    for (var k = 0; k < n; k++) {
      final a = deg * math.pi / 180 + (k - (n - 1) / 2) * step;
      out.add(
        Feature(
          FeatureKind.fence,
          math.cos(a) * r,
          math.sin(a) * r,
          angle: a + math.pi / 2,
        ),
      );
    }
  }

  switch (a) {
    case Arena.dustyYard:
      // 마을 공터: 양옆 울타리, 가운데만 트였다.
      side(-1, -h, -5);
      side(-1, 5, h);
      side(1, -h, -5);
      side(1, 5, h);
      if (obstacles) {
        out.add(Feature(FeatureKind.rock, -h * 0.45, 0));
        out.add(Feature(FeatureKind.rock, h * 0.45, 0));
        // 가운데 천천히 도는 네모 기둥.
        out.add(const Feature(FeatureKind.pillar, 0, 0, sides: 4, spin: 0.9));
      }
    case Arena.oilyTable:
      // 객잔 원탁: 비스듬한 네 귀퉁이에 난간.
      for (final d in const [45.0, 135.0, 225.0, 315.0]) {
        arc(d, 2);
      }
      if (obstacles) {
        out.add(Feature(FeatureKind.rock, -h * 0.35, 0));
        out.add(Feature(FeatureKind.rock, h * 0.35, 0));
        // 객잔: 빙글빙글 빠른 세모 기둥.
        out.add(const Feature(FeatureKind.pillar, 0, 0, sides: 3, spin: -2.4));
      }
    case Arena.turtleMarket:
      // 장터 골목: 양옆이 막힌 담벼락 — 벽을 타고 들어오는 수가 많다.
      side(-1, -h, h);
      side(1, -h, h);
      if (obstacles) {
        // 장터: 좌우로 오가는 육각 기둥.
        out.add(
          const Feature(
            FeatureKind.pillar,
            0,
            0,
            sides: 6,
            spin: 0.6,
            swing: 8,
            swingRate: 1.4,
          ),
        );
        out.add(Feature(FeatureKind.rock, -h * 0.5, -2));
        out.add(Feature(FeatureKind.rock, h * 0.5, 2));
      }
    case Arena.kubiForest:
      // 숲길: 왼쪽은 바위 벽, 가운데 쓰러진 나뭇가지 둘.
      side(-1, -h, h);
      if (obstacles) {
        out.add(Feature(FeatureKind.branch, -h * 0.35, -1.5, angle: 0.4));
        out.add(Feature(FeatureKind.branch, h * 0.4, 1.5, angle: -0.5));
        // 숲: 비스듬히 오가는 오각 기둥.
        out.add(
          const Feature(
            FeatureKind.pillar,
            0,
            0,
            sides: 5,
            spin: 1.2,
            swing: 4,
            swingAngle: 0.8,
            swingRate: 1.1,
          ),
        );
      }
    case Arena.logicMarble:
      // 학당: 네 모서리 기둥(모서리 쪽만 막힘).
      side(-1, -h, -h + 2 * l);
      side(-1, h - 2 * l, h);
      side(1, -h, -h + 2 * l);
      side(1, h - 2 * l, h);
      edge(-1, -h, -h + 2 * l);
      edge(-1, h - 2 * l, h);
      edge(1, -h, -h + 2 * l);
      edge(1, h - 2 * l, h);
      if (obstacles) {
        out.add(Feature(FeatureKind.bamboo, 0, 0));
        // 학당: 서로 반대로 도는 작은 세모 기둥 둘.
        out.add(Feature(FeatureKind.pillar, -h * 0.5, 0, sides: 3, spin: 1.6));
        out.add(Feature(FeatureKind.pillar, h * 0.5, 0, sides: 3, spin: -1.6));
      }
    case Arena.murimIce:
      // 빙판: 좌우 얼음 벽 조금 · 가운데 경종.
      arc(0, 3);
      arc(180, 3);
      if (obstacles) {
        out.add(Feature(FeatureKind.gong, 0, -h * 0.25));
        // 빙판: 좌우로 크게 미끄러지는 팔각 기둥.
        out.add(
          const Feature(
            FeatureKind.pillar,
            0,
            2,
            sides: 8,
            spin: 0.4,
            swing: 10,
            swingRate: 0.9,
          ),
        );
      }
    case Arena.sandCanyon:
      // 협곡: 위아래 가장자리 일부가 바위 벽 · 유사 둘 · 가운데 좌우로 오가는 오각 기둥.
      edge(-1, -h, -6);
      edge(-1, 6, h);
      edge(1, -h, -6);
      edge(1, 6, h);
      if (obstacles) {
        out.add(Feature(FeatureKind.quicksand, -h * 0.42, 0));
        out.add(Feature(FeatureKind.quicksand, h * 0.42, 0));
        out.add(
          const Feature(
            FeatureKind.pillar,
            0,
            0,
            sides: 5,
            spin: 1.0,
            swing: 5,
            swingRate: 1.2,
          ),
        );
      }
    case Arena.pirateDeck:
      // 갑판: 양옆 뱃전 난간이 막혀 있다 · 술통 셋 · 돛대(느리게 도는 팔각 기둥).
      side(-1, -h, h);
      side(1, -h, h);
      if (obstacles) {
        out.add(Feature(FeatureKind.barrel, -h * 0.5, -1.5));
        out.add(Feature(FeatureKind.barrel, h * 0.5, 1.5));
        out.add(const Feature(FeatureKind.pillar, 0, 0, sides: 8, spin: 0.5));
      }
    case Arena.lavaCave:
      // 용암굴: 위아래에 현무암 벽 · 용암 구멍 둘 · 가운데 도는 육각 기둥.
      arc(90, 3);
      arc(270, 3);
      if (obstacles) {
        out.add(Feature(FeatureKind.lavaPit, -h * 0.45, 0));
        out.add(Feature(FeatureKind.lavaPit, h * 0.45, 0));
        out.add(const Feature(FeatureKind.pillar, 0, 0, sides: 6, spin: 1.3));
      }
    case Arena.heavenTemple:
      // 탄신전: 좌우 구름 난간 조금 · 구름 쿠션 둘 · 가운데 소용돌이 · 소용돌이를 가로질러 오가는 네모 기둥.
      arc(0, 2);
      arc(180, 2);
      if (obstacles) {
        out.add(Feature(FeatureKind.cloud, -h * 0.45, -2));
        out.add(Feature(FeatureKind.cloud, h * 0.45, 2));
        out.add(const Feature(FeatureKind.whirlpool, 0, 0));
        out.add(
          const Feature(
            FeatureKind.pillar,
            0,
            0,
            sides: 4,
            spin: -1.5,
            swing: 7,
            swingRate: 0.8,
          ),
        );
      }
  }
  return out;
}
