import 'dart:async';

import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio/sound.dart';
import 'e2e.dart';
import 'input/touch_feed.dart';
import 'progress/settings.dart';
import 'progress/store.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'ui/art.dart';
import 'ui/kit.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializePhysics();
  // 안드로이드: 손끝 점을 빠짐없이·닿은 넓이까지 받는다(돌 맞히기·위아래 타격점).
  TouchFeed.instance.start();
  // 기기에 저장한 진행(캐릭터·내공·재화·강호행)을 읽는다.
  await ProfileStore.load();
  await Settings.load();
  // 소리(효과음·장마다 배경 음악). 준비에 실패해도 게임은 소리 없이 간다.
  // 첫 화면을 기다리게 하지 않도록 뒤에서 준비한다.
  // 손끝 시험판(E2E_FLICK)은 소리를 켜지 않는다 — 소리 장치 없는 CI 에뮬레이터(-noaudio)가 앱이 소리를
  // 해독·재생하는 순간 꺼졌다(2026-10-11 안드로이드 30 기록). 손끝 시험에는 소리가 필요 없다.
  if (!e2eFlick) {
    unawaited(Sound.init());
  }
  // 대전장 바닥·배경 그림(Flame 이 바로 그릴 수 있게 미리 풀어 둔다). 못 읽어도 코드로 그린 바닥으로 간다.
  unawaited(Art.preload());
  // 글꼴 사용권(SIL OFL)을 「오픈소스 사용권」 화면에 싣는다.
  LicenseRegistry.addLicense(() async* {
    for (final f in ['BlackHanSans', 'DoHyeon', 'NotoSansKR']) {
      final text = await rootBundle.loadString('assets/licenses/OFL_$f.txt');
      yield LicenseEntryWithLineBreaks([f], text);
    }
  });
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const AlkkagiApp());
}

/// 탄지무림 앱.
class AlkkagiApp extends StatelessWidget {
  const AlkkagiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '탄지무림 알까기',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      navigatorObservers: [BackSoundObserver()],
      home: e2eFlick ? const HomeScreen() : const SplashScreen(),
    );
  }
}
