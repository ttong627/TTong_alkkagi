import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../progress/settings.dart';
import '../progress/store.dart';
import 'art.dart';
import 'theme.dart';

/// 화면 부품 모음: 배경·단추·아이콘 타일·재화·패널·움직이는 캐릭터.
/// 글을 읽지 않아도 그림과 움직임으로 알아보게 한다.

/// 배경 그림: 천천히 다가왔다 멀어지고(살아 있는 느낌), 위에 떠다니는 꽃잎·불티.
class SceneBackground extends StatefulWidget {
  const SceneBackground({
    super.key,
    required this.asset,
    required this.child,
    this.dim = 0.0,
    this.motes = Motes.petals,
  });

  final String asset;
  final Widget child;

  /// 0~1: 글이 많은 화면은 배경을 어둡게.
  final double dim;
  final Motes motes;

  @override
  State<SceneBackground> createState() => _SceneBackgroundState();
}

enum Motes { none, petals, embers, snow, fireflies }

class _SceneBackgroundState extends State<SceneBackground>
    with SingleTickerProviderStateMixin {
  /// 한 바퀴 96초(앞뒤로 숨 쉬는 배경 두 번 = 48초씩). 떠다니는 알갱이는 이 한 바퀴 안에서
  /// 정수 번 돌아 끊김 없이 이어진다. DateTime.now() 는 쓰지 않는다(그리는 중에 시계를 읽지 않음).
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 96),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Palette.ink),
        // 그림은 한 번만 래스터라이즈하고, 천천히 커졌다 작아지는 것은 변환 레이어만 바꾼다.
        AnimatedBuilder(
          animation: _c,
          builder: (_, child) {
            final f = (_c.value * 2) % 1;
            final k = Curves.easeInOut.transform(1 - (2 * f - 1).abs());
            return Transform.scale(
              scale: 1.04 + 0.06 * k,
              alignment: Alignment(-0.3 + 0.6 * k, -0.2),
              child: child,
            );
          },
          child: RepaintBoundary(
            child: Image.asset(
              widget.asset,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
        if (widget.dim > 0)
          ColoredBox(color: Colors.black.withValues(alpha: widget.dim)),
        if (widget.motes != Motes.none)
          IgnorePointer(
            child: RepaintBoundary(
              // 위젯을 다시 짓지 않고 그림판만 매 프레임 다시 그린다.
              child: CustomPaint(
                painter: _MotesPainter(
                  widget.motes,
                  _Mote.of(widget.motes),
                  _c,
                ),
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}

/// 떠다니는 알갱이 하나(고정 값 — 한 번만 만든다).
class _Mote {
  const _Mote(this.x, this.phase, this.loops, this.radius);

  /// 가로 위치(0~1) · 시작 위상(0~1) · 한 바퀴(96초) 동안 화면을 도는 횟수 · 크기 난수(0~1).
  final double x;
  final double phase;
  final int loops;
  final double radius;

  static final _cache = <Motes, List<_Mote>>{};

  static List<_Mote> of(Motes kind) => _cache.putIfAbsent(kind, () {
    final r = math.Random(3);
    final n = kind == Motes.snow ? 46 : 22;
    return List.unmodifiable([
      for (var i = 0; i < n; i++)
        _Mote(r.nextDouble(), r.nextDouble(), 2 + r.nextInt(3), r.nextDouble()),
    ]);
  });
}

class _MotesPainter extends CustomPainter {
  _MotesPainter(this.kind, this.motes, this.t) : super(repaint: t);
  final Motes kind;
  final List<_Mote> motes;
  final Animation<double> t;

  // 칠 도구는 한 번만 만든다(알갱이마다·프레임마다 새로 만들지 않음).
  // 번짐(MaskFilter.blur)은 비싸서 방사형 그라데이션으로 부드러운 가장자리를 낸다.
  static final _petal = Paint()..color = const Color(0xCCFFB7C9);
  static final _snow = Paint()..color = const Color(0xCCFFFFFF);
  static final _ember = Paint()..shader = _soft(const Color(0xCCFFB050));
  static final _firefly = [
    for (var i = 0; i < 5; i++)
      Paint()..shader = _soft(Color.fromRGBO(220, 255, 140, 0.4 + 0.5 * i / 4)),
  ];

  /// 반지름 1 짜리 부드러운 원(그릴 때 캔버스를 키워 크기를 맞춘다).
  static Shader _soft(Color c) => RadialGradient(
    colors: [c, c.withValues(alpha: 0)],
    stops: const [0.3, 1],
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));

  static const _tau = 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    final up = kind == Motes.embers || kind == Motes.fireflies;
    final span = size.height + 40;
    for (final m in motes) {
      final sway = math.sin(_tau * (v * 12 + m.phase)) * 24;
      var y = ((m.phase + v * m.loops) % 1) * span;
      if (up) y = size.height - y;
      final x = m.x * size.width + sway;
      final py = y - 20;
      switch (kind) {
        case Motes.petals:
          canvas.save();
          canvas.translate(x, py);
          canvas.rotate(_tau * (v * 15 + m.phase));
          canvas.drawOval(const Rect.fromLTWH(-5, -3, 10, 6), _petal);
          canvas.restore();
        case Motes.embers:
          _glow(canvas, x, py, 2 + m.radius * 2 + 3, _ember);
        case Motes.snow:
          canvas.drawCircle(Offset(x, py), 1.5 + m.radius * 2.5, _snow);
        case Motes.fireflies:
          final glow = 0.5 + 0.5 * math.sin(_tau * (v * 45 + m.phase));
          _glow(canvas, x, py, 7, _firefly[(glow * 4).round()]);
        case Motes.none:
      }
    }
  }

  static void _glow(Canvas canvas, double x, double y, double r, Paint paint) {
    canvas
      ..save()
      ..translate(x, y)
      ..scale(r)
      ..drawCircle(Offset.zero, 1, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _MotesPainter old) =>
      old.kind != kind || old.motes != motes || old.t != t;
}

/// 누르면 쑥 들어가는 두툼한 단추(아래 그림자·윗면 광택·금테).
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.onTap,
    this.label,
    this.icon,
    this.color = Palette.red,
    this.height = 64,
    this.width,
    this.fontSize = 24,
    this.child,
    this.sound = 'ui_tap',
  });

  final VoidCallback? onTap;
  final String? label;

  /// 아이콘 그림 이름([Art.icon]).
  final String? icon;
  final Color color;
  final double height;
  final double? width;
  final double fontSize;
  final Widget? child;
  final String sound;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final base = enabled ? widget.color : const Color(0xFF5A5060);
    final top = Color.lerp(base, Colors.white, 0.22)!;
    final edge = Color.lerp(base, Colors.black, 0.45)!;
    const depth = 6.0;
    final h = widget.height;
    final content =
        widget.child ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Image.asset(Art.icon(widget.icon!), height: h * 0.62),
              const SizedBox(width: 8),
            ],
            if (widget.label != null)
              Flexible(
                child: Text(
                  widget.label!,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: titleFont,
                    fontSize: widget.fontSize,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: edge,
                        offset: const Offset(0, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                Sound.play(widget.sound, 0.8);
                Buzz.tick();
                widget.onTap!();
              }
            : null,
        child: SizedBox(
          width: widget.width,
          height: h + depth,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: h,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: edge,
                    borderRadius: BorderRadius.circular(h * 0.32),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 70),
                left: 0,
                right: 0,
                top: _down ? depth : 0,
                height: h,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(h * 0.32),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [top, base],
                    ),
                    border: Border.all(
                      color: enabled
                          ? Palette.gold.withValues(alpha: 0.85)
                          : Colors.white24,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // 윗면 광택.
                      Positioned(
                        left: 10,
                        right: 10,
                        top: 4,
                        height: h * 0.32,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(h),
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: content,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 그림 아이콘 + 짧은 이름 + 빨간 점(새 소식). 누르면 통통 튄다.
class IconTile extends StatefulWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = false,
    this.size = 62,
    this.locked = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool badge;
  final double size;
  final bool locked;

  @override
  State<IconTile> createState() => _IconTileState();
}

class _IconTileState extends State<IconTile>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Sound.play('ui_tap', 0.7);
          Buzz.tick();
          _c.forward(from: 0);
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) {
            final k = math.sin(_c.value * math.pi);
            return Transform.scale(scale: 1 - 0.12 * k, child: child);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: widget.size + 14,
                    height: widget.size + 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.16),
                          Colors.black.withValues(alpha: 0.35),
                        ],
                      ),
                      border: Border.all(
                        color: Palette.gold.withValues(alpha: 0.55),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(7),
                    child: Opacity(
                      opacity: widget.locked ? 0.4 : 1,
                      child: Image.asset(Art.icon(widget.icon)),
                    ),
                  ),
                  if (widget.locked)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Image.asset(Art.icon('lock'), width: 26),
                    ),
                  if (widget.badge)
                    const Positioned(right: 2, top: 2, child: RedDot()),
                ],
              ),
              const SizedBox(height: 4),
              OutlinedText(widget.label, size: 15),
            ],
          ),
        ),
      ),
    );
  }
}

