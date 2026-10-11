import 'dart:math' as math;

import 'package:alkkagi/game/flick.dart';
import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/screens/flick_view.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(initializePhysics);

  Future<(Match, List<FlickShot>)> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    final m = Match(const MatchConfig(mode: MatchMode.vsAi));
    final shots = <FlickShot>[];
    final stone = m.table.stones.firstWhere((s) => s.team == 0);
    await tester.pumpWidget(
      MaterialApp(
        home: FlickView(
          match: m,
          stone: stone,
          onShot: shots.add,
          onCancel: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    return (m, shots);
  }

  testWidgets('가까이 보기: 아래에서 손끝을 밀어 돌 가운데를 맞히면 위쪽으로 쏜다', (tester) async {
    final (m, shots) = await open(tester);
    expect(find.text('손끝을 미끄러뜨려 돌을 맞히세요'), findsOneWidget);
    final pad = tester.getRect(find.byKey(const Key('flick-pad')));
    await tester.flingFrom(
      Offset(pad.center.dx, pad.bottom - 8),
      Offset(0, -pad.height * 0.85),
      3000,
    );
    // 날아가는 연출(0.32초)이 끝나야 쏜다.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(shots, hasLength(1));
    expect(shots.single.angle, closeTo(-math.pi / 2, 0.05));
    expect(shots.single.power, greaterThan(0));
    m.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('돌을 비껴가면 쏘지 않고 다시 하라고 알려 준다', (tester) async {
    final (m, shots) = await open(tester);
    final pad = tester.getRect(find.byKey(const Key('flick-pad')));
    await tester.flingFrom(
      Offset(pad.left + 6, pad.bottom - 8),
      Offset(0, -pad.height * 0.85),
      3000,
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(shots, isEmpty);
    expect(find.text(FlickMiss.missed.hint), findsOneWidget);
    m.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
