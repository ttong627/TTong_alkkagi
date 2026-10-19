import 'package:flutter/material.dart';

import '../game/flick.dart';
import '../game/match.dart';
import '../game/pets.dart';
import '../progress/encounters.dart';
import '../ui/art.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';

/// 확률 안내(설계서 §12.2): 게임 안 모든 확률을 그대로 보여 준다.
/// 한 줄에는 이름과 숫자만, 덧붙일 말은 작은 둘째 줄이나 「?」 안에 둔다.
class OddsScreen extends StatelessWidget {
  const OddsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    String pct(double x) => '${(x * 100).toStringAsFixed(1)}%';
    // (이름, 숫자, 덧붙임).
    final rows = <(String, String, String?)>[
      for (final e in Encounter.values)
        ('기연 · ${e.label}', pct(e.chance), '판당'),
      ('유랑 물음표 칸', '×5', '기연 확률이 5배'),
      ('기인방 효과', '각 20%', legendaryPerks.join(' · ')),
      ('기인방 값', '30~50%', '지금 엽전 기준 · 최소 $legendaryMinPrice'),
      ('기인방 흥정', '50%', '한 번만 · 성공하면 −20%'),
      (
        '회심 일격',
        '실력',
        '한가운데 · 세기 ${(CriticalRule.minPower * 100).round()}~${(CriticalRule.maxPower * 100).round()}%',
      ),
      ('취선', '20%', '회심 때 내공 +1칸 더'),
      ('기인방 「내공 아낌」', '10%', '내공 쓸 때 1칸 돌려받음'),
      ('기인방 「장외 시 기」', '10%', '상대 돌 떨어뜨릴 때 내공 +1칸'),
      (
        '가장자리 기우뚱',
        pct(const MatchConfig(mode: MatchMode.vsAi).edgeTipChance),
        '이번 수에 움직인 돌이 판 끝에 걸쳐 서면(뽀록)',
      ),
      ('회전 기둥', '±34도 · ×0.85~1.4', '맞은 돌이 엇나가는 방향·세기'),
      (
        '영수 날쌘돌',
        '${pct(PetKind.assistChance(1))}~${pct(PetKind.assistChance(PetKind.maxLevel))}',
        '내가 칠 때 함께 튕기기(레벨)',
      ),
    ];
    return GameScaffold(
      background: 'logicMarble',
      appBar: AppBar(
        title: const Text('확률 안내'),
        actions: [
          HelpButton(
            title: '「1판」이란',
            lines: [
              ('campaign', '강호행 1판'),
              ('arena', '투기장 1판'),
              ('training', '목인항 30타'),
              ('wander', '강호유랑 1칸'),
              (
                null,
                '회심 일격은 확률이 아니라 실력이에요(비껴 맞음 ${CriticalRule.maxOffset} 이하).',
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(Art.icon('odds'), width: 36),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    '유료 무작위 상자 없음 · 확률 전부 공개',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17),
                  ),
                ),
              ],
            ),
          ),
          for (final (k, v, note) in rows)
            RowCard(
              title: k,
              sub: note,
              trailing: Text(
                v,
                style: const TextStyle(
                  fontFamily: titleFont,
                  fontFamilyFallback: fallbackFonts,
                  fontSize: 20,
                  color: Palette.gold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
