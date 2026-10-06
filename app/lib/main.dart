import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializePhysics();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const AlkkagiApp());
}

/// 탄지 무림 앱.
class AlkkagiApp extends StatelessWidget {
  const AlkkagiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '탄지 무림',
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
