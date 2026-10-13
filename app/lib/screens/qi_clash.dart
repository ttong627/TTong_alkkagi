import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../game/fx_colors.dart';
import '../game/match.dart';
import '../progress/settings.dart';
import '../ui/kit.dart';

/// 내공 겨루기(설계서 §4 · §16.16): 두 돌이 정면으로 부딪히면 판이 멈추고, 준비 장면 뒤에 3초 연타.
///
/// 2026-10-11 형 「맞추고 나서 내공 대결할 때 준비와 배경 화면 효과음도 조금 더 긴장감 있게 — 대비 없이 바로 시작하니까 이상해」:
/// ① 대치(1.2초): 화면이 붉게 가라앉고 위아래 검은 띠, 두 고수가 미끄러져 들어오며 두 기운이 가운데서 맞붙는다(심장 박동·진동)
/// ② 셋 · 둘 · 하나(북) → 「시작!」(징) — 이때부터만 연타를 센다(먼저 두드리면 「아직!」)
/// ③ 3초 연타: 두 기운이 줄다리기하듯 밀고 밀린다 · 두드릴 때마다 「탁」·떨림·물결
/// ④ 결과(쾅 + 징 / 둔한 북) 뒤 판이 다시 흐른다.
class QiClashOverlay extends StatefulWidget {
  const QiClashOverlay({
    super.key,
    required this.opponent,
    required this.aiTaps,
    required this.onDone,
    this.me,
    this.foe,
    this.fast = false,
  });
  final String opponent;
  final int aiTaps;
  final void Function(int mine, int theirs) onDone;

  /// 두 사람 그림 이름(없으면 그림 없이).
  final String? me;
  final String? foe;

  /// 시험용: 준비 장면을 줄인다.
  final bool fast;

  /// 준비 장면 시각(초): 대치 → 셋 → 둘 → 하나 → 시작.
  static const double faceOff = 1.2;
  static const double beat = 0.55;
  static double get readyTotal => faceOff + beat * 3;

  @override
  State<QiClashOverlay> createState() => _QiClashOverlayState();
}

enum _Phase { faceOff, count, tap, result }

