import 'package:alkkagi/progress/daily.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/progress/store.dart';
import 'package:alkkagi/screens/daily_screen.dart';
import 'package:alkkagi/screens/game_screen.dart';
import 'package:alkkagi/screens/hero_pick_screen.dart';
import 'package:alkkagi/screens/home_screen.dart';
import 'package:alkkagi/screens/tutorial_screen.dart';
import 'package:alkkagi/ui/theme.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home) => MaterialApp(theme: buildTheme(), home: home);

/// 끝없이 도는 연출(꽃잎·숨쉬기)이 있어 pumpAndSettle 대신 시간을 넘긴다.
Future<void> _wait(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializePhysics();
  });

  setUp(() {
    ProfileStore.instance.profile = Profile();
  });

  testWidgets('처음 켜면 입문이 열리고(뒤로 가기 불가) 캐릭터부터 고른 뒤 수련 판', (t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(const HomeScreen()));
    await _wait(t, 800);
    expect(find.byType(TutorialScreen), findsOneWidget);
    expect(find.text('어서 오너라. 손가락 하나로 천하를 다투는 곳 — 탄지무림이다.'), findsOneWidget);
    // 뒤로 가기를 눌러도 그대로.
    await t.binding.handlePopRoute();
    await _wait(t);
    expect(find.byType(TutorialScreen), findsOneWidget);
    // 두 번 누르면 먼저 캐릭터 고르기(수련 판부터 내 무인으로 친다).
    await t.tap(find.byKey(const Key('tutorial-next')));
    await _wait(t);
    await t.tap(find.byKey(const Key('tutorial-next')));
    await _wait(t, 1200);
    expect(find.byType(HeroPickScreen), findsOneWidget);
    expect(ProfileStore.instance.profile.hero, isNull);
    await t.tap(find.byKey(const Key('hero-pick')));
    // 저장은 진짜 파일 쓰기라 시험 시계로는 안 흐른다 — 실제 시간을 조금 준다.
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await _wait(t, 1600);
    expect(ProfileStore.instance.profile.hero, isNotNull);
    // 이어서 첫 수련 판(시범 손가락 · 나가기 단추 없음).
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.byKey(const Key('ghost-hand')), findsWidgets);
    expect(find.byKey(const Key('pause')), findsNothing);
    expect(find.text(lessons.first.line), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await _wait(t, 3000);
  });

  testWidgets('로비: 강호행 단추 · 출석 빨간 점 · 재화', (t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final p = ProfileStore.instance.profile
      ..tutorialDone = true
      ..hero = Fighter.yeonbi
      ..coins = 321
      // 오늘 출석은 받은 셈(출석 창이 저절로 뜨지 않게) — 임무 하나는 끝냄.
      ..attendDay = today();
    Missions.record(p, Missions.of(today()).first.deed, today(), 999);
    await t.pumpWidget(_app(const HomeScreen()));
    await _wait(t, 1000);
    expect(find.text('강호행'), findsOneWidget);
    expect(find.byKey(const Key('lobby-hero')), findsOneWidget);
    expect(find.text('321'), findsOneWidget);
    // 받을 임무가 있으니 임무 아이콘에 빨간 점.
    expect(
      find.descendant(
        of: find.byKey(const Key('menu-missions')),
        matching: find.byKey(const Key('red-dot')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('menu-attendance')),
        matching: find.byKey(const Key('red-dot')),
      ),
      findsNothing,
    );
    await t.pumpWidget(const SizedBox());
    await _wait(t, 3000);
  });

  testWidgets('출석: 받기를 누르면 엽전이 들어오고 단추가 잠긴다', (t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(const DailyScreen()));
    await _wait(t);
    await t.tap(find.byKey(const Key('attend-claim')));
    await _wait(t, 1600);
    final p = ProfileStore.instance.profile;
    expect(p.coins, attendanceRewards.first.coins);
    expect(p.attendDay, today());
    expect(find.text('내일 또 와요'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await _wait(t, 1000);
  });

  testWidgets('캐릭터 고르기: 넘기고 고르면 저장된다', (t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(const HeroPickScreen()));
    await _wait(t);
    await t.drag(find.byKey(const Key('hero-pages')), const Offset(-300, 0));
    await _wait(t, 800);
    await t.tap(find.byKey(const Key('hero-pick')));
    await _wait(t);
    final p = ProfileStore.instance.profile;
    expect(p.hero, Fighter.values.where((h) => h.starter).elementAt(1));
    expect(p.heroes, contains(p.hero));
    await t.pumpWidget(const SizedBox());
    await _wait(t, 1000);
  });
}
