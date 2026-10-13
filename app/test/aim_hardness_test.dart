import 'package:alkkagi/game/ai.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

StoneData _s(StoneShape shape, {int team = 0, bool out = false}) =>
    (x: 0, y: 0, team: team, material: 0, shape: shape.index, out: out);

void main() {
  // 2026-10-14 형 「둥글수록 … 상대가 잘 맞추지 못하고」.
  test('둥글수록 AI 가 겨누기 어렵다: 납작 1 · 둥근 1.15 · 구형 1.4', () {
    expect(aimHardness([_s(StoneShape.flat)], 0), 1);
    expect(aimHardness([_s(StoneShape.round)], 0), 1.15);
    expect(aimHardness([_s(StoneShape.sphere)], 0), 1.4);
  });

  test('노리는 편의 살아 있는 돌만 센다', () {
    final stones = [
      _s(StoneShape.sphere),
      _s(StoneShape.flat, out: true),
      _s(StoneShape.flat, team: 1),
    ];
    expect(aimHardness(stones, 0), 1.4);
    expect(aimHardness(stones, 1), 1);
    expect(aimHardness(const [], 0), 1);
  });
}
