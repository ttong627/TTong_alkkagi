import 'package:alkkagi/progress/modes.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('투기장: 연승 배수 ×1 → ×1.5 → ×2 → ×3, 지면 50%', () {
    expect(ArenaRules.winReward(0), 40);
    expect(ArenaRules.winReward(1), 60);
    expect(ArenaRules.winReward(2), 80);
    expect(ArenaRules.winReward(3), 120);
    expect(ArenaRules.winReward(9), 120);
    expect(ArenaRules.onLoss(301), 150);
  });

  test('강호유랑: 같은 주는 같은 지도, 다음 주는 다른 지도 · 월요일 05:00 에 바뀜', () {
    final sunNight = DateTime(2026, 10, 18, 23);
    final monEarly = DateTime(2026, 10, 19, 4, 59);
    final monAfter = DateTime(2026, 10, 19, 5, 1);
    expect(WanderMap.weekOf(sunNight), WanderMap.weekOf(monEarly));
    expect(WanderMap.weekOf(monAfter), isNot(WanderMap.weekOf(monEarly)));
    final a = WanderMap.build('2026-42'), b = WanderMap.build('2026-42');
    expect(a, b);
    expect(a.length, WanderMap.rows);
    expect(a.every((r) => r.length == WanderMap.cols), isTrue);
  });

  test('진기: 6분에 1 · 최대 100 · 모자라면 못 씀', () {
    final p = Profile()
      ..stamina = 5
      ..staminaAt = 1000;
    expect(p.spendStamina(1000, Stamina.cost), isFalse);
    final later = 1000 + 5 * Stamina.regenMs;
    expect(p.staminaNow(later), closeTo(10, 1e-9));
    expect(p.spendStamina(later, Stamina.cost), isTrue);
    expect(p.staminaNow(later), closeTo(0, 1e-9));
    expect(p.staminaNow(later + 1000 * Stamina.regenMs), 100);
  });
}