/// 새 소식 빨간 점(살짝 숨 쉰다).
class RedDot extends StatefulWidget {
  const RedDot({super.key, this.size = 14});
  final double size;

  @override
  State<RedDot> createState() => _RedDotState();
}

class _RedDotState extends State<RedDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    key: const Key('red-dot'),
    scale: Tween(begin: 0.85, end: 1.15).animate(_c),
    child: Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3)],
      ),
    ),
  );
}

/// 테두리 두른 글자(밝은 배경 위에서도 읽힌다).
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    this.size = 16,
    this.color = Colors.white,
    this.title = false,
    this.align = TextAlign.center,
  });
  final String text;
  final double size;
  final Color color;
  final bool title;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final family = title ? titleFont : bodyFont;
    return Stack(
      children: [
        // 테두리 겹은 소리 내어 읽지 않는다(안 그러면 같은 글이 두 번 읽힌다).
        ExcludeSemantics(
          child: Text(
            text,
            textAlign: align,
            style: TextStyle(
              fontFamily: family,
              fontFamilyFallback: fallbackFonts,
              fontSize: size,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = size * 0.22
                ..color = const Color(0xFF1A0F0A),
            ),
          ),
        ),
        Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontFamily: family,
            fontFamilyFallback: fallbackFonts,
            fontSize: size,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// 재화 한 칸: 그림 + 숫자(바뀌면 굴러 오른다).
class CurrencyPill extends StatelessWidget {
  const CurrencyPill({
    super.key,
    required this.icon,
    required this.value,
    this.onTap,
  });
  final String icon;
  final num value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      height: 34,
      padding: const EdgeInsets.only(left: 2, right: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(Art.icon(icon), width: 30, height: 30),
          const SizedBox(width: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(end: value.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              _short(v.round()),
              style: const TextStyle(
                fontFamily: titleFont,
                fontFamilyFallback: fallbackFonts,
                fontSize: 16,
                color: Palette.text,
              ),
            ),
          ),
        ],
      ),
    );
    // 누르지 않는 표시용은 그대로, 눌리는 것은 손가락이 닿는 칸을 48dp 로(알약 모양은 그대로).
    if (onTap == null) return pill;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(height: 48, child: Align(widthFactor: 1, child: pill)),
      ),
    );
  }

  static String _short(int n) =>
      n >= 100000 ? '${(n / 1000).floor()}K' : n.toString();
}

