import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart' as phys;
import 'package:flutter/material.dart';

import 'fx_colors.dart';
import 'match.dart';

/// 판 위 연출: 날아가는 돌 잔상, 충돌 불꽃·화면 흔들림·잠깐 느려지기, 장외, 회심·내공·무공·스킬 효과.
///
/// 판정에는 손대지 않는다(물리 결과를 보고 그리기만 한다). 좌표는 판 좌표(cm).
class BattleFx {
  final _rand = math.Random(7);
  final _parts = <_Part>[];
  final _rings = <_Ring>[];
  final _texts = <_Text>[];
  final _trails = <int, List<Offset>>{};
  final _glow = <int, (Color, double)>{};

  double _shake = 0;
  double _flash = 0;
  Color _flashColor = Colors.white;
  double _slowLeft = 0;
  double _slowScale = 1;

  /// 흐른 시간(초) — 비·바람 그림이 움직이게.
  double clock = 0;

  /// 어기어석으로 꺾을 수 있는 남은 시간(실제 초). 이 동안 화면이 아주 느리다.
  double steerLeft = 0;

  /// 물리 시간 배수(1 = 보통, 작을수록 느린 화면).
  double get timeScale {
    if (steerLeft > 0) return 0.2;
    return _slowLeft > 0 ? _slowScale : 1;
  }

  /// 화면 흔들림(화소).
  Offset shakeOffset() => _shake <= 0.1
      ? Offset.zero
      : Offset(
          (_rand.nextDouble() - 0.5) * 2 * _shake,
          (_rand.nextDouble() - 0.5) * 2 * _shake,
        );

  void _slow(double scale, double seconds) {
    if (_slowLeft > 0 && _slowScale <= scale) {
      _slowLeft = math.max(_slowLeft, seconds);
      return;
    }
    _slowScale = scale;
    _slowLeft = seconds;
  }

  void _text(Offset at, String s, Color c, {double size = 26}) =>
      _texts.add(_Text(at, s, c, size));

  void _burst(Offset at, Color c, int n, double speed, {double size = 0.25}) {
    for (var i = 0; i < n; i++) {
      final a = _rand.nextDouble() * math.pi * 2;
      final sp = speed * (0.3 + _rand.nextDouble());
      _parts.add(
        _Part(
          at,
          Offset(math.cos(a), math.sin(a)) * sp,
          0.3 + _rand.nextDouble() * 0.4,
          size * (0.5 + _rand.nextDouble()),
          c,
        ),
      );
    }
  }

  /// 한 수를 쏜 순간.
  void onShot(Match m, phys.Stone s) {
    final at = Offset(s.position.x, s.position.y);
    if (m.lastCritical) {
      _text(at.translate(0, -2.5), '회심!', innerColor, size: 34);
      _rings.add(_Ring(at, 0.5, 4, 0.35, innerColor));
      _burst(at, innerColor, 24, 20);
      _flash = 0.35;
      _flashColor = innerColor;
    }
    switch (m.lastMode) {
      case StrikeMode.plain:
        break;
      case StrikeMode.inner:
      case StrikeMode.absorb:
        final martial = s.team == 0
            ? m.config.martial
            : m.config.opponentMartial;
        final c = m.lastMode == StrikeMode.absorb
            ? techniqueColor(phys.Technique.absorb)
            : techniqueColor(martial);
        _glow[s.id] = (c, 2.5);
        _rings.add(_Ring(at, 0.5, 5, 0.4, c));
        _burst(at, c, 30, 25);
        _text(
          at.translate(0, -2.5),
          m.lastMode == StrikeMode.absorb ? '흡성탄지' : '내공 · ${martial.label}',
          c,
        );
        _shake = 6;
      case StrikeMode.ultimate:
        _glow[s.id] = (ultimateColor, 4);
        _rings.add(_Ring(at, 1, 10, 0.6, ultimateColor));
        _burst(at, ultimateColor, 40, 30);
        _text(at.translate(0, -2.5), '어기어석!', ultimateColor, size: 34);
        _flash = 0.5;
        _flashColor = ultimateColor;
        steerLeft = m.config.steerSeconds;
    }
  }

