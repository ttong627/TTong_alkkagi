// 임시(점검용) — 끝나면 지운다.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alkkagi/game/arena.dart';
import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/progress/store.dart';
import 'package:alkkagi/screens/arena_screen.dart';
import 'package:alkkagi/screens/campaign_screen.dart';
import 'package:alkkagi/screens/codex_screen.dart';
import 'package:alkkagi/screens/credits_screen.dart';
import 'package:alkkagi/screens/daily_screen.dart';
import 'package:alkkagi/screens/depot_screen.dart';
import 'package:alkkagi/screens/dialogue_screen.dart';
import 'package:alkkagi/screens/flick_view.dart';
import 'package:alkkagi/screens/free_play_screen.dart';
import 'package:alkkagi/screens/game_screen.dart';
import 'package:alkkagi/screens/hero_pick_screen.dart';
import 'package:alkkagi/screens/home_screen.dart';
import 'package:alkkagi/screens/look_screen.dart';
import 'package:alkkagi/screens/odds_screen.dart';
import 'package:alkkagi/screens/puzzle_screen.dart';
import 'package:alkkagi/screens/settings_screen.dart';
import 'package:alkkagi/screens/shop_screen.dart';
import 'package:alkkagi/screens/stats_screen.dart';
import 'package:alkkagi/screens/training_screen.dart';
import 'package:alkkagi/screens/tutorial_screen.dart';
import 'package:alkkagi/screens/wander_screen.dart';
import 'package:alkkagi/screens/legendary_shop_screen.dart';
import 'package:alkkagi/screens/rebirth_screen.dart';
import 'package:alkkagi/story/chapters.dart';
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
  final mi = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await mi.load().catchError((_) {});
}

bool _cached = false;
final overflows = <String>[];

Future<void> _shot(
  WidgetTester t,
  Widget w,
  String name, {
  int settleMs = 1600,
  double scale = 1.0,
}) async {
  final key = GlobalKey();
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
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: w,
      ),
    ),
  );
  for (var i = 0; i < settleMs ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  final ex = t.takeException();
  if (ex != null) overflows.add('$name: ${ex.toString().split('\n').first}');
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await t.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 1);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('build/shots/adv/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void _fresh({Fighter? hero, bool seen = true}) {
  final s = ProfileStore.instance;
  s.profile = Profile();
  if (hero != null) s.profile.hero = hero;
  if (seen) {
    s.profile.seenHints.addAll([
      'arena',
      'shop',
      'campaign',
      'stats',
      'wander',
      'puzzle',
      'training',
    ]);
  }
  s.profile.tutorialDone = true;
}

void main() {
  final on = Platform.environment['SHOTS'] == '1';
  setUpAll(() async {
    if (!on) return;
    SharedPreferences.setMockInitialValues({});
    await initializePhysics();
    await _fonts();
    PaintingBinding.instance.imageCache.maximumSizeBytes = 800 << 20;
  });

  testWidgets('작은 폰 360x640', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    _fresh(hero: Fighter.seokdu);
    for (final sc in [1.0, 1.3]) {
      final n = sc == 1.0 ? 's' : 'L';
      await _shot(t, const HomeScreen(), 'home_$n', scale: sc);
      await _shot(t, const TutorialScreen(), 'tut_$n', scale: sc);
      await _shot(t, const HeroPickScreen(), 'hero_$n', scale: sc);
      await _shot(t, const CampaignScreen(), 'camp_$n', scale: sc);
      await _shot(t, const ShopScreen(), 'shop_$n', scale: sc);
      await _shot(t, const StatsScreen(), 'stats_$n', scale: sc);
      await _shot(t, const SettingsScreen(), 'settings_$n', scale: sc);
      await _shot(t, const DailyScreen(tab: 1), 'missions_$n', scale: sc);
      await _shot(t, const DailyScreen(tab: 2), 'ach_$n', scale: sc);
      await _shot(t, const ArenaScreen(), 'arena_$n', scale: sc);
      await _shot(t, const WanderScreen(), 'wander_$n', scale: sc);
      await _shot(
        t,
        const TrainingScreen(),
        'train_$n',
        settleMs: 2400,
        scale: sc,
      );
      await _shot(t, const FreePlayScreen(), 'free_$n', scale: sc);
      await _shot(t, const PuzzleScreen(), 'puzzle_$n', scale: sc);
      await _shot(t, const DepotScreen(), 'depot_$n', scale: sc);
      await _shot(t, const LookScreen(), 'look_$n', scale: sc);
      await _shot(t, const OddsScreen(), 'odds_$n', scale: sc);
      await _shot(t, const CreditsScreen(), 'credits_$n', scale: sc);
      await _shot(t, const CodexScreen(), 'codex_$n', scale: sc);
      await _shot(t, const LegendaryShopScreen(), 'legend_$n', scale: sc);
      await _shot(t, const RebirthScreen(), 'rebirth_$n', scale: sc);
      await _shot(
        t,
        DialogueScreen(
          title: campaign[0].title,
          lines: campaign[0].intro,
          scene: 'dustyYard',
        ),
        'dlg_$n',
        settleMs: 3000,
        scale: sc,
      );
      await _shot(
        t,
        GameScreen(
          config: lessons[0].config,
          title: lessons[0].title,
          coach: true,
          coachLines: [lessons[0].line],
        ),
        'coach_$n',
        settleMs: 2500,
        scale: sc,
      );
      await _shot(
        t,
        const GameScreen(
          config: MatchConfig(
            mode: MatchMode.vsAi,
            arena: Arena.dustyYard,
            opponentName: '촌장',
          ),
          title: '1장 · 하산의 길',
        ),
        'game_$n',
        settleMs: 2600,
        scale: sc,
      );
    }
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
    File('build/shots/adv/_overflows.txt')
        .writeAsStringSync(overflows.join('\n'));
  }, skip: !on);
}