/// 반투명 어두운 판(금테).
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
    this.borderColor,
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  /// 테두리 색(기본은 옅은 금색). 고른 것·받을 것을 도드라지게 할 때.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Palette.panelLight, Palette.panel],
      ),
      border: Border.all(
        color: borderColor ?? Palette.gold.withValues(alpha: 0.45),
        width: borderColor == null ? 1.5 : 2.5,
      ),
      boxShadow: const [
        BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 6)),
      ],
    ),
    child: child,
  );
}

/// 살아 있는 캐릭터: 숨 쉬듯 들썩이고, [attack] 이 바뀔 때마다 앞으로 튀어나가며 튕기는 자세.
class CharacterSprite extends StatefulWidget {
  const CharacterSprite({
    super.key,
    required this.id,
    this.height = 220,
    this.attack,
    this.flip = false,
    this.onTap,
  });

  final String id;
  final double height;

  /// 값이 바뀔 때마다 한 번 공격 동작.
  final ValueNotifier<int>? attack;
  final bool flip;
  final VoidCallback? onTap;

  @override
  State<CharacterSprite> createState() => _CharacterSpriteState();
}

class _CharacterSpriteState extends State<CharacterSprite>
    with TickerProviderStateMixin {
  late final _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);
  late final _hit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    widget.attack?.addListener(_strike);
  }

  @override
  void didUpdateWidget(covariant CharacterSprite old) {
    super.didUpdateWidget(old);
    if (old.attack != widget.attack) {
      old.attack?.removeListener(_strike);
      widget.attack?.addListener(_strike);
    }
  }

  void _strike() => _hit.forward(from: 0);

  @override
  void dispose() {
    widget.attack?.removeListener(_strike);
    _idle.dispose();
    _hit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.height * 440 / 520;
    // 그림 원본(880x1040)을 화면에 그리는 크기만큼만 읽는다(메모리).
    final px = (widget.height * MediaQuery.devicePixelRatioOf(context)).ceil();
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap == null
            ? null
            : () {
                _strike();
                widget.onTap!();
              },
        child: AnimatedBuilder(
          animation: Listenable.merge([_idle, _hit]),
          builder: (_, _) {
            final breath = Curves.easeInOut.transform(_idle.value);
            final h = _hit.value;
            final striking = _hit.isAnimating && h < 0.85;
            // 공격: 앞으로 쭉(0~0.25) → 버팀 → 제자리.
            final lunge = h < 0.25
                ? Curves.easeOut.transform(h / 0.25)
                : 1 - Curves.easeIn.transform(((h - 0.25) / 0.75).clamp(0, 1));
            final flash = striking && h < 0.18 ? (1 - h / 0.18) : 0.0;
            // 숨 쉬는 변환만 매 프레임 바뀌고, 그림 자체는 다시 그리지 않는다.
            final img = RepaintBoundary(
              child: Image.asset(
                Art.character(widget.id, attack: striking),
                width: w,
                height: widget.height,
                cacheHeight: px,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) =>
                    SizedBox(width: w, height: widget.height),
              ),
            );
            Widget body = Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..translateByDouble(
                  lunge * w * 0.08 * (widget.flip ? -1 : 1),
                  -breath * 3,
                  0,
                  1,
                )
                ..scaleByDouble(1 + 0.012 * breath, 1 + 0.028 * breath, 1, 1),
              child: img,
            );
            if (flash > 0) {
              body = Stack(
                children: [
                  body,
                  Positioned.fill(
                    child: Opacity(
                      opacity: flash * 0.7,
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcATop,
                        ),
                        child: body,
                      ),
                    ),
                  ),
                ],
              );
            }
            return widget.flip
                ? Transform.flip(flipX: true, child: body)
                : body;
          },
        ),
      ),
    );
  }
}

