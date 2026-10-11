import 'dart:math' as math;

import 'package:alkkagi/game/flick.dart';

import 'dart:typed_data';

import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/input/touch_feed.dart';
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
          onShot: (s, _) => shots.add(s),
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

  testWidgets('닿지 않은 손가락(띄움)이 돌을 스치면 돌 위쪽(상단)을 친 것으로 쏜다', (tester) async {
    final (m, shots) = await open(tester);
    final pad = tester.getRect(find.byKey(const Key('flick-pad')));
    final dpr = tester.view.devicePixelRatio;
    // 패드 가운데 줄을 아래에서 위로 0.2초에 쓸고 지나간다(8ms 마다 한 점, 화면에는 안 닿음).
    const n = 25;
    for (var i = 0; i <= n; i++) {
      final y = pad.bottom - 8 - (pad.height - 16) * i / n;
      TouchFeed.instance.inject(
        Float64List.fromList([
          i == 0 ? 9 : 7,
          1,
          1000.0 + i * 8,
          pad.center.dx * dpr,
          y * dpr,
          0,
          0,
          0,
        ]),
      );
      await tester.pump(const Duration(milliseconds: 1));
    }
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(TouchFeed.instance.hoverPoints, n + 1);
    expect(shots, hasLength(1));
    expect(shots.single.hit, 1);
    expect(shots.single.angle, closeTo(-math.pi / 2, 0.05));
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