class _QiClashOverlayState extends State<QiClashOverlay>
    with TickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(days: 1),
  )..forward();
  late final _tap = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (QiClash.seconds * 1000).round()),
  );
  final _timers = <Timer>[];
  final _ripples = <(Offset, double)>[];
  final _attackMe = ValueNotifier<int>(0);
  final _attackFoe = ValueNotifier<int>(0);
  final _rand = math.Random();

  _Phase _phase = _Phase.faceOff;
  int _count = 3;
  int _taps = 0;
  double _kick = 0;
  double _lastBeatAt = -1;

  /// 북이 울렸다 — 다음 그림 때 그 시각을 잡는다(타이머 시각은 그림 시계와 어긋날 수 있다).
  bool _beatPending = false;
  String? _early;
  String? _result;
  double _swing = 0;

  /// 겨루기 동안 bgm_clash 를 틀고, 닫힐 때 원래 곡으로 되돌린다.
  final String? _prevTrack = Sound.current;

  double get _t => _clock.lastElapsedDuration == null
      ? 0
      : _clock.lastElapsedDuration!.inMicroseconds / 1e6;

  void _at(double sec, VoidCallback f) {
    final s = widget.fast ? sec * 0.1 : sec;
    _timers.add(
      Timer(Duration(milliseconds: (s * 1000).round()), () {
        if (mounted) f();
      }),
    );
  }

  @override
  void initState() {
    super.initState();
    Sound.track('bgm_clash');
    Sound.play('clash_ready');
    Buzz.heartbeat();
    _at(0.6, Buzz.heartbeat);
    for (var i = 0; i < 3; i++) {
      _at(QiClashOverlay.faceOff + i * QiClashOverlay.beat, () {
        setState(() {
          _phase = _Phase.count;
          _count = 3 - i;
          _beatPending = true;
        });
        Sound.play('clash_beat');
        Buzz.heartbeat();
      });
    }
    _at(QiClashOverlay.readyTotal, _start);
    _tap.addStatusListener((st) {
      if (st == AnimationStatus.completed) _finish();
    });
  }

  void _start() {
    setState(() {
      _phase = _Phase.tap;
      _early = null;
      _beatPending = true;
    });
    Sound.play('go');
    Buzz.heavy();
    _tap.forward();
  }

  void _finish() {
    final d = _swing = QiClash.swing(_taps, widget.aiTaps);
    final cap = (QiClash.maxRate * QiClash.seconds).round();
    setState(() {
      _phase = _Phase.result;
      _beatPending = true;
      _result = _taps > cap
          ? '무효 — 초당 ${QiClash.maxRate}회를 넘겼다'
          : (d > 0
                ? '이겼다! 반발 +${(d * 100).round()}%'
                : (d < 0 ? '밀렸다… 반발 ${(d * 100).round()}%' : '팽팽하다'));
    });
    if (d > 0) {
      Sound.play('clash_win');
      _attackMe.value++;
      Buzz.burst();
    } else {
      Sound.play(d < 0 ? 'clash_lose' : 'clash_beat');
      if (d < 0) _attackFoe.value++;
      Buzz.thud();
    }
    _at(1.1, () => widget.onDone(_taps, widget.aiTaps));
  }

  void _onTap(TapDownDetails d) {
    if (_phase == _Phase.tap && _tap.isAnimating) {
      setState(() {
        _taps++;
        _kick = 1;
        _ripples.add((d.localPosition, _t));
      });
      Sound.play('clash_tap', 0.55);
      Buzz.impact(0.25);
      if (_taps % 6 == 0) _attackMe.value++;
    } else if (_phase != _Phase.result) {
      setState(() => _early = '아직! 「시작」에 두드려라');
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    Sound.track(_prevTrack);
    _clock.dispose();
    _tap.dispose();
    _attackMe.dispose();
    _attackFoe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('qi-clash'),
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTap,
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final t = _t;
          if (_beatPending) {
            _beatPending = false;
            _lastBeatAt = t;
          }
          final size = MediaQuery.sizeOf(context);
          final enter = Curves.easeOutBack.transform(
            (t / (widget.fast ? 0.1 : 0.55)).clamp(0.0, 1.0),
          );
          // AI 연타는 막대가 고르게 차오른다.
          final ai = _phase.index >= _Phase.tap.index
              ? (widget.aiTaps * _tap.value).round()
              : 0;
          // 줄다리기: 많이 두드린 쪽이 가운데를 밀어낸다.
          final tug = _phase == _Phase.result
              ? _swing / QiClash.maxSwing
              : (_taps + ai == 0
                    ? 0.0
                    : (_taps - ai) / math.max(8, _taps + ai));
          _kick = math.max(0, _kick - 0.08);
          _ripples.removeWhere((r) => t - r.$2 > 0.45);
          final sinceBeat = _lastBeatAt < 0 ? 9.0 : t - _lastBeatAt;
          final cap = (QiClash.maxRate * QiClash.seconds).toDouble();
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ClashPainter(
                    t: t,
                    enter: enter,
                    tug: tug.clamp(-1.0, 1.0),
                    pulse: math.exp(-sinceBeat * 5),
                    kick: _kick,
                    ripples: [for (final r in _ripples) (r.$1, t - r.$2)],
                    rand: _rand,
                    resolved: _phase == _Phase.result,
                  ),
                ),
              ),
              if (widget.foe != null)
                Positioned(
                  top: 70,
                  left: -size.width * 0.7 * (1 - enter),
                  child: Opacity(
                    opacity: 0.9,
                    child: CharacterSprite(
                      id: widget.foe!,
                      height: size.height * 0.26,
                      attack: _attackFoe,
                    ),
                  ),
                ),
              if (widget.me != null)
                Positioned(
                  // 아래 연타 막대 위에 선다(막대를 가리지 않게).
                  bottom: size.height * 0.11 + 150,
                  right: -size.width * 0.7 * (1 - enter),
                  child: Opacity(
                    opacity: 0.9,
                    child: CharacterSprite(
                      id: widget.me!,
                      height: size.height * 0.22,
                      flip: true,
                      attack: _attackMe,
                    ),
                  ),
                ),
              // 제목.
              Positioned(
                top: size.height * 0.11,
                left: 0,
                right: 0,
                child: Transform.scale(
                  scale: 2.2 - 1.2 * enter,
                  child: const Center(
                    child: OutlinedText(
                      '내공 겨루기',
                      size: 46,
                      title: true,
                      color: Color(0xFFFFE08A),
                    ),
                  ),
                ),
              ),
              // 가운데 큰 글: 셋·둘·하나 / 시작! / 결과.
              Center(
                child: switch (_phase) {
                  _Phase.faceOff => const SizedBox.shrink(),
                  _Phase.count => _Pop(
                    key: ValueKey(_count),
                    child: OutlinedText(
                      ['', '하나', '둘', '셋'][_count],
                      size: 92,
                      title: true,
                      color: Colors.white,
                    ),
                  ),
                  _Phase.tap =>
                    sinceBeat < 0.6
                        ? const _Pop(
                            key: ValueKey('go'),
                            child: OutlinedText(
                              '시작!',
                              size: 84,
                              title: true,
                              color: Color(0xFFFFE08A),
                            ),
                          )
                        : const SizedBox.shrink(),
                  _Phase.result => _Pop(
                    key: const ValueKey('result'),
                    child: OutlinedText(
                      _result ?? '',
                      size: 34,
                      title: true,
                      color: _swing > 0
                          ? const Color(0xFFFFE08A)
                          : const Color(0xFFB0B8C8),
                    ),
                  ),
                },
              ),
              // 아래: 안내 · 두 사람 연타 막대.
              Positioned(
                left: 20,
                right: 20,
                bottom: size.height * 0.11,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedText(
                      _early ??
                          switch (_phase) {
                            _Phase.faceOff ||
                            _Phase.count => '「시작」에 맞춰 화면을 마구 두드려라!',
                            _Phase.tap =>
                              '두드려라! ${(QiClash.seconds * (1 - _tap.value)).toStringAsFixed(1)}초',
                            _Phase.result => '',
                          },
                      size: 20,
                      color: _early != null
                          ? const Color(0xFFFF8A7A)
                          : Colors.white,
                    ),
                    const SizedBox(height: 10),
                    _Bar(who: '나', n: _taps, cap: cap, color: innerColor),
                    const SizedBox(height: 6),
                    _Bar(
                      who: widget.opponent,
                      n: ai,
                      cap: cap,
                      color: const Color(0xFFFF6B6B),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '많이 두드린 쪽 돌이 더 세게 튕겨 낸다(반발 ±${(QiClash.maxSwing * 100).round()}%)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 큰 글이 「쾅」 하고 박힌다.
class _Pop extends StatelessWidget {
  const _Pop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 260),
    builder: (_, k, c) => Transform.scale(
      scale: 1.9 - 0.9 * Curves.easeOutBack.transform(k),
      child: Opacity(opacity: k.clamp(0.0, 1.0), child: c),
    ),
    child: child,
  );
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.who,
    required this.n,
    required this.cap,
    required this.color,
  });
  final String who;
  final int n;
  final double cap;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 84, child: OutlinedText(who, size: 16)),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: LinearProgressIndicator(
            value: (n / cap).clamp(0.0, 1.0),
            minHeight: 16,
            color: color,
            backgroundColor: Colors.white12,
          ),
        ),
      ),
      SizedBox(width: 40, child: OutlinedText('$n', size: 16)),
    ],
  );
}