/// 공통 하위 화면: 배경 그림 + 투명 제목줄.
class GameScaffold extends StatelessWidget {
  const GameScaffold({
    super.key,
    this.title = '',
    this.appBar,
    required this.body,
    this.background = 'lobby',
    this.dim = 0.45,
    this.actions,
    this.motes = Motes.none,
  });

  final String title;

  /// 제목줄을 따로 줄 때(단추가 있는 화면).
  final PreferredSizeWidget? appBar;
  final Widget body;
  final String background;
  final double dim;
  final List<Widget>? actions;
  final Motes motes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: appBar ?? AppBar(title: Text(title), actions: actions),
      body: SceneBackground(
        asset: Art.background(background),
        dim: dim,
        motes: motes,
        child: SafeArea(child: body),
      ),
    );
  }
}

/// 화면 넘김: 살짝 커지며 나타난다.
Route<T> gameRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 280),
  reverseTransitionDuration: const Duration(milliseconds: 220),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, anim, _, child) {
    final a = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: Tween(begin: 0.96, end: 1.0).animate(a),
        child: child,
      ),
    );
  },
);

/// 동그란 얼굴(캐릭터 그림의 머리 부분).
class Portrait extends StatelessWidget {
  const Portrait({
    super.key,
    required this.id,
    this.size = 52,
    this.ring = Palette.gold,
    this.attack = false,
  });
  final String? id;
  final double size;
  final Color ring;
  final bool attack;

