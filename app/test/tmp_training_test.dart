import 'dart:math' as math;

import 'package:alkkagi/game/board_game.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/progress/store.dart';
import 'package:alkkagi/screens/training_screen.dart';
import 'package:alkkagi/ui/theme.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializePhysics();
  });

  testWidgets('목인항: 한 번 맞히면 1타만 센다', (t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final p = ProfileStore.instance.profile = Profile()
      ..tutorialDone = true
      ..seenHints.add('training');
    await t.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const TrainingScreen()),
    );
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    final game =
        (t.widget(
              find.byWidgetPredicate((w) => w is GameWidget),
            ) as GameWidget).game
            as BoardGame;
    final m = game.match;
    final me = m.table.stones[0];
    // 더미(0,0) 쪽으로 곧게.
    m.shoot(me, -math.pi / 2, 60, 0);
    Object? err;
    try {
      for (var i = 0; i < 200; i++) {
        await t.pump(const Duration(milliseconds: 50));
        if (!m.isMoving && m.turnCount > 0) break;
      }
    } catch (e) {
      err = e;
    }
    final ex = t.takeException();
    // ignore: avoid_print
    print(
      'hits today=${p.trainingHits} total=${p.totalHits} err=$err ex=${ex.runtimeType}',
    );
    await t.pumpWidget(const SizedBox());
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    t.takeException();
    expect(p.totalHits, 1);
  });
}
