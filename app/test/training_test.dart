import 'dart:math' as math;

import 'package:alkkagi/game/board_game.dart';
import 'package:alkkagi/game/match.dart';
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
    // 2026-10-14 형 「저장 기능과 다음 목표치와 진행 상황」: 진행 막대 둘 · 저장 단추 · 저장됨 표시.
    expect(find.byKey(const Key('goal-stage')), findsOneWidget);
    expect(find.textContaining('삼류 → 이류'), findsOneWidget);
    expect(find.text('오늘 깨달음 1/30타 (내공 6배)'), findsOneWidget);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await t.pump();
    expect(find.textContaining('저장됨 · '), findsOneWidget);
    expect(find.byKey(const Key('training-save')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  });

  // 2026-10-14 형 「목인항 수련할 때 자꾸 그냥 통과하는 오류」 — 처음 가설(떠서 더미를 넘어감)을 확인한 시험.
  // 400수 실험에서 더미를 뚫고 지나간 수는 0 이었다(진짜 원인은 손끝 판정 — flick_test 「그냥 통과하지 않음」).
  test('목인항: 위·아래 끝을 쳐도(뜨는 타점) 더미를 지나가지 않고 맞는다', () {
    for (final hit in [0.95, -0.95]) {
      final m = Match(
        const MatchConfig(mode: MatchMode.practice, training: true),
      );
      m.resetTraining(0, 0);
      final me = m.table.stones[0];
      final dummy = m.table.stones[1];
      final angle = math.atan2(
        dummy.position.y - me.position.y,
        dummy.position.x - me.position.x,
      );
      m.shoot(me, angle, 90, hit, lift: true);
      var guard = 0;
      while (m.isMoving && guard++ < 2000) {
        m.step();
      }
      expect(m.touchedThisTurn, contains(1), reason: '타점 $hit');
      m.dispose();
    }
  });

  test('목인항 목표: 다음 경지까지 비율 · 오늘 친 수 · 마지막 경지', () {
    final p = Profile()
      ..naegong = 180
      ..trainingDay = '2026-10-14'
      ..trainingHits = 12;
    final g = TrainingGoal.of(p, '2026-10-14');
    expect(g.stageName, '이류');
    expect(g.nextName, '일류');
    expect(g.need, 270);
    expect(g.stageProgress, closeTo((180 - 90) / (270 - 90), 1e-9));
    expect(g.todayHits, 12);
    expect(TrainingGoal.of(p, '2026-10-15').todayHits, 0, reason: '날이 바뀌면 0');
    final top = TrainingGoal.of(Profile()..naegong = 9999, '2026-10-14');
    expect(top.nextName, isNull);
    expect(top.stageProgress, 1);
  });

  test('대전에서는 그대로 뜬다(떠서 넘기기는 남긴다)', () {
    final m = Match(const MatchConfig(mode: MatchMode.twoPlayer));
    final me = m.table.stones.first;
    m.shoot(me, -math.pi / 2, 90, 0.95, lift: true);
    m.step();
    expect(me.airborne, isTrue);
    m.dispose();
  });
}
