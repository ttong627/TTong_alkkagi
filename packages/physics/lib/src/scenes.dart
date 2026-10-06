import 'dart:math' as math;

import 'constants.dart';
import 'materials.dart';
import 'table.dart';

/// planck.js 시험대(`prototype/physics/measure.js`)와 똑같은 장면들.
/// 측정 재현 시험(체크리스트 1-08)과 측정 스크립트가 같이 쓴다.
abstract final class Scenes {
  /// A. 타격점: 같은 재질 구형 돌, 정면 충돌, 처음 속도 20cm/s.
  /// 반환: (내 돌 최종 x, 표적 최종 x).
  static (double, double) hitPoint(double gap, double hit) {
    final t = Table(minDamping: 0.15);
    final me = t.addStone(-gap, 0, shape: StoneShape.sphere);
    final tg = t.addStone(0, 0, shape: StoneShape.sphere);
    t.shoot(me, 0, 20, hit);
    t.runTurn();
    final r = (me.position.x, tg.position.x);
    t.dispose();
    return r;
  }

  /// B. 재질별: 같은 충격량(60)으로 둥근 돌 혼자 굴림.
  /// 반환: (거리 cm 또는 장외면 null, 시간 초).
  static (double?, double) materialRoll(StoneMaterial m) {
    final t = Table(minDamping: 0.15);
    final s = t.addStone(-PhysicsConstants.halfBoard + 2, 0, material: m);
    final x0 = s.position.x;
    t.shoot(s, 0, 60 / s.body.mass, 0);
    final r = t.runTurn();
    final out = s.out;
    final d = s.position.x - x0;
    t.dispose();
    return (out ? null : d, r.seconds);
  }

  /// B2. 재질별: 같은 속도(30cm/s)로 청옥 표적을 정면으로 침. 반환: 표적 x(장외면 null).
  static double? materialPush(StoneMaterial m) {
    final t = Table(minDamping: 0.15);
    final me = t.addStone(-8, 0, material: m);
    final tg = t.addStone(0, 0);
    t.shoot(me, 0, 30, 0);
    t.runTurn();
    final r = tg.out ? null : tg.position.x;
    t.dispose();
    return r;
  }

  /// B3. 모양별: 청옥, 같은 속도(40cm/s)로 혼자 굴림. 반환: 거리(cm).
  static double shapeRoll(StoneShape shape) {
    final t = Table(minDamping: 0.15);
    final s = t.addStone(-PhysicsConstants.halfBoard + 2, 0, shape: shape);
    final x0 = s.position.x;
    t.shoot(s, 0, 40, 0);
    t.runTurn();
    final d = s.position.x - x0;
    t.dispose();
    return d;
  }

  /// D·E 용 무작위 16알 판(8:8). [seed] 가 같으면 같은 판·같은 한 수.
  static (Table, Stone) randomGame(int seed, {double minDamping = 0.15}) {
    final rand = Lcg(seed);
    final t = Table(minDamping: minDamping);
    const b = PhysicsConstants.board;
    const r = PhysicsConstants.stoneRadius;
    while (t.stones.length < 16) {
      final x = (rand.next() - 0.5) * (b - 6);
      final y =
          (t.stones.length < 8 ? -1 : 1) * (2 + rand.next() * (b / 2 - 5));
      final free = t.stones.every((s) {
        final p = s.position;
        return math.sqrt((p.x - x) * (p.x - x) + (p.y - y) * (p.y - y)) >
            2 * r + 0.3;
      });
      if (free) {
        t.addStone(
          x,
          y,
          material: StoneMaterial.values[(rand.next() * 4).floor()],
          shape: StoneShape.values[(rand.next() * 3).floor()],
          team: t.stones.length < 8 ? 0 : 1,
        );
      }
    }
    final me = t.stones[(rand.next() * 8).floor()];
    t.shoot(
      me,
      math.pi / 2 + (rand.next() - 0.5) * 0.8,
      40 + rand.next() * 80,
      rand.next() * 2 - 1,
    );
    return (t, me);
  }
}

/// measure.js 의 시드 고정 난수와 같은 식.
class Lcg {
  Lcg(int seed) : _s = seed & 0xffffffff;
  int _s;
  double next() {
    _s = (_s * 1664525 + 1013904223) & 0xffffffff;
    return _s / 4294967296;
  }
}
