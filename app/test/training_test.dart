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

  // 2026-10-11 점검: 더미를 다시 세우는 알림이 판 끝 처리로 곧장 되돌아와 한 번 치면
  // 1000번 넘게 불려 판이 터졌다. 한 번 치면 한 타만 센다.
  testWidgets('목인항: 더미를 한 번 맞히면 한 타만 센다(끝없이 다시 불리지 않음)', (t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    ProfileStore.instance.profile = Profile()
      ..tutorialDone = true
      ..seenHints.add('training');
    await t.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const TrainingScreen()),
    );
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    final gw = t.widget(find.byWidgetPredicate((w) => w is GameWidget));
    final match = ((gw as GameWidget).game! as BoardGame).match;
    final me = match.table.stones[0];
    match.shoot(me, -math.pi / 2, 90, 0);
    for (var i = 0; i < 400 && match.isMoving; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    await t.pump(const Duration(milliseconds: 100));
    final p = ProfileStore.instance.profile;
    expect(match.isMoving, isFalse);
    expect(p.trainingHits, 1);
    expect(p.totalHits, 1);
    await t.pumpWidget(const SizedBox());
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  });
}
