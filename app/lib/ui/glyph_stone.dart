import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../progress/settings.dart';
import '../story/chapters.dart';
import 'kit.dart';
import 'theme.dart';

/// 기명석(설계서 §2.6): 검은 돌 둘레에 문양 넷 — 깨어난 문양만 금빛으로 빛난다.
/// [glow] 0~1 은 [fresh] 번째 문양이 막 깨어나는 빛(문양 각성 장면).
class GlyphStone extends StatelessWidget {
  const GlyphStone({
    super.key,
    required this.lit,
    this.size = 96,
    this.fresh,
    this.glow = 0,
  });

  /// 깨어난 문양(0~3).
  final Set<int> lit;
  final double size;
  final int? fresh;
  final double glow;

  /// 강호행 진행([done] = 깬 판 id)에서 깨어난 문양.
  static Set<int> litFrom(Set<String> done) => {
    for (var i = 0; i < glyphs.length; i++)
      if (done.contains(glyphs[i].$1)) i,
  };

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _GlyphPainter(lit, fresh, glow),
  );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.lit, this.fresh, this.glow);
  final Set<int> lit;
  final int? fresh;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.36;
    final all = lit.length == glyphs.length;
    // 네 문양이 모두 깨어나면 돌 둘레가 은은하게 빛난다.
    if (all || glow > 0) {
      canvas.drawCircle(
        c,
        r * (1.25 + 0.15 * glow),
        Paint()
          ..color = Palette.gold.withValues(alpha: 0.25 + 0.35 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFF4A4A52), Color(0xFF15151A)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white24,
    );
    for (var i = 0; i < glyphs.length; i++) {
      final a = -math.pi / 2 + i * math.pi / 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * r * 0.58;
      final on = lit.contains(i);
      final hot = i == fresh ? glow : 0.0;
      if (on || hot > 0) {
        canvas.drawCircle(
          p,
          r * (0.26 + 0.2 * hot),
          Paint()
            ..color = Palette.gold.withValues(alpha: 0.75 + 0.25 * hot)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: glyphs[i].$2.characters.first,
          style: TextStyle(
            fontFamily: titleFont,
            fontSize: r * 0.42,
            color: on || hot > 0.5 ? const Color(0xFF3A2208) : Colors.white24,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter o) =>
      o.glow != glow || o.fresh != fresh || o.lit.length != lit.length;
}

/// 문양 각성 장면: 돌이 떠오르고 새 문양이 번쩍 깨어난다(소리 · 쿵-쿵 진동). 누르면 닫힌다.
Future<void> showGlyphAwaken(
  BuildContext context, {
  required int index,
  required Set<int> lit,
}) {
  Sound.play('unlock');
  Buzz.burst();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (c) => _GlyphAwaken(index: index, lit: lit),
  );
}

class _GlyphAwaken extends StatefulWidget {
  const _GlyphAwaken({required this.index, required this.lit});
  final int index;
  final Set<int> lit;

  @override
  State<_GlyphAwaken> createState() => _GlyphAwakenState();
}

class _GlyphAwakenState extends State<_GlyphAwaken>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = glyphs[widget.index];
    return GestureDetector(
      key: const Key('glyph-awaken'),
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context),
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final t = Curves.easeOutBack.transform(_c.value.clamp(0, 1));
            // 0.5초 뒤 번쩍 — 그다음 은은하게 남는다.
            final flash = _c.value < 0.35
                ? 0.0
                : (1 - ((_c.value - 0.35) / 0.65)) * 0.6 + 0.4;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedText(
                  '${widget.index + 1}번째 문양',
                  size: 22,
                  color: Palette.dim,
                ),
                const SizedBox(height: 8),
                Transform.scale(
                  scale: 0.6 + 0.4 * t,
                  child: GlyphStone(
                    lit: {...widget.lit, if (_c.value > 0.35) widget.index},
                    fresh: widget.index,
                    glow: flash,
                    size: 220,
                  ),
                ),
                const SizedBox(height: 12),
                Opacity(
                  opacity: _c.value < 0.35 ? 0 : 1,
                  child: Column(
                    children: [
                      OutlinedText(
                        g.$2,
                        size: 44,
                        title: true,
                        color: Palette.gold,
                      ),
                      const SizedBox(height: 4),
                      OutlinedText(g.$3, size: 20),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
