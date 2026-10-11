import 'dart:math' as math;

import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/progress/store.dart';
import 'package:alkkagi/screens/game_screen.dart';
import 'package:alkkagi/screens/puzzle_screen.dart';
import 'package:alkkagi/story/puzzles.dart';
import 'package:alkkagi/story/trickshots.dart';
import 'package:alkkagi/ui/theme.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'trickshot_solutions.dart';

void runToRest(Match m) {
  var guard = 0;
  while (m.isMoving && guard++ < 5000) {
    m.step();
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializePhysics();
  });

  test('트릭샷 60판: 묶음 6 × 10 · id 겹침 없음 · 돌이 판 안 · 시간 제한 있음', () {
    expect(trickshots.length, 60);
    expect(trickTierNames.length, 6);
    expect(trickshots.map((z) => z.id).toSet().length, 60);
    for (final z in trickshots) {
      expect(z.seconds, isNotNull, reason: '${z.id}');
      expect(z.layout.first.team, 0, reason: '${z.id}: 내 돌이 맨 앞');
      for (final p in [...z.layout, ...z.civilians]) {
        expect(
          z.arena.boundary.edgeDistance(p.x, p.y),
          greaterThan(PhysicsConstants.stoneRadius),
          reason: '${z.id}: 판 밖에 놓인 돌',
        );
      }
    }
  });

  for (final z in trickshots) {
    test('트릭샷 ${z.id} ${z.title}: 찾은 풀이로 성공 · 아무렇게나 치면 실패', () {
      final m = Match(z.config());
      for (final (angle, sp) in trickSolutions[z.id]!) {
        expect(m.isOver, isFalse);
        final me = m.table.stones.firstWhere((s) => s.team == 0);
        m.shoot(me, angle, sp, 0);
        runToRest(m);
      }
      expect(m.winner, 0, reason: '풀이로 이겨야');
      expect(m.civiliansLost, 0);
      m.dispose();

      final miss = Match(z.config());
      for (var i = 0; i < z.shots && !miss.isOver; i++) {
        final me = miss.table.stones.firstWhere((s) => s.team == 0);
        miss.shoot(me, math.pi / 2, 15, 0);
        runToRest(miss);
      }
      expect(miss.winner, 1, reason: '수를 다 쓰면 실패');
      miss.dispose();
    });
  }

  test('묘수풀이에서 백성 돌을 떨어뜨리면 바로 실패', () {
    final z = trickshots.firstWhere((x) => x.civilians.isNotEmpty);
    final m = Match(z.config());
    final civ = m.table.stones.firstWhere((s) => s.team == 2);
    civ.out = true;
    civ.body.isEnabled = false;
    final me = m.table.stones.firstWhere((s) => s.team == 0);
    m.shoot(me, math.pi / 2, 5, 0);
    runToRest(m);
    expect(m.winner, 1);
    m.dispose();
  });

  test('시간이 다 되면 실패로 끝난다', () {
    final m = Match(trickshots.first.config());
    m.timeUp();
    expect(m.winner, 1);
    m.dispose();
  });

  test('별: 남은 시간 60%↑ 셋 · 30%↑ 둘 · 그 밖 하나 · 더 좋은 별만 남긴다', () {
    expect(trickStars(0.9), 3);
    expect(trickStars(0.6), 3);
    expect(trickStars(0.59), 2);
    expect(trickStars(0.3), 2);
    expect(trickStars(0.1), 1);
    final p = Profile();
    expect(p.recordPuzzleStars(1000, 2), 2);
    expect(p.recordPuzzleStars(1000, 1), 0);
    expect(p.recordPuzzleStars(1000, 3), 1);
    expect(p.trickStarTotal, 3);
    final q = Profile.decode(p.encode());
    expect(q.puzzleStars, {1000: 3});
  });

  test('열림: 묶음 첫 판은 앞 묶음 5판 · 그다음은 바로 앞 판', () {
    final p = Profile();
    expect(PuzzleScreen.trickOpen(p, trickshots[0]), isTrue);
    expect(PuzzleScreen.trickOpen(p, trickshots[1]), isFalse);
    p.puzzles.add(trickshots[0].id);
    expect(PuzzleScreen.trickOpen(p, trickshots[1]), isTrue);
    final tier2 = trickshots.firstWhere((z) => z.id == 1010);
    expect(PuzzleScreen.trickOpen(p, tier2), isFalse);
    for (var i = 0; i < 5; i++) {
      p.puzzles.add(trickshots[i].id);
    }
    expect(PuzzleScreen.trickOpen(p, tier2), isTrue);
  });

  testWidgets('시간 제한: 겨누는 동안 줄고 다 되면 실패 · 별 0', (t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    ProfileStore.instance.profile = Profile()..tutorialDone = true;
    final z = trickshots.first;
    GameScreen.lastStars = 9;
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: GameScreen(config: z.config(), title: 't', timeLimit: 2),
      ),
    );
    expect(find.byKey(const Key('time-left')), findsOneWidget);
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('패배'), findsWidgets);
    expect(GameScreen.lastStars, 0);
    await t.pumpWidget(const SizedBox());
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  });
}