  /// 물리 한 스텝 뒤: 충돌·무공·장외를 보고 연출을 붙인다.
  void onStep(Match m, Set<int> wasOut) {
    final t = m.table;
    final shooterId = t.shooter?.id ?? -1;
    for (final i in t.impacts) {
      final at = Offset(i.x, i.y);
      final strong = i.speed >= 60;
      final mid = i.speed >= 20;
      final withShooter = i.a == shooterId || i.b == shooterId;
      _burst(
        at,
        const Color(0xFFFFF2C0),
        strong ? 26 : (mid ? 12 : 4),
        i.speed * 0.4,
        size: strong ? 0.35 : 0.22,
      );
      if (strong) {
        _shake = math.max(_shake, 10);
        _flash = math.max(_flash, 0.25);
        _flashColor = Colors.white;
        _rings.add(_Ring(at, 0.3, 3.5, 0.3, Colors.white));
        // 환영 교전(설계서 §4): 쏜 돌의 센 정면 충돌은 잠깐 느린 화면.
        if (withShooter) _slow(0.3, 0.35);
      } else if (mid) {
        _shake = math.max(_shake, 4);
      }
    }
    for (final e in t.events) {
      final at = Offset(e.x, e.y);
      switch (e.fx) {
        case phys.TechniqueFx.innerImpact:
          _rings.add(_Ring(at, 0.5, 5, 0.45, innerColor));
          _burst(at, innerColor, 30, 40);
          _shake = math.max(_shake, 12);
        case phys.TechniqueFx.swordQi:
          final c = techniqueColor(phys.Technique.swordQi);
          if (e.stoneId != null) _glow[e.stoneId!] = (c, 1.2);
          _text(at.translate(0, -2), '검기', c);
        case phys.TechniqueFx.stomp:
          final c = techniqueColor(phys.Technique.stomp);
          _rings.add(
            _Ring(at, 0.5, phys.TechniqueConstants.stompRadius, 0.5, c),
          );
          _rings.add(
            _Ring(at, 0.2, phys.TechniqueConstants.stompRadius * 1.4, 0.7, c),
          );
          _burst(at, c, 40, 30, size: 0.3);
          _text(at.translate(0, -2), '진각', c);
          _shake = math.max(_shake, 16);
        case phys.TechniqueFx.clone:
          final c = techniqueColor(phys.Technique.clone);
          _burst(at, c, 36, 25);
          if (e.stoneId != null) _glow[e.stoneId!] = (c, 3);
          _text(at.translate(0, -2), '분신', c);
        case phys.TechniqueFx.absorb:
          final c = techniqueColor(phys.Technique.absorb);
          const r = phys.TechniqueConstants.absorbRadius;
          for (var k = 0; k < 40; k++) {
            final a = _rand.nextDouble() * math.pi * 2;
            final from = at + Offset(math.cos(a), math.sin(a)) * r;
            _parts.add(_Part(from, (at - from) * 2, 0.5, 0.25, c));
          }
          _rings.add(_Ring(at, r, 0.5, 0.5, c));
          _text(at.translate(0, -2), '흡성탄지', c);
      }
    }
    for (final e in t.terrainEvents) {
      final at = Offset(e.x, e.y);
      switch (e.fx) {
        case phys.TerrainFx.gong:
          const c = Color(0xFFF2CF7A);
          _rings.add(_Ring(at, 1.5, phys.TerrainConstants.gongRadius, 0.6, c));
          _text(at.translate(0, -2), '경종!', c);
          _shake = math.max(_shake, 8);
        case phys.TerrainFx.swallow:
          const c = Color(0xFFB07CFF);
          _rings.add(_Ring(at, phys.TerrainConstants.holeRadius, 0.3, 0.5, c));
          _text(at.translate(0, -2), '흡입!', c);
        case phys.TerrainFx.mine:
          const c = Color(0xFFFF7A2E);
          _burst(at, c, 60, 60, size: 0.45);
          _rings.add(_Ring(at, 0.5, phys.TerrainConstants.mineRadius, 0.5, c));
          _text(at.translate(0, -2), '폭발!', c, size: 32);
          _shake = math.max(_shake, 20);
          _flash = math.max(_flash, 0.5);
          _flashColor = c;
        case phys.TerrainFx.frostStop:
          const c = Color(0xFFBFEFFF);
          _burst(at, c, 16, 10);
          _text(at.translate(0, -2), '결빙', c);
        case phys.TerrainFx.bamboo:
          const c = Color(0xFF5FE08A);
          _rings.add(_Ring(at, 0.3, 2.5, 0.3, c));
          _text(at.translate(0, -2), '청죽!', c, size: 22);
      }
    }
    for (final s in t.stones) {
      if (s.out && !wasOut.contains(s.id)) {
        final at = Offset(s.position.x, s.position.y);
        _text(at, '장외!', const Color(0xFFFF6B5B), size: 24);
        _burst(at, const Color(0xFFC9A57A), 20, 15, size: 0.35);
        _shake = math.max(_shake, 5);
      }
    }
    // 잔상: 움직이는 돌의 지나온 자리.
    for (final s in t.stones) {
      final list = _trails.putIfAbsent(s.id, () => []);
      if (s.out || s.velocity.length < 3) {
        if (list.isNotEmpty) list.removeAt(0);
        continue;
      }
      list.add(Offset(s.position.x, s.position.y));
      if (list.length > 14) list.removeAt(0);
    }
  }

