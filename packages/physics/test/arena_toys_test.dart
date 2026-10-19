import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:test/test.dart';

/// 2026-10-20 형 요청: 박살 연쇄 · 담장 되튐 · 회전 기둥 엇나감.
void main() {
  TurnStatus run(Table t) {
    var guard = 0;
    while (t.step() == TurnStatus.moving && guard++ < 3000) {}
    return t.status;
  }

  group('박살(회심 + 정면)', () {
    test('정면으로 맞힌 상대 돌은 박살 · 바싹 붙은 상대 돌도 연쇄로 박살', () {
      final t = Table();
      final me = t.addStone(0, 10);
      final a = t.addStone(0, 0, team: 1);
      final b = t.addStone(0, -2.4, team: 1); // a 바로 뒤에 붙음
      final far = t.addStone(5, -1, team: 1); // 조각에 밀리기만
      t.shoot(me, -math.pi / 2, 120, 0, shatter: true);
      run(t);
      expect(a.out, isTrue);
      expect(b.out, isTrue);
      expect(t.shattered.map((s) => s.chain), containsAll([0, 1]));
      expect(far.out, isFalse);
      t.dispose();
    });

    test('회심이 아니면 박살 없음 · 비껴 맞히면 박살 없음', () {
      final plain = Table();
      final me = plain.addStone(0, 10);
      plain.addStone(0, 0, team: 1);
      plain.shoot(me, -math.pi / 2, 120, 0);
      run(plain);
      expect(plain.shattered, isEmpty);
      plain.dispose();

      final side = Table();
      final me2 = side.addStone(1.8, 10);
      side.addStone(0, 0, team: 1);
      side.shoot(me2, -math.pi / 2, 120, 0, shatter: true);
      run(side);
      expect(side.shattered, isEmpty);
      side.dispose();
    });
  });

  test('담장: 판 밖으로 나가던 돌이 맞고 되튀어 판 안에 남는다', () {
    double go(bool fence) {
      final t = Table();
      if (fence) {
        for (var y = -18.0; y <= 18; y += 6) {
          t.addFeature(
            Feature(
              FeatureKind.fence,
              21 + TerrainConstants.fenceHalfThickness,
              y,
              angle: math.pi / 2,
            ),
          );
        }
      }
      final s = t.addStone(10, 0);
      t.shoot(s, 0, 40, 0);
      run(t);
      final x = s.out ? 99.0 : s.position.x;
      t.dispose();
      return x;
    }

    expect(go(false), 99, reason: '담장이 없으면 장외');
    expect(go(true), lessThan(21), reason: '담장이 있으면 판 안');
  });

  test('회전 기둥: 돌이 움직이는 동안 돈다 · 맞은 돌의 방향이 판마다 달라진다', () {
    const pillar = Feature(FeatureKind.pillar, 0, 0, sides: 6, spin: 2);
    final angles = <double>{};
    for (final seed in [1, 2, 3, 4]) {
      final t = Table(windSeed: seed)..addFeature(pillar);
      final s = t.addStone(0, 10);
      t.shoot(s, -math.pi / 2, 80, 0);
      var guard = 0;
      double? after;
      while (t.step() == TurnStatus.moving && guard++ < 3000) {
        if (after == null &&
            t.terrainEvents.any((e) => e.fx == TerrainFx.pillar)) {
          final v = s.velocity;
          after = math.atan2(v.y, v.x);
        }
      }
      expect(t.clock, greaterThan(0));
      expect(t.poseOf(pillar).$3, isNot(0), reason: '돌았다');
      if (after != null) angles.add((after * 100).roundToDouble());
      t.dispose();
    }
    expect(angles.length, greaterThan(1), reason: '같은 수라도 엇나가는 방향이 다르다');
  });
}
