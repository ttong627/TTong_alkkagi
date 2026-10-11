import 'package:flutter/material.dart';

import '../game/flick.dart';
import '../progress/encounters.dart';

/// 확률 안내(설계서 §12.2): 게임 안 모든 확률을 그대로 보여 준다.
class OddsScreen extends StatelessWidget {
  const OddsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    String pct(double x) => '${(x * 100).toStringAsFixed(1)}%';
    final rows = <(String, String)>[
      ('「1판」이란', '강호행 1판 · 투기장 1판 · 목인항 30타 · 강호유랑 1칸'),
      for (final e in Encounter.values)
        ('기연 · ${e.label}', '판당 ${pct(e.chance)}'),
      ('강호유랑 물음표 칸', '위 기연 확률 ×5'),
      ('기인방 특수효과', '${legendaryPerks.join(' · ')} 중 하나, 각 20% (사기 전에 보임)'),
      ('기인방 값', '지금 엽전의 30~50% (최소 50)'),
      ('기인방 흥정', '한 번, 성공 50% · 성공하면 −20%'),
      (
        '회심 일격',
        '확률이 아니라 실력: 한가운데(비껴 맞음 ≤ ${CriticalRule.maxOffset}) · 세기 ${(CriticalRule.minPower * 100).round()}~${(CriticalRule.maxPower * 100).round()}%',
      ),
      ('취선', '회심 때 20% 로 내공 +1칸 더'),
      ('기인방 「내공 아낌」', '내공을 쓸 때 10% 로 1칸 돌려받음'),
      ('기인방 「장외 시 기」', '상대 돌을 떨어뜨릴 때마다 10% 로 내공 +1칸'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('확률 안내')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('유료로 사는 무작위 상자는 없습니다. 모든 확률을 여기에 그대로 적습니다.'),
          const SizedBox(height: 8),
          for (final (k, v) in rows)
            Card(
              child: ListTile(title: Text(k), subtitle: Text(v)),
            ),
        ],
      ),
    );
  }
}
