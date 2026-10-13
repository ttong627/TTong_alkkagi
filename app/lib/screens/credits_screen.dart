import 'package:flutter/material.dart';

import '../ui/kit.dart';
import '../ui/theme.dart';
import '../version.dart';

/// 만든 이 · 쓴 것(설계서 §16.9): 글꼴 저작권 고지(SIL OFL)와 그림·소리 출처.
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) => GameScaffold(
    title: '만든 이',
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OutlinedText(
                '알까기 · 탄지무림',
                size: 28,
                title: true,
                color: Palette.gold,
                align: TextAlign.start,
              ),
              const SizedBox(height: 6),
              const Text('(주)웰쉐어로지스', style: TextStyle(fontSize: 18)),
              Text(versionLabel, style: const TextStyle(color: Palette.dim)),
              const SizedBox(height: 14),
              const Text(
                '그림 · 소리',
                style: TextStyle(
                  fontFamily: titleFont,
                  fontSize: 18,
                  color: Palette.gold,
                ),
              ),
              const Text(
                '캐릭터·배경·아이콘·효과음·국악풍 배경 음악은 모두 이 게임을 위해 코드로 직접 그리고 합성했습니다.',
              ),
              const SizedBox(height: 14),
              const Text(
                '글꼴',
                style: TextStyle(
                  fontFamily: titleFont,
                  fontSize: 18,
                  color: Palette.gold,
                ),
              ),
              const Text(
                'Black Han Sans — Copyright 2015 The Black Han Sans Project Authors',
              ),
              const Text(
                'Do Hyeon — Copyright 2018 The Do Hyeon Project Authors',
              ),
              const Text('SIL Open Font License 1.1'),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: '알까기 · 탄지무림',
                    applicationVersion: versionLabel,
                  ),
                  child: const Text('오픈소스 사용권 전체 보기'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
