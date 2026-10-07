import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:test/test.dart';

/// planck.js 시험대 값(prototype/physics/RESULTS.txt)과 ±15% 비교.
/// 기준값이 소수 첫째 자리로 적혀 있어 반올림 폭 0.05cm 를 더한다.
Matcher within15(double ref) => inInclusiveRange(
  ref - (0.15 * ref.abs() + 0.05),
  ref + (0.15 * ref.abs() + 0.05),
);

void main() {
  setUpAll(initializePhysics);

  group('1-02 장외 판정', () {
    test('돌 중심이 판 밖으로 나가면 탈락하고 움직이지 않는다', () {
      final t = Table();
      final s = t.addStone(19, 0);
      t.shoot(s, 0, 60, 0);
      t.runTurn();
      expect(s.out, isTrue);
      expect(s.body.isEnabled, isFalse);
      expect(s.position.x, greaterThan(PhysicsConstants.halfBoard));
      t.dispose();
    });
    test('판 안에서 멈추면 탈락이 아니다', () {
      final t = Table();
      final s = t.addStone(0, 0);
      t.shoot(s, 0, 10, 0);
      t.runTurn();
      expect(s.out, isFalse);
      t.dispose();
    });
  });

  group('대전장: 판 모양 · 바닥 감속 배수', () {
    test('둥근 판은 모서리 쪽이 장외, 네모 판은 안', () {
      // (17, 17): 중심에서 24cm — 둥근 판(반지름 21) 밖, 네모 판(±21) 안.
      expect(Boundary.circle.isOut(17, 17), isTrue);
      expect(Boundary.square.isOut(17, 17), isFalse);
      expect(Boundary.circle.edgeDistance(0, 0), PhysicsConstants.halfBoard);
      expect(Boundary.square.edgeDistance(20, 0), closeTo(1, 1e-9));
    });
    test('둥근 판에서 대각선으로 나가면 장외', () {
      final t = Table(boundary: Boundary.circle);
      final s = t.addStone(12, 12);
      t.shoot(s, math.pi / 4, 60, 0);
      t.runTurn();
      expect(s.out, isTrue);
      expect(s.position.length, greaterThan(PhysicsConstants.halfBoard));
      t.dispose();
    });
    test('바닥 배수: 감속에 곱하고 하한 0.3 은 지킨다', () {
      final dirt = Table(floorFactor: 1.4);
      final oil = Table(floorFactor: 0.5);
      expect(
        dirt.dampingOf(StoneMaterial.cheongok, StoneShape.round),
        closeTo(1.68, 1e-9),
      );
      expect(oil.dampingOf(StoneMaterial.cheongok, StoneShape.round), 0.6);
      expect(oil.dampingOf(StoneMaterial.ice, StoneShape.round), 0.3);
      dirt.dispose();
      oil.dispose();
    });
    test('같은 속도면 미끄러운 바닥에서 더 멀리 간다', () {
      double roll(double f) {
        final t = Table(floorFactor: f);
        final s = t.addStone(-18, 0);
        t.shoot(s, 0, 30, 0);
        t.runTurn();
        final d = s.position.x + 18;
        t.dispose();
        return d;
      }

      final dirt = roll(1.4), plain = roll(1.0), oil = roll(0.6);
      expect(dirt, lessThan(plain));
      expect(plain, lessThan(oil));
    });
  });

  group('1-03 감속 하한 0.3', () {
    test('빙백한옥(0.15)도 실제 감속은 0.3', () {
      final t = Table();
      expect(t.dampingOf(StoneMaterial.ice, StoneShape.round), 0.3);
      expect(t.dampingOf(StoneMaterial.ice, StoneShape.sphere), 0.3);
      final s = t.addStone(0, 0, material: StoneMaterial.ice);
      expect(s.body.linearDamping, closeTo(0.3, 1e-6));
      t.dispose();
    });
    test('하한보다 큰 감속은 재질 × 모양 그대로', () {
      final t = Table();
      expect(
        t.dampingOf(StoneMaterial.hyeoncheol, StoneShape.flat),
        closeTo(2.6, 1e-9),
      );
      t.dispose();
    });
  });

  group('1-04 10초 강제 정지 · 멈춤 0.5cm/s', () {
    test('감속 0이면 600스텝에서 강제로 멈춘다', () {
      final t = Table(minDamping: 0);
      final s = t.addStone(0, 0, material: StoneMaterial.ice);
      s.body.linearDamping = 0;
      t.shoot(s, 0, 1.2, 0);
      final r = t.runTurn();
      expect(r.timedOut, isTrue);
      expect(r.steps, PhysicsConstants.maxTurnSteps);
      expect(s.velocity.length, 0);
      t.dispose();
    });
    test('멈춤 판정 뒤 모든 돌 속도는 0.5cm/s 이하', () {
      final t = Table();
      final s = t.addStone(0, 0);
      t.shoot(s, 0.3, 50, 0);
      final r = t.runTurn();
      expect(r.timedOut, isFalse);
      for (final x in t.stones.where((x) => !x.out)) {
        expect(
          x.velocity.length,
          lessThanOrEqualTo(PhysicsConstants.restSpeed),
        );
      }
      t.dispose();
    });
  });

  group('1-05 회전 모델', () {
    test('회전량 = 타격점 × 모양 회전 효율, 1초에 1/e 로 준다', () {
      final t = Table();
      final s = t.addStone(-15, 0, shape: StoneShape.round);
      t.shoot(s, 0, 20, 1);
      expect(s.spin, closeTo(0.7, 1e-12));
      for (var i = 0; i < 60; i++) {
        t.step();
      }
      expect(s.spin, closeTo(0.7 * math.exp(-1), 1e-9));
      t.dispose();
    });
    test('충돌이 없으면 회전 보정이 없다(상·하 같은 거리)', () {
      double roll(double hit) {
        final t = Table();
        final s = t.addStone(-15, 0);
        t.shoot(s, 0, 30, hit);
        t.runTurn();
        final x = s.position.x;
        t.dispose();
        return x;
      }

      expect(roll(1), closeTo(roll(-1), 1e-9));
    });
  });

  group('1-06·1-07 재질·모양 값 표(설계서 §3.5·§3.6)', () {
    test('재질 4종', () {
      expect(
        [
          for (final m in StoneMaterial.values)
            (m.density, m.damping, m.restitution),
        ],
        [
          (1.0, 1.2, 0.85),
          (0.5, 0.9, 0.80),
          (2.5, 2.0, 0.75),
          (1.0, 0.15, 0.95),
        ],
      );
    });
    test('모양 3종', () {
      expect(
        [
          for (final s in StoneShape.values)
            (s.dampingMultiplier, s.spinEfficiency),
        ],
        [(1.3, 0.4), (1.0, 0.7), (0.7, 1.0)],
      );
    });
  });

  group('1-08 측정 재현(planck.js ±15%)', () {
    test('§3.3 타격점 상·중·하', () {
      final ref = {
        (8.0, 1.0): (5.2, 16.1),
        (8.0, 0.0): (-0.9, 16.1),
        (8.0, -1.0): (-7.0, 16.1),
        (20.0, 1.0): (-1.3, 5.0),
        (20.0, 0.0): (-1.8, 5.0),
        (20.0, -1.0): (-2.3, 5.0),
      };
      ref.forEach((k, v) {
        final (me, tg) = Scenes.hitPoint(k.$1, k.$2);
        expect(me, within15(v.$1), reason: '표적 ${k.$1}cm 타격 ${k.$2} 내 돌');
        expect(tg, within15(v.$2), reason: '표적 ${k.$1}cm 타격 ${k.$2} 표적');
      });
    });
    test('§3.5 같은 힘으로 혼자 굴림', () {
      final ref = {
        StoneMaterial.cheongok: 12.7,
        StoneMaterial.wood: 34.5,
        StoneMaterial.hyeoncheol: 2.9,
      };
      ref.forEach(
        (m, d) =>
            expect(Scenes.materialRoll(m).$1, within15(d), reason: m.label),
      );
      expect(
        Scenes.materialRoll(StoneMaterial.ice).$1,
        isNull,
        reason: '빙백한옥은 판 밖으로',
      );
    });
    test('§3.5 같은 속도로 표적을 침', () {
      final ref = {
        StoneMaterial.cheongok: 17.3,
        StoneMaterial.wood: 12.3,
        StoneMaterial.hyeoncheol: 19.8,
      };
      ref.forEach(
        (m, d) => expect(Scenes.materialPush(m), within15(d), reason: m.label),
      );
      expect(
        Scenes.materialPush(StoneMaterial.ice),
        isNull,
        reason: '설계서 §3.5: 빙백한옥은 판 밖으로 밀어냄',
      );
    });
    test('§3.6 모양별 거리', () {
      final ref = {
        StoneShape.flat: 25.3,
        StoneShape.round: 32.9,
        StoneShape.sphere: 40.0,
      };
      ref.forEach(
        (s, d) => expect(Scenes.shapeRoll(s), within15(d), reason: s.label),
      );
    });
  });

  test('1-09 결정성: 같은 입력 200판 두 번 계산 → 200/200 같음', () {
    var same = 0;
    for (var i = 0; i < 200; i++) {
      String snap() {
        final (t, _) = Scenes.randomGame(5000 + i);
        t.runTurn();
        final s = t.stones
            .map((s) => '${s.position.x},${s.position.y},${s.out}')
            .join(';');
        t.dispose();
        return s;
      }

      if (snap() == snap()) same++;
    }
    expect(same, 200);
  });
}
