import 'dart:math' as math;

/// 투기장(설계서 §8.1): AI 연승전. 이길수록 배수 ×1 → ×1.5 → ×2 → ×3, 지면 모은 것의 50%.
abstract final class ArenaRules {
  static const int base = 40;
  static const int entryCoins = 20;
  static const multipliers = [1.0, 1.5, 2.0, 3.0];

  /// [streak] 번 이긴 뒤 다음 판을 이기면 더해지는 엽전.
  static int winReward(int streak) =>
      (base * multipliers[math.min(streak, multipliers.length - 1)]).round();

  /// 지면 받는 몫.
  static int onLoss(int pot) => pot ~/ 2;
}

/// 강호유랑 칸 종류(설계서 §8.4).
enum WanderNode {
  battle('전투', '고수와 한 판 — 이기면 엽전 50'),
  village('마을', '쉬어 가기 — 진기 +15 · 엽전 +20'),
  mystery('물음표', '무슨 일이 생길지 모른다 — 기연 확률 ×5'),
  wagon('수레 객잔', '이동 상점 — 진기 +30 · 특산물 흥정');

  const WanderNode(this.label, this.help);
  final String label;
  final String help;
}

/// 강호유랑 한 주 지도: 6줄 × 3칸. 매주 월요일 05:00 에 새로 만든다(주 번호로 같은 지도).
abstract final class WanderMap {
  static const int rows = 6;
  static const int cols = 3;

  /// 이번 주 번호(월요일 05:00 기준, yyyy-ww).
  static String weekOf(DateTime now) {
    final shifted = now.subtract(const Duration(hours: 5));
    final monday = DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
    ).subtract(Duration(days: shifted.weekday - 1));
    final firstMonday = DateTime(monday.year, 1, 1);
    final week = monday.difference(firstMonday).inDays ~/ 7 + 1;
    return '${monday.year}-$week';
  }

  /// 그 주의 지도.
  static List<List<WanderNode>> build(String week) {
    final r = math.Random(week.hashCode);
    return [
      for (var row = 0; row < rows; row++)
        [
          for (var c = 0; c < cols; c++)
            switch (r.nextDouble()) {
              < 0.5 => WanderNode.battle,
              < 0.7 => WanderNode.village,
              < 0.9 => WanderNode.mystery,
              _ => WanderNode.wagon,
            },
        ],
    ];
  }
}
