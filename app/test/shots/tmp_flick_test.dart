import 'dart:math' as math;

import 'package:alkkagi/game/flick.dart';
import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/screens/flick_view.dart';
import 'package:alkkagi/screens/tutorial_screen.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(initializePhysics);
  for (final size in [const Size(412, 915), const Size(360, 640)]) {
    Future<(Match, List<FlickShot>, Rect, Offset, double)> open(
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      final m = Match(lessons[0].config);
      final shots = <FlickShot>[];
      final stone = m.table.stones.firstWhere((s) => s.team == 0);
      await tester.pumpWidget(
        MaterialApp(
          home: FlickView(
            match: m,
            stone: stone,
            onShot: (s, _) => shots.add(s),
            onCancel: () {},
            demo: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      final pad = tester.getRect(find.byKey(const Key('flick-pad')));
      final h = pad.height, w = pad.width;
      final miniH = h * 0.3, floorH = h - miniH - 78;
      final r = math.min(w * 0.28, floorH * 0.3);
      final c = Offset(pad.left + w / 2, pad.top + miniH + floorH * 0.5);
      return (m, shots, pad, c, r);
    }

    Future<void> settle(WidgetTester t) async {
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
    }

    testWidgets('$size 새총식: 돌을 누르고 뒤로 끌었다 놓기', (t) async {
      final (m, shots, pad, c, r) = await open(t);
      print(
        'r=${r.toStringAsFixed(1)} stone-diam=${(2 * r).toStringAsFixed(0)}dp pad=$pad',
      );
      final g = await t.startGesture(c);
      for (var i = 1; i <= 10; i++) {
        await g.moveTo(c + Offset(0, i * r * 0.2));
        await t.pump(const Duration(milliseconds: 20));
      }
      await g.up();
      await settle(t);
      print(
        'slingshot shots=${shots.length} text=${find.textContaining('튕겨').evaluate().length}',
      );
      for (final w
          in find.byType(Text).evaluate().map((e) => (e.widget as Text).data)) {
        if (w != null && (w.contains('튕') || w.contains('내공')))
          print('  text: $w');
      }
      m.dispose();
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('$size 그냥 한 번 톡(탭)', (t) async {
      final (m, shots, pad, c, r) = await open(t);
      await t.tapAt(c);
      await settle(t);
      print('tap shots=${shots.length}');
      for (final w
          in find.byType(Text).evaluate().map((e) => (e.widget as Text).data)) {
        if (w != null && (w.contains('튕') || w.contains('내공')))
          print('  text: $w');
      }
      m.dispose();
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('$size 느린 쓸기(0.5초) 돌 아래에서 위로', (t) async {
      final (m, shots, pad, c, r) = await open(t);
      await t.timedDragFrom(
        Offset(c.dx, c.dy + r * 3),
        Offset(0, -r * 5),
        const Duration(milliseconds: 500),
      );
      await settle(t);
      print(
        'slow swipe shots=${shots.length} power=${shots.isEmpty ? null : shots.first.power.toStringAsFixed(2)}',
      );
      for (final w
          in find.byType(Text).evaluate().map((e) => (e.widget as Text).data)) {
        if (w != null && (w.contains('튕') || w.contains('내공')))
          print('  text: $w');
      }
      m.dispose();
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('$size 위에서 아래로 쓸기(반대 방향)', (t) async {
      final (m, shots, pad, c, r) = await open(t);
      await t.timedDragFrom(
        Offset(c.dx, c.dy - r * 3),
        Offset(0, r * 5),
        const Duration(milliseconds: 80),
      );
      await settle(t);
      print(
        'downward shots=${shots.length} angle=${shots.isEmpty ? null : (shots.first.angle * 180 / math.pi).toStringAsFixed(0)}',
      );
      m.dispose();
      await t.pumpWidget(const SizedBox());
    });
  }
}