  @override
  Widget build(BuildContext context) {
    final s = size;
    final w = s * 1.8, h = w * 520 / 440;
    // 작은 얼굴을 큰 원본(880x1040)으로 읽지 않는다: 그리는 크기 × 화면 배율만큼만 읽는다.
    final px = (w * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 2.5),
        gradient: const RadialGradient(
          colors: [Color(0xFF5A4636), Color(0xFF241A14)],
        ),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
      ),
      child: ClipOval(
        child: id == null
            ? Padding(
                padding: EdgeInsets.all(s * 0.14),
                child: Image.asset(Art.icon('training')),
              )
            // 얼굴 그림이 있으면 그것(7등신 전신에서 자른 얼굴), 없으면 전신 그림의 머리 쪽을 잘라 쓴다.
            : Transform.scale(
                scale: attack ? 1.12 : 1,
                child: Image.asset(
                  Art.face(id!),
                  cacheWidth: (s * MediaQuery.devicePixelRatioOf(context))
                      .ceil(),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        left: s / 2 - w * 0.5,
                        top: s / 2 - h * 0.337,
                        width: w,
                        height: h,
                        child: Image.asset(
                          Art.character(id!, attack: attack),
                          cacheWidth: px,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// 내공 경지가 올랐으면 한 번 축하한다(설계서 §16.13). 올랐는지는 [Profile.celebratedStage] 와 비교.
Future<void> celebrateStage(BuildContext context) async {
  final store = ProfileStore.instance;
  final p = store.profile;
  if (p.stage <= p.celebratedStage) return;
  p.celebratedStage = p.stage;
  await store.save();
  if (!context.mounted) return;
  Sound.play('jingle_levelup');
  Buzz.heavy();
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '경지 상승',
    barrierColor: Colors.black.withValues(alpha: 0.75),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (c, _, _) => GestureDetector(
      key: const Key('stage-up'),
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(c),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CharacterSprite(id: p.hero?.name ?? 'seokdu', height: 240),
            const OutlinedText(
              '경지 상승!',
              size: 46,
              title: true,
              color: Palette.gold,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(Art.icon('naegong'), width: 44),
                const SizedBox(width: 8),
                OutlinedText(
                  '${p.stageName} · ${p.stage}단계',
                  size: 30,
                  title: true,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const OutlinedText('눌러서 닫기', size: 15, color: Palette.dim),
          ],
        ),
      ),
    ),
    transitionBuilder: (_, a, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
      child: FadeTransition(opacity: a, child: child),
    ),
  );
}

/// 화면을 처음 열 때 사부가 한 줄로 알려 준다(설계서 §16.13). 한 번 본 화면은 다시 안 뜬다.
///
/// 화면을 가리지 않는 말풍선이다: 말풍선 말고는 손가락이 그대로 아래 화면에 닿고(첫 터치를
/// 삼키지 않는다), 3초 뒤 저절로 사라지며, 누르면 바로 닫힌다. 다른 화면이 위로 열리거나
/// 이 화면에서 나가도 사라진다. 사라지면 Future 가 끝난다.
Future<void> firstVisit(BuildContext context, String key, String line) async {
  final store = ProfileStore.instance;
  final p = store.profile;
  if (p.seenHints.contains(key)) return;
  p.seenHints.add(key);
  await store.save();
  if (!context.mounted) return;
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  final route = ModalRoute.of(context);
  final done = Completer<void>();
  late final OverlayEntry entry;
  VoidCallback? detach;
  void close() {
    if (done.isCompleted) return;
    detach?.call();
    entry.remove();
    entry.dispose();
    done.complete();
  }

  // 이 화면이 가려지거나(위에 새 화면) 닫히면 말풍선도 같이 거둔다.
  final cover = route?.secondaryAnimation;
  final self = route?.animation;
  void onCover(AnimationStatus s) {
    if (s != AnimationStatus.dismissed) close();
  }

  void onSelf(AnimationStatus s) {
    if (s == AnimationStatus.reverse || s == AnimationStatus.dismissed) {
      close();
    }
  }

  cover?.addStatusListener(onCover);
  self?.addStatusListener(onSelf);
  detach = () {
    cover?.removeStatusListener(onCover);
    self?.removeStatusListener(onSelf);
  };
  entry = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: _HintBubble(line: line, onClose: close),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  return done.future;
}

/// [firstVisit] 의 말풍선: 사부 얼굴 + 한 줄 + 줄어드는 막대(곧 사라진다는 뜻) + 닫기 표시.
class _HintBubble extends StatefulWidget {
  const _HintBubble({required this.line, required this.onClose});
  final String line;
  final VoidCallback onClose;

  @override
  State<_HintBubble> createState() => _HintBubbleState();
}

class _HintBubbleState extends State<_HintBubble>
    with SingleTickerProviderStateMixin {
  static const _life = Duration(milliseconds: 3400);

  late final _c = AnimationController(vsync: this, duration: _life)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onClose();
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF2A1A12);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final v = _c.value;
        final inT = Curves.easeOut.transform((v / 0.1).clamp(0.0, 1.0));
        final outT = ((1 - v) / 0.1).clamp(0.0, 1.0);
        return Opacity(
          opacity: inT * outT,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - inT)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Semantics(
          liveRegion: true,
          label: widget.line,
          child: GestureDetector(
            key: const Key('first-visit'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onClose,
            child: Material(
              color: Palette.paper,
              elevation: 6,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: ink, width: 3),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                      child: Row(
                        children: [
                          const ExcludeSemantics(
                            child: Portrait(id: 'sabu', size: 44),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.line,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: bodyFont,
                                fontFamilyFallback: fallbackFonts,
                                fontSize: 18,
                                color: ink,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(Icons.close, color: ink, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _c,
                    builder: (_, _) => LinearProgressIndicator(
                      value: 1 - _c.value,
                      minHeight: 4,
                      backgroundColor: Colors.transparent,
                      color: Palette.redDeep.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 누르지 않는 알약: 그림 + 짧은 글(숫자·상태). [warn] 이면 붉게.
class InfoPill extends StatelessWidget {
  const InfoPill({super.key, this.icon, required this.text, this.warn = false});
  final String? icon;
  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    padding: EdgeInsets.only(left: icon == null ? 12 : 2, right: 12),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: (warn ? Palette.red : Palette.gold).withValues(alpha: 0.7),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Image.asset(Art.icon(icon!), width: 28, height: 28),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          maxLines: 1,
          style: TextStyle(
            fontFamily: titleFont,
            fontFamilyFallback: fallbackFonts,
            fontSize: 15,
            color: warn ? const Color(0xFFFF8A75) : Palette.text,
          ),
        ),
      ],
    ),
  );
}

/// 고르는 알약(옛 ChoiceChip 자리): 고른 것은 금빛, 못 쓰는 것은 흐리게 + 자물쇠.
/// 손가락이 닿는 칸은 늘 48dp 이상.
class GameChip extends StatelessWidget {
  const GameChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.trailing,
    this.locked = false,
  });
  final String label;
  final bool selected;

  /// null 이면 눌러도 반응 없음(흐리게).
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final on = selected;
    final fg = on ? const Color(0xFF2A1A08) : Palette.text;
    return Semantics(
      button: true,
      selected: on,
      enabled: onTap != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                Sound.play('ui_tap', 0.7);
                Buzz.tick();
                onTap!();
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Opacity(
            opacity: onTap == null || locked ? 0.55 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: on
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Palette.gold, Palette.goldDeep],
                      )
                    : null,
                color: on ? null : Palette.panel,
                border: Border.all(
                  color: on
                      ? Colors.white70
                      : Palette.gold.withValues(alpha: 0.4),
                  width: on ? 2 : 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (locked) ...[
                    Image.asset(Art.icon('lock'), width: 20),
                    const SizedBox(width: 4),
                  ] else if (on) ...[
                    Icon(Icons.check_rounded, size: 18, color: fg),
                    const SizedBox(width: 2),
                  ],
                  if (leading != null) ...[leading!, const SizedBox(width: 6)],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: bodyFont,
                        fontFamilyFallback: fallbackFonts,
                        fontSize: 17,
                        color: fg,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 6),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「끼운 중」「가짐」 같은 상태 표시(누르는 단추처럼 안 보이게 옥색 알약).
class StateBadge extends StatelessWidget {
  const StateBadge(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Palette.jadeDeep.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Palette.jade),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 18, color: Palette.jade),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 15)),
      ],
    ),
  );
}

