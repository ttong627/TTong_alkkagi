import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'home_screen.dart';

/// 켤 때 화면(설계서 §16.9): 제목 · 두 무인 · 한 줄 비결. 그림을 미리 풀어 두는 동안 1.6초.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// 짧은 비결(로딩 팁) — 한 줄만.
  static const tips = [
    '돌 가운데를 맞히면 곧게, 가장자리를 맞히면 비스듬히 나간다.',
    '빠르게 튕길수록 세다. 살살 밀어도 나간다.',
    '회심 일격이 터지면 내공 구슬이 찬다.',
    '목인항은 하루 처음 30타가 내공 3배!',
    '두 개를 한 번에 떨어뜨리면 일타쌍피 엽전.',
    '매일 출석하면 7일째 상자가 열린다.',
    '판마다 별 셋 — 내 돌을 하나도 안 잃으면 된다.',
  ];

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();
  final _tip = SplashScreen.tips[math.Random().nextInt(SplashScreen.tips.length)];

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((st) {
      if (st == AnimationStatus.completed && mounted) {
        Navigator.of(context).pushReplacement(gameRoute<void>(const HomeScreen()));
      }
    });
    // 그림을 미리 디코드해 두면 로비가 깜빡이지 않는다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final id in ['seokdu', 'yeonbi', 'cheongmyeong', 'sabu']) {
        unawaited(precacheImage(AssetImage(Art.character(id)), context));
      }
      unawaited(precacheImage(AssetImage(Art.background('lobby')), context));
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SceneBackground(
        asset: Art.background('lobby'),
        dim: 0.2,
        motes: Motes.petals,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final v = _c.value;
              final title = Curves.elasticOut.transform((v / 0.6).clamp(0, 1));
              return Column(
                children: [
                  const Spacer(flex: 2),
                  Transform.scale(
                    scale: 0.5 + 0.5 * title,
                    child: const OutlinedText('탄지무림', size: 72, title: true, color: Palette.gold),
                  ),
                  Opacity(
                    opacity: (v * 2).clamp(0, 1),
                    child: const OutlinedText('손끝으로 펼치는 무협 알까기', size: 20),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.translate(
                        offset: Offset(-80 * (1 - Curves.easeOut.transform(v)), 0),
                        child: const CharacterSprite(id: 'yeonbi', height: 220),
                      ),
                      Transform.translate(
                        offset: Offset(80 * (1 - Curves.easeOut.transform(v)), 0),
                        child: const CharacterSprite(id: 'seokdu', height: 220, flip: true),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: v,
                        minHeight: 8,
                        color: Palette.gold,
                        backgroundColor: Colors.black38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: OutlinedText('비결 · $_tip', size: 16),
                  ),
                  const SizedBox(height: 28),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