/// 배경: 붉게 가라앉은 화면 · 도는 집중선 · 위아래 검은 띠 · 가운데서 맞붙는 두 기운(번개).
class _ClashPainter extends CustomPainter {
  _ClashPainter({
    required this.t,
    required this.enter,
    required this.tug,
    required this.pulse,
    required this.kick,
    required this.ripples,
    required this.rand,
    required this.resolved,
  });
  final double t;
  final double enter;
  final double tug;
  final double pulse;
  final double kick;
  final List<(Offset, double)> ripples;
  final math.Random rand;
  final bool resolved;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final full = Offset.zero & size;
    // 붉게 가라앉은 바탕(북이 울릴 때 조금 밝아진다).
    canvas.drawRect(
      full,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(
              const Color(0xFF5A1020),
              const Color(0xFF9A2030),
              pulse,
            )!.withValues(alpha: 0.9 * enter.clamp(0, 1)),
            const Color(0xF2060208),
          ],
          stops: const [0, 1],
          radius: 0.85,
        ).createShader(full),
    );
    // 집중선: 가운데로 모이며 천천히 돈다.
    final lines = Paint()..strokeWidth = 2;
    final rays = 48;
    for (var i = 0; i < rays; i++) {
      final a = i / rays * math.pi * 2 + t * 0.15;
      final inner =
          size.shortestSide * (0.28 + 0.05 * math.sin(i * 7.1 + t * 3));
      final outer = size.longestSide;
      lines.color = Colors.white.withValues(alpha: 0.05 + 0.1 * pulse);
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * inner,
        c + Offset(math.cos(a), math.sin(a)) * outer,
        lines,
      );
    }
    // 두 기운: 왼쪽 위(상대) · 오른쪽 아래(나)에서 가운데로. 맞붙는 자리는 연타로 밀린다.
    final meet = c + Offset(size.width * 0.28 * -tug, size.height * 0.12 * tug);
    final from1 = Offset(-20, size.height * 0.3);
    final from2 = Offset(size.width + 20, size.height * 0.7);
    void beam(Offset a, Color col) {
      final p = Path()..moveTo(a.dx, a.dy);
      const n = 14;
      for (var i = 1; i <= n; i++) {
        final k = i / n;
        final pt = Offset.lerp(a, meet, k)!;
        final j = (rand.nextDouble() - 0.5) * 18 * math.sin(k * math.pi);
        p.lineTo(pt.dx + j, pt.dy + j);
      }
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14 + 8 * kick
          ..color = col.withValues(alpha: 0.35 * enter.clamp(0, 1))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withValues(alpha: 0.85 * enter.clamp(0, 1)),
      );
    }

    if (!resolved) {
      beam(from1, const Color(0xFFFF6B6B));
      beam(from2, innerColor);
    }
    // 맞붙는 자리: 커졌다 작아지는 빛 + 튀는 불꽃.
    final r =
        (resolved ? 120.0 : 34.0 + 16 * pulse + 14 * kick) * enter.clamp(0, 1);
    canvas.drawCircle(
      meet,
      r * 1.8,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: meet, radius: r * 1.8)),
    );
    final spark = Paint()..strokeWidth = 2;
    for (var i = 0; i < 16; i++) {
      final a = rand.nextDouble() * math.pi * 2;
      final l = r * (0.8 + rand.nextDouble() * 1.4);
      spark.color = Color.lerp(
        innerColor,
        const Color(0xFFFFE08A),
        rand.nextDouble(),
      )!;
      canvas.drawLine(meet, meet + Offset(math.cos(a), math.sin(a)) * l, spark);
    }
    // 두드린 자리 물결.
    for (final (p, age) in ripples) {
      final k = (age / 0.45).clamp(0.0, 1.0);
      canvas.drawCircle(
        p,
        20 + 70 * k,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - k)
          ..color = innerColor.withValues(alpha: 1 - k),
      );
    }
    // 위아래 검은 띠(영화처럼).
    final band = size.height * 0.08 * enter.clamp(0, 1);
    final bp = Paint()..color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, band), bp);
    canvas.drawRect(Rect.fromLTWH(0, size.height - band, size.width, band), bp);
  }

  @override
  bool shouldRepaint(covariant _ClashPainter old) => true;
}
