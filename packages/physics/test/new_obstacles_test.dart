import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:test/test.dart';

/// 2026-10-28 형 「장애물도 좀더 다양하게」: 유사 · 소용돌이 · 용암 구멍 · 술통 · 구름.
void main() {
  TurnStatus run(Table t) {
    var guard = 0;
    while (t.step() == TurnStatus.moving && guard++ < 3000) {}
    return t.status;
  }

  /// 아래에서 위로 [speed] 로 쏜 돌이 멈춘 자리(판 밖이면 null) · 구역 지물 [f] 가 있을 때.
  ({double x, double y})? shot(Feature? f, {double speed = 32, double x = 0}) {
    final t = Table();
    if (f != null) t.addFeature(f);
    final s = t.addStone(x, 12);
    t.shoot(s, -math.pi / 2, speed, 0);
    run(t);
    final out = s.out ? null : (x: s.position.x, y: s.position.y);
    t.dispose();
    return out;
  }

  test('유사: 지나가는 돌이 크게 느려져 덜 간다 · 부딪히지는 않는다', () {
    final free = shot(null)!;
    final sand = shot(const Feature(FeatureKind.quicksand, 0, 4))!;
    expect(sand.y, greaterThan(free.y + 3), reason: '위(−y)로 덜 갔다');
    expect(sand.x.abs(), lessThan(0.5), reason: '튕겨 나가지 않고 곧게');
  });

  test('소용돌이: 지나가는 돌이 옆으로 휜다', () {
    final free = shot(null)!;
    final whirl = shot(const Feature(FeatureKind.whirlpool, 1, 2))!;
    expect(free.x.abs(), lessThan(0.3));
    expect((whirl.x - free.x).abs(), greaterThan(1.5));
  });

  test('용암 구멍: 한가운데로 지나가면 장외 · 비켜 가면 산다', () {
    expect(shot(const Feature(FeatureKind.lavaPit, 0, 2)), isNull);
    expect(shot(const Feature(FeatureKind.lavaPit, 9, 2)), isNotNull);
    final t = Table();
    t.addFeature(const Feature(FeatureKind.lavaPit, 0, 2));
    final s = t.addStone(0, 12);
    t.shoot(s, -math.pi / 2, 60, 0);
    run(t);
    expect(t.terrainEvents.any((e) => e.fx == TerrainFx.lava), isTrue);
    t.dispose();
  });

  test('멈춘 돌은 구역 지물이 움직이지 않는다(소용돌이·유사 안에 서 있어도)', () {
    final t = Table();
    t.addFeature(const Feature(FeatureKind.whirlpool, 0, 0));
    final s = t.addStone(2, 0);
    for (var i = 0; i < 120; i++) {
      t.step();
    }
    expect(s.position.x, closeTo(2, 1e-6));
    expect(s.position.y, closeTo(0, 1e-6));
    t.dispose();
  });

  test('술통·구름은 바위보다 세게 튕겨 낸다', () {
    double bounce(FeatureKind k) {
      final t = Table();
      t.addFeature(Feature(k, 0, 0));
      final s = t.addStone(0, 8);
      t.shoot(s, -math.pi / 2, 60, 0);
      var guard = 0;
      var best = 0.0;
      while (t.step() == TurnStatus.moving && guard++ < 3000) {
        if (s.velocity.y > best) best = s.velocity.y;
      }
      t.dispose();
      return best;
    }

    final rock = bounce(FeatureKind.rock);
    expect(bounce(FeatureKind.barrel), greaterThan(rock));
    expect(bounce(FeatureKind.cloud), greaterThan(bounce(FeatureKind.barrel)));
  });

  test('구역 지물은 크기가 그 구역 반지름 · 부딪히는 지물이 아니다', () {
    expect(
      const Feature(FeatureKind.quicksand, 0, 0).size,
      TerrainConstants.quicksandRadius,
    );
    expect(
      const Feature(FeatureKind.whirlpool, 0, 0).size,
      TerrainConstants.whirlRadius,
    );
    for (final k in [
      FeatureKind.quicksand,
      FeatureKind.whirlpool,
      FeatureKind.lavaPit,
      FeatureKind.blackHole,
    ]) {
      expect(Feature(k, 0, 0).isZone, isTrue, reason: k.name);
    }
    for (final k in [FeatureKind.barrel, FeatureKind.cloud, FeatureKind.rock]) {
      expect(Feature(k, 0, 0).isZone, isFalse, reason: k.name);
    }
  });
}
