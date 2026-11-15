import 'dart:math' as math;

import 'package:alkkagi/game/board_game.dart';
import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/progress/settings.dart';
import 'package:alkkagi/progress/store.dart';
import 'package:alkkagi/screens/flick_view.dart';
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

  testWidgets('목인항 6/10 검지 튕기기: 평범하게 손가락으로 밀어 쳐서 5회 통과한다(당겨 쏘기 켜짐 포함)', (
    t,
  ) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      Settings.instance.pull = false;
      t.view.reset();
    });
    Settings.instance.pull = true;
    ProfileStore.instance.profile = Profile()
      ..tutorialDone = true
      ..seenHints.add('training')
      ..drillCleared = 5
      ..drillIndex = 5
      ..drillProgress = 0;

    await t.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const TrainingScreen()),
    );
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('내 돌을 눌러 겨누세요'), findsWidgets);
    expect(find.textContaining('수련 6/10 · 검지 튕기기'), findsOneWidget);

    BoardGame board() =>
        (t
                .widget<GameWidget>(
                  find.byWidgetPredicate((w) => w is GameWidget),
                )
                .game!)
            as BoardGame;

    for (var hit = 1; hit <= 5; hit++) {
      final game = board();
      final match = game.match;
      // 더미를 내 돌 바로 위 정면에 두어 손가락 스와이프가 확실히 명중하게 한다.
      match.resetTraining(0, 0);
      await t.pump(const Duration(milliseconds: 32));

      final gwBox = t.getRect(find.byWidgetPredicate((w) => w is GameWidget));
      final stoneAt =
          gwBox.topLeft +
          game.screenOf(
            match.table.stones[0].position.x,
            match.table.stones[0].position.y,
          );
      if (hit == 1) {
        // 판 위 내 돌에서 바로 드래그해도 가까이 보기가 열리는지 검증.
        final drag = await t.startGesture(stoneAt);
        await drag.moveBy(const Offset(0, -30));
        await drag.up();
      } else {
        await t.tapAt(stoneAt);
      }
      for (var i = 0; i < 25; i++) {
        await t.pump(const Duration(milliseconds: 20));
      }
      expect(find.byType(FlickView), findsOneWidget);
      expect(find.text('튕기기 수련'), findsOneWidget);

      final pad = t.getRect(find.byKey(const Key('flick-pad')));
      final (center, r, _) = FlickView.layout(pad.size);
      final c = pad.topLeft + center;
      // 돌 아래에서 돌 한가운데를 지나 위로 자연스럽게 밀어 튕긴다(손을 미리 떼지 않는 일반 스와이프).
      final g = await t.startGesture(c + Offset(0, r * 2.0));
      for (var step = 1; step <= 8; step++) {
        await g.moveTo(
          Offset.lerp(
            c + Offset(0, r * 2.0),
            c - Offset(0, r * 0.6),
            step / 8,
          )!,
        );
        await t.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      // 발사 연출(0.42초) + 물리 진행이 끝날 때까지 진행.
      for (
        var i = 0;
        i < 300 &&
            (find.byType(FlickView).evaluate().isNotEmpty || match.isMoving);
        i++
      ) {
        await t.pump(const Duration(milliseconds: 16));
      }
      await t.pump(const Duration(milliseconds: 80));

      final p = ProfileStore.instance.profile;
      if (hit < 5) {
        expect(p.drillProgress, hit, reason: '$hit번째 스와이프 적중 후 진행도');
      } else {
        expect(find.byKey(const Key('drill-cleared')), findsOneWidget);
        expect(p.drillCleared, 6);
      }
    }

    await t.tap(find.text('다음 수련'));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 30));
    }
    await t.pumpWidget(const SizedBox());
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  });

  testWidgets('목인항 8/10 내공 타격: 가까이 보기를 열면 내공 타격이 미리 선택되어 있다', (t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    ProfileStore.instance.profile = Profile()
      ..tutorialDone = true
      ..seenHints.add('training')
      ..drillCleared = 7
      ..drillIndex = 7
      ..drillProgress = 0;

    await t.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const TrainingScreen()),
    );
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    final game =
        (t
                .widget<GameWidget>(
                  find.byWidgetPredicate((w) => w is GameWidget),
                )
                .game!)
            as BoardGame;
    final gwBox = t.getRect(find.byWidgetPredicate((w) => w is GameWidget));
    final stoneAt =
        gwBox.topLeft +
        game.screenOf(
          game.match.table.stones[0].position.x,
          game.match.table.stones[0].position.y,
        );
    await t.tapAt(stoneAt);
    for (var i = 0; i < 25; i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
    final chip = t.widget<ChoiceChip>(find.byKey(const Key('mode-inner')));
    expect(chip.selected, isTrue);

    await t.pumpWidget(const SizedBox());
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  });
}
