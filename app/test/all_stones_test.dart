import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/progress/store.dart';
import 'package:alkkagi/screens/flick_view.dart';
import 'package:alkkagi/screens/game_screen.dart';
import 'package:alkkagi/screens/shop_screen.dart';
import 'package:alkkagi/screens/stats_screen.dart';
import 'package:alkkagi/ui/theme.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-11-01 형 「11단 천년온옥을 끼웠더니 화면이 안 나와」 — 돌 13종 × 모양 3 을 하나씩 끼우고
/// 대전 화면·만물상·능력치 화면이 오류 없이 뜨는지 본다.
Future<void> _wait(WidgetTester t, [int ms = 1000]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Profile _equipped(StoneMaterial m, StoneShape s) => Profile()
  ..tutorialDone = true
  ..hero = Fighter.yeonbi
  ..materials.add(m)
  ..material = m
  ..shapes.add(s)
  ..shape = s;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializePhysics();
  });

  for (final m in StoneMaterial.values) {
    for (final s in StoneShape.values) {
      testWidgets('${m.grade}단 ${m.label} · ${s.label}: 대전 화면이 뜬다', (t) async {
        t.view.physicalSize = const Size(412, 915);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        ProfileStore.instance.profile = _equipped(m, s);
        await t.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: GameScreen(
              config: MatchConfig(
                mode: MatchMode.vsAi,
                myMaterial: m,
                myShape: s,
                opponentMaterial: m,
                opponentShape: s,
              ),
            ),
          ),
        );
        await _wait(t);
        expect(t.takeException(), isNull);
        expect(find.byType(GameScreen), findsOneWidget);
        await t.pumpWidget(const SizedBox());
        await _wait(t, 3000);
      });
    }
  }

  // 돌을 고르면 열리는 확대 화면(손끝으로 치는 곳) — 기 빛깔 표에 처음 4종만 있어 4~13단에서 꺼졌다.
  for (final m in StoneMaterial.values) {
    for (final s in StoneShape.values) {
      testWidgets('${m.grade}단 ${m.label} · ${s.label}: 확대 화면이 뜬다', (t) async {
        await t.binding.setSurfaceSize(const Size(400, 860));
        addTearDown(() => t.binding.setSurfaceSize(null));
        final match = Match(
          MatchConfig(mode: MatchMode.vsAi, myMaterial: m, myShape: s),
        );
        await t.pumpWidget(
          MaterialApp(
            home: FlickView(
              match: match,
              stone: match.table.stones.firstWhere((x) => x.team == 0),
              onShot: (_, _) {},
              onCancel: () {},
            ),
          ),
        );
        await _wait(t, 500);
        expect(t.takeException(), isNull);
        match.dispose();
        await t.pumpWidget(const SizedBox());
      });
    }
  }

  for (final m in StoneMaterial.values) {
    testWidgets('${m.grade}단 ${m.label} 끼움: 만물상·능력치 화면이 뜬다', (t) async {
      t.view.physicalSize = const Size(412, 915);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      ProfileStore.instance.profile = _equipped(m, StoneShape.round);
      for (final screen in [const ShopScreen(), const StatsScreen()]) {
        await t.pumpWidget(MaterialApp(theme: buildTheme(), home: screen));
        await _wait(t, 600);
        expect(t.takeException(), isNull, reason: '${screen.runtimeType}');
        await t.pumpWidget(const SizedBox());
        await _wait(t, 300);
      }
    });
  }
}
