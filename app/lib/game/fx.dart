import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart' as phys;
import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../progress/settings.dart';
import 'board_paint.dart';
import 'fx_colors.dart';
import 'match.dart';
import 'pets.dart';
import '../ui/theme.dart';

/// 부딪힌 빠르기(cm/s)에 따른 연출 단계.
///
/// 2026-10-13 형 「액션이 확실하게 전달되는」: 예전엔 60cm/s 부터만 「퍽!」·멈칫·번쩍이었는데, 보통 손
/// (손가락 500~700px/s)이 내는 빠르기가 42~58cm/s(설계서 §16.16 실측)라 대부분의 판에서 큰 연출이 안 나왔다.
enum ImpactTier {
  /// 살짝 닿음 — 작은 먼지만.
  light,

  /// 불꽃 줄기 · 작은 흔들림.
  mid,

  /// 「퍽!」 · 짧은 멈칫 · 번쩍 — 보통 손으로 정통으로 맞힌 한 방.
  strong,

  /// 「쾅!」 · 긴 멈칫 · 큰 흔들림 · 쏜 돌이면 느린 화면.
  huge;

  static ImpactTier of(double speed) => speed >= 75
      ? huge
      : speed >= 40
      ? strong
      : speed >= 12
      ? mid
      : light;
}

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
  final _streaks = <_Streak>[];
  final _glints = <_Ring>[];

  /// 판 밖으로 떨어지는 돌(그리기는 BoardGame — 돌 그림을 안다).
  final falls = <FallingStone>[];

  /// 타격 멈춤(히트스톱): 센 충돌 순간 아주 잠깐 거의 멈춘다(손맛 · 2026-10-11).
  double _stopLeft = 0;

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
    if (_stopLeft > 0) return 0.05;
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

  /// 줄무늬 불꽃: [at] 에서 [dir] 둘레(퍼짐 [spread] 라디안)로 [n] 줄.
  void _streak(
    Offset at,
    double dir,
    double spread,
    int n,
    double speed,
    Color c, {
    double len = 1.2,
  }) {
    for (var i = 0; i < n; i++) {
      final a = dir + (_rand.nextDouble() - 0.5) * 2 * spread;
      final sp = speed * (0.5 + _rand.nextDouble() * 0.8);
      _streaks.add(
        _Streak(
          at,
          Offset(math.cos(a), math.sin(a)) * sp,
          0.22 + _rand.nextDouble() * 0.18,
          len * (0.6 + _rand.nextDouble() * 0.8),
          c,
        ),
      );
    }
  }

  /// 한 수를 쏜 순간.
  void onShot(Match m, phys.Stone s) {
    final at0 = Offset(s.position.x, s.position.y);
    if (m.lastVolley && m.config.pet != null) {
      _text(
        at0.translate(0, -3.2),
        m.config.pet == PetKind.dragon ? '금룡 합공!!' : '백호 합공!',
        const Color(0xFFFFB04A),
        size: 34,
      );
      _rings.add(_Ring(at0, 0.5, 8, 0.5, const Color(0xFFFFB04A)));
      _shake = math.max(_shake, 8);
      Sound.play('tech_clone');
    } else if (m.lastPetAssist) {
      _text(
        at0.translate(0, -3.2),
        '날쌘돌 함께 튕기기!',
        const Color(0xFFFFD86A),
        size: 24,
      );
      Sound.play('whoosh');
    }
    final at = Offset(s.position.x, s.position.y);
    // 떠나는 돌 뒤로 바람 줄기·흙먼지(얼마나 세게 쳤는지 보이게).
    final v = s.velocity;
    final sp = v.length;
    if (sp > 1) {
      final back = math.atan2(-v.y, -v.x);
      _streak(at, back, 0.5, (6 + sp / 8).round(), sp * 0.35, Colors.white70);
      _rings.add(_Ring(at, 0.4, 1.5 + sp / 40, 0.25, const Color(0xFFE8D9B0)));
      Buzz.impact(sp / 120);
    }
    if (m.lastCritical) {
      Sound.play('critical');
      _text(at.translate(0, -2.5), '회심!', innerColor, size: 34);
      _rings.add(_Ring(at, 0.5, 4, 0.35, innerColor));
      _burst(at, innerColor, 24, 20);
      _flash = 0.35;
      _flashColor = innerColor;
      Buzz.burst();
    }
    if (m.lastMode != StrikeMode.plain) Buzz.burst();
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
        Sound.play('inner');
        if (martial == phys.Technique.taiji) Sound.technique(martial);
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
        Sound.play('ultimate');
        _glow[s.id] = (ultimateColor, 4);
        _rings.add(_Ring(at, 1, 10, 0.6, ultimateColor));
        _burst(at, ultimateColor, 40, 30);
        _text(at.translate(0, -2.5), '어기어석!', ultimateColor, size: 34);
        if (m.lastWing > 0) {
          _text(
            at.translate(0, 0.5),
            '동행 ${m.lastWing}!',
            ultimateColor,
            size: 26,
          );
        }
        _flash = 0.5;
        _flashColor = ultimateColor;
        steerLeft = m.config.steerSeconds;
    }
  }

  /// 대사 고르기(연출만 — 판 결과와 무관하니 씨앗 없이).
  final _quipRand = math.Random();
  String _pick(List<String> xs) => xs[_quipRand.nextInt(xs.length)];

  /// 목인항 한 수: 연타가 길수록 글자·흔들림·소리가 커진다. 5·10·20·30 연타는 큰 장면.
  void _trainingHit(Match m) {
    final n = m.trainStreak;
    if (n == 0) {
      _text(const Offset(0, -4), '빗나감…', const Color(0xFFB0A8A0), size: 20);
      return;
    }
    final k = math.min(n, 12);
    const tiers = [
      Color(0xFFFFFFFF),
      Color(0xFFFFE08A),
      Color(0xFFFFB04A),
      Color(0xFFFF6B4A),
      Color(0xFFE85AFF),
    ];
    final c = tiers[math.min(4, (n - 1) ~/ 3)];
    final big = n % 10 == 0 || n == 5;
    _text(
      const Offset(0, -4),
      n == 1 ? '1타!' : '$n연타${big ? '!!' : '!'}',
      c,
      size: 24 + k * 2.0 + (big ? 10 : 0),
    );
    _shake = math.max(_shake, 3 + k * 0.9 + (big ? 8 : 0));
    _rings.add(_Ring(const Offset(0, -6), 0.5, 4 + k * 0.5, 0.4, c));
    if (big) {
      _flash = math.max(_flash, 0.4);
      _flashColor = c;
      _burst(const Offset(0, -6), c, 30 + k * 2, 22);
      _slow(0.4, 0.35);
      Sound.play(n >= 10 ? 'finisher' : 'jingle_reward', 0.8);
    } else if (n >= 3) {
      Sound.play('clash_beat', math.min(1, 0.4 + k * 0.05));
    }
    if (n == 3) Sound.play('star');
  }

  /// 떨어지는 상대 돌의 비명(2026-10-20 형 「묘한 중독성이랑 은근히 웃기도 재미가」).
  static const fallLines = [
    '으악~',
    '엄마야!',
    '다음 생엔 바둑알로…',
    '살려줘~',
    '날 잊지 마…',
    '히익!',
    '먼저 갈게~',
    '이건 반칙이야!',
  ];

  /// 회전 기둥에 맞고 엇나갈 때.
  static const pillarLines = ['팽그르르!', '엇나갔다!', '기둥 맞고 휘청~', '어디로 튈지 몰라!'];

  /// 담장에 맞고 되튈 때.
  static const fenceLines = ['쿵! 되튕김', '담장 반동!', '벽 타고 돌아온다!'];

  /// 내가 헛손질했을 때 상대의 놀림.
  static const missLines = [
    '헛손질~',
    '바람만 갈랐구나',
    '어디를 보는 게냐',
    '허공 베기 달인',
    '눈 감고 쳤느냐?',
  ];

  /// 한 수가 끝났을 때: 뽀록·아슬아슬 → 연타 → 대사 → 일타쌍피(설계서 §16.7).
  void onTurnEnd(Match m) {
    if (m.config.training) {
      _trainingHit(m);
      return;
    }
    final mine = m.lastShooter == 0;
    var line = -4.6;
    void say(String s, Color c, {double size = 24}) {
      _text(Offset(0, line), s, c, size: size);
      line += 2.4;
    }

    const lucky = Color(0xFFFFD86A), sore = Color(0xFFFF6B6B);
    for (final e in m.luckEvents) {
      final at = Offset(e.x, e.y);
      final byMe = e.team == m.lastShooter;
      if (e.tipped) {
        final d = at.distance;
        falls.add(
          FallingStone(
            at,
            d > 0 ? at / d * 14 : const Offset(0, 14),
            e.team,
            e.stone.material,
            e.stone.shape,
          ),
        );
        Sound.play('out_thud');
        if (!byMe) {
          say(mine ? '뽀록! 기우뚱 떨어졌다' : '뽀록이라니… 열받네!', mine ? lucky : sore);
        } else {
          say(mine ? '아이고, 미끄러졌다!' : '자멸이로다~', mine ? sore : lucky);
        }
        _shake = math.max(_shake, 6);
      } else if (!byMe) {
        say(mine ? '버텼다?! 얄밉다…' : '휴~ 구사일생!', mine ? sore : lucky);
      }
    }
    if (m.lastFluke > 0 && !m.luckEvents.any((e) => e.tipped)) {
      say(mine ? '어부지리! 뽀록이다' : '어부지리라니…', mine ? lucky : sore);
    }
    if (mine && m.combo >= 2) {
      say(
        '연타 ×${m.combo}! 엽전 +${Match.comboCoin * m.combo}',
        innerColor,
        size: 28,
      );
      Sound.play('coin');
    }
    if (m.lastKnocked > 0 && m.lastKnocked < 2) {
      say(_pick(fallLines), mine ? Colors.white : sore, size: 22);
    } else if (mine && m.lastMissed && m.config.mode == MatchMode.vsAi) {
      say(_pick(missLines), sore, size: 22);
    }
    if (m.lastKnocked < 2) return;
    final c = mine ? innerColor : const Color(0xFFFF6B6B);
    final name = switch (m.lastKnocked) {
      2 => '일타쌍피!',
      3 => '일타삼피!',
      _ => '일타다피!',
    };
    _text(const Offset(0, -3), name, c, size: 40);
    Sound.play('clash');
    if (mine && m.config.mode == MatchMode.vsAi) {
      _text(
        const Offset(0, 1.5),
        '엽전 +${Match.multiKnockCoin * m.lastKnocked}',
        c,
        size: 22,
      );
    }
    _rings.add(_Ring(Offset.zero, 2, 16, 0.7, c));
    _flash = math.max(_flash, 0.4);
    _flashColor = c;
    _shake = math.max(_shake, 10);
  }

  /// 물리 한 스텝 뒤: 충돌·무공·장외를 보고 연출을 붙인다.
  /// 이번 수에 이미 보여 준 박살 수(연쇄 글자를 한 번씩).
  int _shatterShown = 0;

  void onStep(Match m, Set<int> wasOut) {
    final t = m.table;
    final shooterId = t.shooter?.id ?? -1;
    if (t.shattered.length < _shatterShown) _shatterShown = 0;
    for (final b in t.shattered.skip(_shatterShown)) {
      if (b.chain > 0) {
        _text(
          Offset(b.x, b.y - 3.2),
          b.chain == 1 ? '연쇄 박살!' : '연쇄 ${b.chain + 1}단 박살!!',
          const Color(0xFFFF9A3C),
          size: 34,
        );
        _slow(0.35, 0.5);
      }
    }
    _shatterShown = t.shattered.length;
    var sounds = 0;
    for (final i in t.impacts) {
      // 재질별 충돌음: 쏜 돌이 맞힌 돌(아니면 먼저 적힌 돌)의 재질. 한 걸음에 둘까지.
      if (sounds < 2) {
        final id = i.a == shooterId ? i.b : i.a;
        for (final st in t.stones) {
          if (st.id == id) {
            Sound.hit(st.material, i.speed);
            sounds++;
            break;
          }
        }
      }
      final at = Offset(i.x, i.y);
      final tier = ImpactTier.of(i.speed);
      final huge = tier == ImpactTier.huge;
      final strong = huge || tier == ImpactTier.strong;
      final mid = strong || tier == ImpactTier.mid;
      final withShooter = i.a == shooterId || i.b == shooterId;
      // 손맛: 부딪힌 빠르기만큼 떨린다(같은 순간 여러 번이면 한 번).
      Buzz.impact(i.speed / 100);
      if (mid) {
        // 부딪힌 자리에서 사방으로 튀는 불꽃 줄기.
        _streak(
          at,
          _rand.nextDouble() * math.pi * 2,
          math.pi,
          strong ? 14 : 6,
          i.speed * 0.5,
          const Color(0xFFFFE9A8),
          len: strong ? 1.6 : 1,
        );
      }
      if (strong) {
        _glints.add(_Ring(at, 0, 2.2 + i.speed / 60, 0.22, Colors.white));
        // 센 충돌은 아주 잠깐 멈춘다(히트스톱).
        _stopLeft = math.max(_stopLeft, huge ? 0.09 : 0.06);
        if (withShooter || huge) {
          _text(
            at.translate(0, -1.8),
            huge ? '쾅!' : '퍽!',
            const Color(0xFFFFF2C0),
            size: huge ? 34 : 28,
          );
        }
      }
      _burst(
        at,
        const Color(0xFFFFF2C0),
        strong ? 26 : (mid ? 12 : 4),
        i.speed * 0.4,
        size: strong ? 0.35 : 0.22,
      );
      if (strong) {
        _shake = math.max(_shake, huge ? 12 : 8);
        _flash = math.max(_flash, huge ? 0.3 : 0.2);
        _flashColor = Colors.white;
        _rings.add(_Ring(at, 0.3, huge ? 4.2 : 3.2, 0.3, Colors.white));
        // 환영 교전(설계서 §4): 쏜 돌의 아주 센 정면 충돌은 잠깐 느린 화면.
        if (withShooter && huge) _slow(0.3, 0.35);
      } else if (mid) {
        _shake = math.max(_shake, 4);
      }
    }
    for (final e in t.events) {
      final at = Offset(e.x, e.y);
      switch (e.fx) {
        case phys.TechniqueFx.innerImpact:
          Sound.play('inner', 0.8);
          _rings.add(_Ring(at, 0.5, 5, 0.45, innerColor));
          _burst(at, innerColor, 30, 40);
          _streak(at, 0, math.pi, 16, 40, innerColor, len: 2);
          _shake = math.max(_shake, 12);
          _stopLeft = math.max(_stopLeft, 0.08);
          Buzz.burst();
        case phys.TechniqueFx.swordQi:
          Sound.technique(phys.Technique.swordQi);
          final c = techniqueColor(phys.Technique.swordQi);
          if (e.stoneId != null) _glow[e.stoneId!] = (c, 1.2);
          _text(at.translate(0, -2), '검기', c);
        case phys.TechniqueFx.stomp:
          Sound.technique(phys.Technique.stomp);
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
          Sound.technique(phys.Technique.clone);
          final c = techniqueColor(phys.Technique.clone);
          _burst(at, c, 36, 25);
          if (e.stoneId != null) _glow[e.stoneId!] = (c, 3);
          _text(at.translate(0, -2), '분신', c);
        case phys.TechniqueFx.absorb:
          Sound.technique(phys.Technique.absorb);
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
          Sound.play('terrain_gong');
          const c = Color(0xFFF2CF7A);
          _rings.add(_Ring(at, 1.5, phys.TerrainConstants.gongRadius, 0.6, c));
          _text(at.translate(0, -2), '경종!', c);
          _shake = math.max(_shake, 8);
          Buzz.heartbeat();
        case phys.TerrainFx.swallow:
          Sound.play('tech_absorb', 0.7);
          const c = Color(0xFFB07CFF);
          _rings.add(_Ring(at, phys.TerrainConstants.holeRadius, 0.3, 0.5, c));
          _text(at.translate(0, -2), '흡입!', c);
        case phys.TerrainFx.mine:
          Sound.play('terrain_mine');
          const c = Color(0xFFFF7A2E);
          _burst(at, c, 60, 60, size: 0.45);
          _streak(at, 0, math.pi, 20, 60, c, len: 2.2);
          Buzz.burst();
          _rings.add(_Ring(at, 0.5, phys.TerrainConstants.mineRadius, 0.5, c));
          _text(at.translate(0, -2), '폭발!', c, size: 32);
          _shake = math.max(_shake, 20);
          _flash = math.max(_flash, 0.5);
          _flashColor = c;
        case phys.TerrainFx.frostStop:
          Sound.play('hit_ice', 0.6);
          const c = Color(0xFFBFEFFF);
          _burst(at, c, 16, 10);
          _text(at.translate(0, -2), '결빙', c);
        case phys.TerrainFx.bamboo:
          Sound.play('hit_wood');
          const c = Color(0xFF5FE08A);
          _rings.add(_Ring(at, 0.3, 2.5, 0.3, c));
          _text(at.translate(0, -2), '청죽!', c, size: 22);
        case phys.TerrainFx.pillar:
          Sound.play('hit_hyeoncheol');
          const c = Color(0xFFFFC857);
          _rings.add(_Ring(at, 0.4, 3, 0.35, c));
          _burst(at, c, 12, 14);
          _shake = math.max(_shake, 6);
          _text(at.translate(0, -2), _pick(pillarLines), c, size: 22);
        case phys.TerrainFx.fence:
          Sound.play('hit_wood');
          const c = Color(0xFFE8C48A);
          _rings.add(_Ring(at, 0.3, 2.2, 0.3, c));
          _shake = math.max(_shake, 4);
          _text(at.translate(0, -2), _pick(fenceLines), c, size: 20);
      }
    }
    for (final (name, x, y) in m.artEvents) {
      const c = Color(0xFFD06BFF);
      final at = Offset(x, y);
      _text(at.translate(0, -2.5), name, c, size: 28);
      _rings.add(_Ring(at, 0.5, 6, 0.5, c));
      _burst(at, c, 30, 30);
      _shake = math.max(_shake, 8);
      Sound.play('tech_absorb', 0.8);
    }
    var crowd = false;
    for (final s in t.stones) {
      if (s.out && !wasOut.contains(s.id)) {
        Sound.play('out_thud');
        if (!crowd) Sound.play('out_crowd', 0.7);
        crowd = true;
        final at = Offset(s.position.x, s.position.y);
        final dir = s.velocity.length > 1
            ? Offset(s.velocity.x, s.velocity.y)
            : Offset(at.dx, at.dy);
        final unit = dir.distance == 0
            ? const Offset(0, 1)
            : dir / dir.distance;
        // 2026-10-14 형 「크리티컬 … 상대 돌이 떨어지는 게 아니라 박살나면서 분해되는 그래픽과 액션」:
        // 회심·어기어석으로 친 수에 상대 돌이 장외되면 떨어지는 대신 조각으로 부서진다.
        final shooter = t.shooter;
        final smash =
            shooter != null &&
            s.team <= 1 &&
            s.team != shooter.team &&
            (m.lastCritical || m.lastMode == StrikeMode.ultimate);
        if (smash) {
          _shatter(at, unit, s);
          continue;
        }
        _text(at, '장외!', const Color(0xFFFF6B5B), size: 24);
        _burst(at, const Color(0xFFC9A57A), 20, 15, size: 0.35);
        _shake = math.max(_shake, 5);
        // 판 밖으로 떨어지며 작아지는 돌(장외가 눈에 보이게).
        falls.add(
          FallingStone(
            at,
            unit * math.max(12, s.velocity.length * 0.6),
            s.team,
            s.material,
            s.shape,
          ),
        );
        Buzz.thud();
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

  /// 박살나는 돌의 조각(그리기는 [paintOver]).
  final shards = <Shard>[];

  /// 돌이 박살나 조각 8개로 흩어진다(「박살!」 · 큰 흔들림 · 번쩍 · 쿵-쿵).
  void _shatter(Offset at, Offset unit, phys.Stone s) {
    final face = stoneBase(s.team);
    final edge = materialColors[s.material] ?? Colors.white;
    for (var k = 0; k < 8; k++) {
      final a = k * math.pi / 4 + _rand.nextDouble() * 0.5;
      final out = Offset(math.cos(a), math.sin(a));
      shards.add(
        Shard(
          at + out * 0.4,
          out * (10 + _rand.nextDouble() * 18) + unit * 14,
          _rand.nextDouble() * math.pi,
          (_rand.nextDouble() - 0.5) * 18,
          0.45 + _rand.nextDouble() * 0.35,
          face,
          edge,
        ),
      );
    }
    _text(at.translate(0, -2.2), '박살!', const Color(0xFFFFB04A), size: 38);
    _rings.add(_Ring(at, 0.3, 5, 0.4, Colors.white));
    _burst(at, edge, 30, 25, size: 0.3);
    _streak(at, 0, math.pi, 18, 40, const Color(0xFFFFE9A8), len: 1.8);
    _shake = math.max(_shake, 16);
    _flash = math.max(_flash, 0.45);
    _flashColor = Colors.white;
    _stopLeft = math.max(_stopLeft, 0.1);
    Sound.play('critical');
    Sound.play('hit_hyeoncheol');
    Buzz.burst();
  }

  /// 실제 시간으로 연출을 진행한다.
  void update(double dt) {
    clock += dt;
    for (final s in shards) {
      s.pos += s.vel * dt;
      s.vel *= 1 - 1.8 * dt;
      s.rot += s.spin * dt;
      s.life -= dt;
    }
    shards.removeWhere((s) => s.life <= 0);
    if (_stopLeft > 0) _stopLeft -= dt;
    for (final st in _streaks) {
      st.pos += st.vel * dt;
      st.vel *= 1 - 3 * dt;
      st.life -= dt;
    }
    _streaks.removeWhere((st) => st.life <= 0);
    for (final g in _glints) {
      g.t += dt;
    }
    _glints.removeWhere((g) => g.t >= g.dur);
    for (final f in falls) {
      f.pos += f.vel * dt;
      f.t += dt;
    }
    falls.removeWhere((f) => f.t >= FallingStone.life);
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
    _texts.removeWhere((t) {
      final done = t.t >= 1.1;
      if (done) t.painter?.dispose();
      return done;
    });
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
      // 빛나는 꼬리: 흐림은 꼬리 전체에 한 번만(선마다 흐리던 것 — 돌 하나에 13번 · 2026-10-14 점검).
      if (glow != null) {
        final start = at(list[0].dx, list[0].dy);
        final path = Path()..moveTo(start.dx, start.dy);
        for (var i = 1; i < list.length; i++) {
          final p = at(list[i].dx, list[i].dy);
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = base.withValues(alpha: 0.35)
            ..strokeWidth = r * 1.2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      for (var i = 1; i < list.length; i++) {
        final k = i / list.length;
        canvas.drawLine(
          at(list[i - 1].dx, list[i - 1].dy),
          at(list[i].dx, list[i].dy),
          Paint()
            ..color = base.withValues(alpha: (glow == null ? 0.25 : 0.6) * k)
            ..strokeWidth = r * (glow == null ? 0.8 : 1.4) * k
            ..strokeCap = StrokeCap.round,
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
    for (final s in shards) {
      // 세모 조각: 돌 겉빛 + 재질 테두리, 사라지며 옅어진다.
      final a = (s.life / Shard.lifeTime).clamp(0.0, 1.0);
      final c = at(s.pos.dx, s.pos.dy);
      final r = s.size * scale;
      final path = Path();
      for (var k = 0; k < 3; k++) {
        final ang = s.rot + k * 2.1;
        final rr = r * const [1.0, 0.7, 0.85][k];
        final p = c + Offset(math.cos(ang), math.sin(ang)) * rr;
        k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = s.face.withValues(alpha: a));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, scale * 0.12)
          ..color = s.edge.withValues(alpha: a),
      );
    }
    for (final r in _rings) {
      final k = r.t / r.dur;
      final rad =
          (r.r0 + (r.r1 - r.r0) * Curves.easeOut.transform(k.clamp(0.0, 1.0))) *
          scale;
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
      // 매 장 글자 배치를 다시 하던 것(120Hz 에 글자 수만큼) → 크기는 그림판을 키워서, 투명도는 10단계가
      // 바뀔 때만 다시 배치(2026-10-14 점검).
      final step = ((1 - k * k).clamp(0.0, 1.0) * 10).round();
      if (t.painter == null || t.step != step) {
        t.painter?.dispose();
        t.step = step;
        t.painter = TextPainter(
          text: TextSpan(
            text: t.s,
            style: TextStyle(
              fontFamily: titleFont,
              fontFamilyFallback: fallbackFonts,
              fontSize: t.size,
              color: t.color.withValues(alpha: step / 10),
              shadows: const [Shadow(blurRadius: 6, color: Color(0xCC000000))],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
      }
      final tp = t.painter!;
      canvas
        ..save()
        ..translate(pos.dx, pos.dy)
        ..scale(pop);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
    for (final st in _streaks) {
      final a = (st.life / 0.4).clamp(0.0, 1.0);
      final v = st.vel.distance;
      if (v < 0.01) continue;
      final tail = st.pos - st.vel / v * st.len;
      canvas.drawLine(
        at(tail.dx, tail.dy),
        at(st.pos.dx, st.pos.dy),
        Paint()
          ..color = st.color.withValues(alpha: a)
          ..strokeWidth = math.max(1.2, scale * 0.12)
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final g in _glints) {
      // 번쩍: 네 갈래 빛.
      final k = g.t / g.dur;
      final c = at(g.at.dx, g.at.dy);
      final len = g.r1 * scale * Curves.easeOut.transform(k.clamp(0.0, 1.0));
      final p = Paint()
        ..color = Colors.white.withValues(alpha: (1 - k) * 0.95)
        ..strokeWidth = math.max(2, scale * 0.25 * (1 - k))
        ..strokeCap = StrokeCap.round;
      for (final a in const [0.0, math.pi / 2]) {
        final d = Offset(math.cos(a + 0.4), math.sin(a + 0.4)) * len;
        canvas.drawLine(c - d, c + d, p);
      }
    }
  }

  /// 화면에 붙어 있는 것(번쩍임·느린 화면 테두리) — 카메라와 상관없이 화면 전체에.
  void paintScreen(Canvas canvas, Size size) {
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

/// 판 밖으로 떨어지는 돌 하나(장외 연출).
class FallingStone {
  FallingStone(this.pos, this.vel, this.team, this.material, this.shape);
  static const double life = 0.5;
  Offset pos;
  final Offset vel;
  final int team;
  final phys.StoneMaterial material;
  final phys.StoneShape shape;
  double t = 0;
}

/// 박살난 돌 조각 하나.
class Shard {
  Shard(
    this.pos,
    this.vel,
    this.rot,
    this.spin,
    this.size,
    this.face,
    this.edge,
  );
  static const double lifeTime = 0.9;
  Offset pos;
  Offset vel;
  double rot;
  final double spin;
  final double size;
  final Color face;
  final Color edge;
  double life = lifeTime;
}

class _Streak {
  _Streak(this.pos, this.vel, this.life, this.len, this.color);
  Offset pos;
  Offset vel;
  double life;
  final double len;
  final Color color;
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

  /// 한 번 배치한 글자(투명도 단계가 바뀔 때만 다시) · 그 단계.
  TextPainter? painter;
  int step = -1;
}