/// 목록 한 줄(옛 Card + ListTile 자리): 그림 · 제목 · 짧은 한 줄 · 오른쪽 단추/표시.
class RowCard extends StatelessWidget {
  const RowCard({
    super.key,
    this.leading,
    required this.title,
    this.sub,
    this.trailing,
    this.onTap,
    this.dim = false,
    this.borderColor,
  });
  final Widget? leading;
  final String title;
  final String? sub;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// 흐리게(아직 못 쓰는 것).
  final bool dim;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    Widget card = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        radius: 18,
        borderColor: borderColor,
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: titleFont,
                      fontFamilyFallback: fallbackFonts,
                      fontSize: 17,
                      color: Palette.text,
                    ),
                  ),
                  if (sub != null)
                    Text(
                      sub!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: bodyFont,
                        fontFamilyFallback: fallbackFonts,
                        fontSize: 14,
                        color: Palette.dim,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
    if (dim) card = Opacity(opacity: 0.55, child: card);
    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Sound.play('ui_tap', 0.7);
          Buzz.tick();
          onTap!();
        },
        child: card,
      ),
    );
  }
}

/// 묶음 머리글: 그림 + 금빛 제목 (+ 오른쪽에 짧은 표시).
class SectionHead extends StatelessWidget {
  const SectionHead(this.text, {super.key, this.icon, this.trailing});
  final String text;
  final String? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Row(
      children: [
        if (icon != null) ...[
          Image.asset(Art.icon(icon!), width: 28, height: 28),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: titleFont,
              fontFamilyFallback: fallbackFonts,
              fontSize: 19,
              color: Palette.gold,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// 둥근 진행 막대(0~1).
class GameBar extends StatelessWidget {
  const GameBar({
    super.key,
    required this.value,
    this.color = Palette.gold,
    this.height = 10,
  });
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      minHeight: height,
      backgroundColor: Colors.white12,
      color: color,
    ),
  );
}

/// 작은 「?」 단추(48dp): 누르면 자세한 설명 창. 화면에는 한 줄만 두고 나머지는 여기로.
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, required this.title, required this.lines});
  final String title;

  /// (그림 이름 또는 null, 한 줄).
  final List<(String?, String)> lines;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '설명',
    iconSize: 28,
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    color: Palette.gold,
    icon: const Icon(Icons.help_outline_rounded),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (ic, t) in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ic != null) ...[
                        Image.asset(Art.icon(ic), width: 28, height: 28),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(t, style: const TextStyle(fontSize: 17)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('알겠어요'),
          ),
        ],
      ),
    ),
  );
}

/// 뒤로 갈 때 「톡」(설계서 §16.13).
class BackSoundObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) Sound.play('ui_back', 0.7);
  }
}
