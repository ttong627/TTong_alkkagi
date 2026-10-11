import 'dart:async';

import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/sound.dart';
import 'game/arena.dart';
import 'input/touch_feed.dart';
import 'progress/settings.dart';
import 'progress/store.dart';
import 'screens/home_screen.dart';

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
  unawaited(Sound.init().then((_) => Sound.music(Arena.dustyYard)));
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8A5A2B),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF2B2118),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
