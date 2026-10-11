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
import 'package:alkkagi/screens/free_play_screen.dart';
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
    final l = FontLoader(fam)
      ..addFont(rootBundle.load('assets/fonts/$file.ttf'));
    await l.load();
  }
  // 아이콘 글꼴.
  final mi = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await mi.load().catchError((_) {});
}

bool _cached = false;

Future<void> _shot(
  WidgetTester t,
  Widget w,
  String name, {
  int settleMs = 1600,
  double ratio = 1,
  String dir = 'build/shots',
}) async {
  final key = GlobalKey();
  // 그림을 먼저 모두 풀어 캐시에 넣는다(화면이 그리기 전에 — 시험 환경은 늦게 읽은 그림을 다시 안 그린다).
  if (!_cached) {
    await t.pumpWidget(MaterialApp(home: SizedBox(key: key)));
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
    _cached = true;
  }
  await t.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: w,
      ),
    ),
  );
  for (var i = 0; i < settleMs ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  // 캐릭터·얼굴은 그릴 크기로 줄여 읽어(캐시 열쇠가 원본과 다름) 미리 읽은 원본을 못 쓴다 —
  // 실제 시간을 조금 주어 풀리게 한 뒤 다시 그린다.
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 700)),
  );
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await t.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: ratio);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$dir/$name.png')..createSync(recursive: true);
    f.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  final on = Platform.environment['SHOTS'] == '1';
  final store = Platform.environment['STORE'] == '1';
  setUpAll(() async {
    if (!on && !store) return;
    SharedPreferences.setMockInitialValues({});
    await initializePhysics();
    await _fonts();
    // 그림 42장(장마다 3.6MB 풀림)이 기본 캐시 100MB 를 넘어 밀려나지 않게.
    PaintingBinding.instance.imageCache.maximumSizeBytes = 800 << 20;
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
    await _shot(
      t,
      Scaffold(
        body: ResultOverlay(
          title: '승리!',
          won: true,
          stars: 2,
          coins: 20,
          character: 'yonga',
          onDone: () {},
          onAgain: () {},
        ),
      ),
      'result',
      settleMs: 2200,
    );
    // 규칙 변형(장수전·점수전) 판.
    for (final rule in [MatchRule.general, MatchRule.score]) {
      await _shot(
        t,
        GameScreen(
          config: MatchConfig(mode: MatchMode.twoPlayer, rule: rule),
        ),
        'rule_${rule.name}',
        settleMs: 2000,
      );
    }
    await _shot(t, const FreePlayScreen(), 'free_play');
    await _shot(t, const CampaignScreen(), 'campaign');
    await _shot(
      t,
      DialogueScreen(
        title: campaign[1].title,
        lines: campaign[1].intro,
        scene: 'oilyTable',
      ),
      'dialogue',
      settleMs: 2800,
    );
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
      GameScreen(
        config: lessons[0].config,
        title: lessons[0].title,
        coach: true,
        coachLines: [lessons[0].line],
      ),
      'game_coach',
      settleMs: 2500,
    );
    await _shot(
      t,
      const GameScreen(
        config: MatchConfig(
          mode: MatchMode.vsAi,
          arena: Arena.kubiForest,
          opponentName: '쿠비',
        ),
        title: '4장 · 야성의 숲',
      ),
      'game_vs_intro',
      settleMs: 700,
    );
    await _shot(
      t,
      const GameScreen(
        config: MatchConfig(
          mode: MatchMode.vsAi,
          arena: Arena.oilyTable,
          opponentName: '통통',
        ),
        title: '2장 · 기름진 난장',
      ),
      'game_oily',
      settleMs: 2600,
    );
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  }, skip: !on);

  // 스토어 스크린샷 1080×1920(9:16): STORE=1 flutter test test/shots → ../store/
  testWidgets('스토어 스크린샷', (t) async {
    const w = 412.0, k = 1080 / w, h = 1920 / k;
    t.view.physicalSize = const Size(w * k, h * k);
    t.view.devicePixelRatio = k;
    final p = ProfileStore.instance.profile
      ..hero = Fighter.yonga
      ..tutorialDone = true
      ..coins = 1240
      ..silver = 7
      ..naegong = 180
      ..attendDay = today();
    p.done.addAll(['c1', 'r1', 'c2']);
    p.stars.addAll({'c1': 3, 'r1': 2, 'c2': 3});
    p.seenHints.addAll([
      'campaign',
      'training',
      'arena',
      'wander',
      'shop',
      'stats',
      'puzzle',
    ]);
    const out = '../store';
    await _shot(
      t,
      const HomeScreen(),
      'screenshot-1-lobby',
      ratio: k,
      dir: out,
    );
    await _shot(
      t,
      GameScreen(
        config: lessons[0].config,
        title: lessons[0].title,
        coach: true,
        coachLines: [lessons[0].line],
      ),
      'screenshot-2-tutorial',
      settleMs: 2500,
      ratio: k,
      dir: out,
    );
    await _shot(
      t,
      const GameScreen(
        config: MatchConfig(
          mode: MatchMode.vsAi,
          arena: Arena.oilyTable,
          opponentName: '통통',
        ),
        title: '2장 · 기름진 난장',
      ),
      'screenshot-3-versus',
      // 시작 연출 0.9초 — 사라지기 전(0.74초 전)에 찍는다.
      settleMs: 400,
      ratio: k,
      dir: out,
    );
    await _shot(
      t,
      const CampaignScreen(),
      'screenshot-4-campaign',
      ratio: k,
      dir: out,
    );
    await _shot(
      t,
      DialogueScreen(
        title: campaign[1].title,
        lines: campaign[1].intro,
        scene: 'oilyTable',
      ),
      'screenshot-5-story',
      settleMs: 2800,
      ratio: k,
      dir: out,
    );
    await _shot(
      t,
      Scaffold(
        body: ResultOverlay(
          title: '승리!',
          won: true,
          stars: 3,
          coins: 20,
          character: 'yonga',
          onDone: () {},
          onAgain: () {},
        ),
      ),
      'screenshot-6-victory',
      settleMs: 2200,
      ratio: k,
      dir: out,
    );
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  }, skip: !store);
}
