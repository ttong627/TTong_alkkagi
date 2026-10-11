import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../progress/settings.dart';
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
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat(reverse: true);

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
        AnimatedBuilder(
          animation: _c,
          builder: (_, child) {
            final k = Curves.easeInOut.transform(_c.value);
            return Transform.scale(
              scale: 1.04 + 0.06 * k,
              alignment: Alignment(-0.3 + 0.6 * k, -0.2),
              child: child,
            );
          },
          child: Image.asset(
            widget.asset,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        if (widget.dim > 0)
          ColoredBox(color: Colors.black.withValues(alpha: widget.dim)),
        if (widget.motes != Motes.none)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => CustomPaint(
                painter: _MotesPainter(
                  widget.motes,
                  DateTime.now().millisecondsSinceEpoch / 1000,
                ),
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}

class _MotesPainter extends CustomPainter {
  _MotesPainter(this.kind, this.t);
  final Motes kind;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(3);
    final n = kind == Motes.snow ? 46 : 22;
    for (var i = 0; i < n; i++) {
      final speed = 14 + r.nextDouble() * 22;
      final x0 = r.nextDouble() * size.width;
      final phase = r.nextDouble() * 100;
      final sway = math.sin((t + phase) * 0.8) * 24;
      final up = kind == Motes.embers || kind == Motes.fireflies;
      var y = ((t + phase) * speed) % (size.height + 40);
      if (up) y = size.height - y;
      final p = Offset(x0 + sway, y - 20);
      switch (kind) {
        case Motes.petals:
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate((t + phase) * 1.3);
          canvas.drawOval(
            const Rect.fromLTWH(-5, -3, 10, 6),
            Paint()..color = const Color(0xCCFFB7C9),
          );
          canvas.restore();
        case Motes.embers:
          canvas.drawCircle(
            p,
            2 + r.nextDouble() * 2,
            Paint()
              ..color = const Color(0xCCFFB050)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        case Motes.snow:
          canvas.drawCircle(
            p,
            1.5 + r.nextDouble() * 2.5,
            Paint()..color = const Color(0xCCFFFFFF),
          );
        case Motes.fireflies:
          final glow = 0.5 + 0.5 * math.sin((t + phase) * 3);
          canvas.drawCircle(
            p,
            3,
            Paint()
              ..color = Color.fromRGBO(220, 255, 140, 0.4 + 0.5 * glow)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        case Motes.none:
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MotesPainter old) => old.t != t;
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
        Text(
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                  fontSize: 16,
                  color: Palette.text,
                ),
              ),
            ),
          ],
        ),
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
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;

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
        color: Palette.gold.withValues(alpha: 0.45),
        width: 1.5,
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
    return GestureDetector(
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
          final img = Image.asset(
            Art.character(widget.id, attack: striking),
            width: w,
            height: widget.height,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) =>
                SizedBox(width: w, height: widget.height),
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
          return widget.flip ? Transform.flip(flipX: true, child: body) : body;
        },
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
            : Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: s / 2 - w * 0.5,
                    top: s / 2 - h * 0.337,
                    width: w,
                    height: h,
                    child: Image.asset(
                      Art.character(id!, attack: attack),
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