  /// 실제 시간으로 연출을 진행한다.
  void update(double dt) {
    clock += dt;
    for (final p in _parts) {
      p.pos += p.vel * dt;
      p.vel *= 1 - 2.5 * dt;
      p.life -= dt;
    }
    _parts.removeWhere((p) => p.life <= 0);
    for (final r in _rings) {
      r.t += dt;
    }
    _rings.removeWhere((r) => r.t >= r.dur);
    for (final t in _texts) {
      t.t += dt;
    }
    _texts.removeWhere((t) => t.t >= 1.1);
    _glow.updateAll((k, v) => (v.$1, v.$2 - dt));
    _glow.removeWhere((k, v) => v.$2 <= 0);
    _shake *= math.pow(0.02, dt).toDouble();
    _flash = math.max(0, _flash - dt * 1.5);
    if (_slowLeft > 0) _slowLeft -= dt;
    if (steerLeft > 0) steerLeft = math.max(0, steerLeft - dt);
  }

  /// 돌 아래에 그리는 것(잔상·빛).
  void paintUnder(
    Canvas canvas,
    Match m,
    Offset Function(double x, double y) at,
    double scale,
  ) {
    final r = phys.PhysicsConstants.stoneRadius * scale;
    _trails.forEach((id, list) {
      if (list.length < 2 || id >= m.table.stones.length) return;
      final glow = _glow[id];
      final mine = m.table.stones[id].team == 0;
      final custom = mine ? trailColor(m.config.myTrail) : null;
      final base = glow?.$1 ?? custom ?? const Color(0xFFFFFFFF);
      for (var i = 1; i < list.length; i++) {
        final k = i / list.length;
        canvas.drawLine(
          at(list[i - 1].dx, list[i - 1].dy),
          at(list[i].dx, list[i].dy),
          Paint()
            ..color = base.withValues(alpha: (glow == null ? 0.25 : 0.6) * k)
            ..strokeWidth = r * (glow == null ? 0.8 : 1.4) * k
            ..strokeCap = StrokeCap.round
            ..maskFilter = glow == null
                ? null
                : const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    });
    _glow.forEach((id, g) {
      if (id >= m.table.stones.length) return;
      final s = m.table.stones[id];
      if (s.out) return;
      final c = at(s.position.x, s.position.y).translate(0, -s.z * scale);
      final rr = r * 2.2;
      canvas.drawCircle(
        c,
        rr,
        Paint()
          ..shader = RadialGradient(
            colors: [
              g.$1.withValues(alpha: 0.7 * math.min(1, g.$2)),
              g.$1.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: rr)),
      );
    });
  }

  /// 돌 위에 그리는 것(불꽃·고리·글자·번쩍임·느린 화면 테두리).
  void paintOver(
    Canvas canvas,
    Size size,
    Offset Function(double x, double y) at,
    double scale,
  ) {
    for (final r in _rings) {
      final k = r.t / r.dur;
      final rad = (r.r0 + (r.r1 - r.r0) * Curves.easeOut.transform(k)) * scale;
      canvas.drawCircle(
        at(r.at.dx, r.at.dy),
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, scale * 0.35 * (1 - k))
          ..color = r.color.withValues(alpha: (1 - k) * 0.9),
      );
    }
    for (final p in _parts) {
      final a = (p.life / 0.7).clamp(0.0, 1.0);
      canvas.drawCircle(
        at(p.pos.dx, p.pos.dy),
        p.size * scale * (0.5 + a * 0.5),
        Paint()..color = p.color.withValues(alpha: a),
      );
    }
    for (final t in _texts) {
      final k = t.t / 1.1;
      final pos = at(t.at.dx, t.at.dy).translate(0, -k * 30);
      final pop = k < 0.15 ? 0.6 + k / 0.15 * 0.6 : 1.2 - (k - 0.15) * 0.25;
      final style = TextStyle(
        fontSize: t.size * pop,
        fontWeight: FontWeight.w900,
        color: t.color.withValues(alpha: (1 - k * k).clamp(0.0, 1.0)),
        shadows: const [Shadow(blurRadius: 6, color: Color(0xCC000000))],
      );
      final tp = TextPainter(
        text: TextSpan(text: t.s, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
    if (_flash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = _flashColor.withValues(alpha: _flash * 0.35),
      );
    }
    if (timeScale < 1) {
      // 느린 화면: 가장자리를 어둡게.
      final rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            radius: 0.9,
            colors: [
              Colors.transparent,
              (steerLeft > 0 ? ultimateColor : Colors.black).withValues(
                alpha: 0.45,
              ),
            ],
            stops: const [0.6, 1],
          ).createShader(rect),
      );
    }
  }
}

class _Part {
  _Part(this.pos, this.vel, this.life, this.size, this.color);
  Offset pos;
  Offset vel;
  double life;
  final double size;
  final Color color;
}

class _Ring {
  _Ring(this.at, this.r0, this.r1, this.dur, this.color);
  final Offset at;
  final double r0;
  final double r1;
  final double dur;
  final Color color;
  double t = 0;
}

class _Text {
  _Text(this.at, this.s, this.color, this.size);
  final Offset at;
  final String s;
  final Color color;
  final double size;
  double t = 0;
}
