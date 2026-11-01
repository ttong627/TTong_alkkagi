import 'package:alkkagi/game/flick.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

/// 돌 13종 × 모양 3 실측표 — `flutter test tool/stone_audit.dart` (2026-11-01 형 「돌과 모양에 따른 물리적 법칙 … 재점검」).
/// 형 법칙(10-14·10-19): 단이 높을수록 ①상대에게 맞아도 덜 밀리고 ②내가 친 상대는 더 밀리고
/// ③친 내 돌은 덜 튕긴다.
const _far = 400.0;

double _travel(Stone s, Vector2 from) => (s.position - from).length;

/// 상대(편 1, 둥근 청옥)가 100cm/s 로 정면에서 내 돌을 친다 → 내 돌이 밀린 거리.
double pushedMine(StoneMaterial m, StoneShape s) {
  final t = Table(half: _far);
  try {
    final mine = t.addStone(0, 0, material: m, shape: s);
    final foe = t.addStone(0, 6, team: 1);
    final from = mine.position.clone();
    t.shoot(foe, -1.5707963, 100, 0);
    t.runTurn();
    return _travel(mine, from);
  } finally {
    t.dispose();
  }
}

/// 내 돌이 손끝 가득(120cm/s × 무게 보정)으로 정면에서 둥근 청옥 상대를 친다 →
/// (상대가 밀린 거리, 내 돌이 맞은 뒤 더 간 거리).
(double foe, double recoil) strike(
  StoneMaterial m,
  StoneShape s, {
  StoneMaterial foeMat = StoneMaterial.cheongok,
}) {
  final t = Table(half: _far);
  try {
    final mine = t.addStone(0, 6, material: m, shape: s);
    final foe = t.addStone(0, 0, team: 1, material: foeMat);
    final from = foe.position.clone();
    t.shoot(mine, -1.5707963, 60 * massFactor(stoneMass(m, s)), 0);
    Vector2? hitAt;
    while (t.step() == TurnStatus.moving) {
      if (hitAt == null && t.impacts.isNotEmpty) hitAt = mine.position.clone();
    }
    t.endTurn();
    return (_travel(foe, from), hitAt == null ? 0 : _travel(mine, hitAt));
  } finally {
    t.dispose();
  }
}

void main() {
  setUpAll(initializePhysics);

  test('돌 13종 × 모양 3 실측표', () {
    final byGrade = [...StoneMaterial.values]
      ..sort((a, b) => a.grade - b.grade);
    for (final s in StoneShape.values) {
      // ignore: avoid_print
      print(
        '── ${s.label}: 단 재질 | 무게 | 손끝배수 | 맞아 밀림 | 친 상대 밀림 | 내 튕김 | 현철 상대 밀림',
      );
      for (final m in byGrade) {
        final (foe, recoil) = strike(m, s);
        final (heavy, _) = strike(m, s, foeMat: StoneMaterial.hyeoncheol);
        // ignore: avoid_print
        print(
          '${m.grade.toString().padLeft(2)} ${m.label.padRight(5)} | '
          '${stoneMass(m, s).toStringAsFixed(2)} | '
          '${massFactor(stoneMass(m, s)).toStringAsFixed(2)} | '
          '${pushedMine(m, s).toStringAsFixed(1)} | '
          '${foe.toStringAsFixed(1)} | ${recoil.toStringAsFixed(1)} | '
          '${heavy.toStringAsFixed(1)}',
        );
      }
    }
  });
}
