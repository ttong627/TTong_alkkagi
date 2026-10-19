import 'package:flutter/material.dart';

import '../ui/art.dart';
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
              Text(versionLabel, style: const TextStyle(color: Palette.dim)),
              const SizedBox(height: 14),
              // 만든 곳(2026-10-19 형 「제작자에 웰쉐어로지스와 함께 로고 넣어줘야 해」).
              Container(
                key: const Key('credits-maker'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Image.asset(Art.icon('wslogis'), height: 56),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '제작',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B5B66),
                            ),
                          ),
                          Text(
                            '(주)웰쉐어로지스',
                            style: TextStyle(
                              fontFamily: titleFont,
                              fontSize: 22,
                              color: Color(0xFF2A1830),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                '캐릭터·배경·아이콘 그림과 국악풍 배경 음악은 이 게임만을 위해 AI 도구(코덱스·재미나이)로 만들었고, 효과음은 코드로 합성했습니다.',
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
              const SizedBox(height: 14),
              const Text(
                '개인정보처리방침',
                style: TextStyle(
                  fontFamily: titleFont,
                  fontSize: 18,
                  color: Palette.gold,
                ),
              ),
              const Text('수집하는 개인정보 없음 · 전문:'),
              const SelectableText(
                'https://github.com/ttong627/TTong_alkkagi/blob/main/docs/개인정보처리방침.md',
                style: TextStyle(fontSize: 13, color: Palette.dim),
              ),
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
