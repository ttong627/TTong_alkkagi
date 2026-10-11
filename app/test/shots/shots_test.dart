// 화면 사진 찍기(눈으로 확인용 · CI 에서는 건너뜀): SHOTS=1 flutter test test/shots
// 진짜 글꼴과 그림을 읽어 휴대폰 크기(412×915)로 그린 뒤 build/shots/*.png 로 저장한다.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alkkagi/game/arena.dart';
import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/progress/store.dart';
import 'package:alkkagi/screens/campaign_screen.dart';
import 'package:alkkagi/screens/codex_screen.dart';
import 'package:alkkagi/screens/daily_screen.dart';
import 'package:alkkagi/screens/dialogue_screen.dart';
import 'package:alkkagi/screens/settings_screen.dart';
import 'package:alkkagi/screens/shop_screen.dart';
import 'package:alkkagi/screens/stats_screen.dart';
import 'package:alkkagi/story/chapters.dart';
import 'package:alkkagi/screens/game_screen.dart';
import 'package:alkkagi/screens/hero_pick_screen.dart';
import 'package:alkkagi/screens/home_screen.dart';
import 'package:alkkagi/screens/splash_screen.dart';
import 'package:alkkagi/screens/tutorial_screen.dart';
import 'package:alkkagi/ui/art.dart';
import 'package:alkkagi/ui/theme.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _fonts() async {
  for (final (fam, file) in [
    ('BlackHanSans', 'BlackHanSans-Regular'),
    ('DoHyeon', 'DoHyeon-Regular'),
    ('NotoKRFallback', 'NotoSansKR-Fallback'),
  ]) {
    final l = FontLoader(fam)..addFont(rootBundle.load('assets/fonts/$file.ttf'));
    await l.load();
  }
  // 아이콘 글꼴.
  final mi = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await mi.load().catchError((_) {});
}

Future<void> _shot(WidgetTester t, Widget w, String name, {int settleMs = 1600}) async {
  final key = GlobalKey();
  await t.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: w),
    ),
  );
  // 그림을 실제로 풀어 화면에 올린다.
  await t.runAsync(() async {
    final ctx = key.currentContext!;
    for (final e in [
      ...Art.characterIds.map((id) => Art.character(id)),
      ...Art.characterIds.map((id) => Art.character(id, attack: true)),
      ...Art.iconNames.map(Art.icon),
      for (final a in Arena.values) Art.arenaBackground(a),
      Art.background('lobby'),
    ]) {
      await precacheImage(AssetImage(e), ctx);
    }
    await Art.preload();
  });
  for (var i = 0; i < settleMs ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await t.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 1);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('build/shots/$name.png')..createSync(recursive: true);
    f.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  final on = Platform.environment['SHOTS'] == '1';
  setUpAll(() async {
    if (!on) return;
    SharedPreferences.setMockInitialValues({});
    await initializePhysics();
    await _fonts();
  });

  testWidgets('화면 사진', (t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    final p = ProfileStore.instance.profile
      ..hero = Fighter.yonga
      ..tutorialDone = true
      ..coins = 1240
      ..silver = 7
      ..naegong = 180
      ..attendDay = today();
    p.done.add('c1');
    await _shot(t, const CampaignScreen(), 'campaign');
    await _shot(t, DialogueScreen(title: campaign[1].title, lines: campaign[1].intro, scene: 'oilyTable'), 'dialogue', settleMs: 2800);
    await _shot(t, const ShopScreen(), 'shop');
    await _shot(t, const StatsScreen(), 'stats');
    await _shot(t, const CodexScreen(), 'codex');
    await _shot(t, const SettingsScreen(), 'settings');
    await _shot(t, const SplashScreen(), 'splash', settleMs: 800);
    await _shot(t, const HomeScreen(), 'lobby');
    await _shot(t, const DailyScreen(tab: 0), 'daily_attend');
    await _shot(t, const DailyScreen(tab: 1), 'daily_missions');
    await _shot(t, const HeroPickScreen(), 'hero_pick');
    await _shot(t, const TutorialScreen(), 'tutorial');
    await _shot(
      t,
      GameScreen(config: lessons[0].config, title: lessons[0].title, coach: true, coachLines: [lessons[0].line]),
      'game_coach',
      settleMs: 2500,
    );
    await _shot(
      t,
      const GameScreen(
        config: MatchConfig(mode: MatchMode.vsAi, arena: Arena.kubiForest, opponentName: '쿠비'),
        title: '4장 · 야성의 숲',
      ),
      'game_vs_intro',
      settleMs: 700,
    );
    await _shot(
      t,
      const GameScreen(
        config: MatchConfig(mode: MatchMode.vsAi, arena: Arena.oilyTable, opponentName: '통통'),
        title: '2장 · 기름진 난장',
      ),
      'game_oily',
      settleMs: 2600,
    );
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  }, skip: !on);
}
