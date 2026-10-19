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

  // 2026-10-14 점검: 「처음부터」 뒤 옛 판 그리기가 치운 Box2D 세계를 읽어 앱이 꺼졌다(세계 칸이 0 으로 비워짐).
  test('치운 판: 돌 위치는 마지막 값 · 빠르기 0 · 진행 안 함 · 두 번 치워도 됨', () {
    final t = Table();
    final s = t.addStone(1, 2);
    t.shoot(s, 0, 50, 0);
    t.step();
    final at = s.position.clone();
    t.dispose();
    expect(t.disposed, isTrue);
    expect(s.position.x, closeTo(at.x, 1e-9));
    expect(s.position.y, closeTo(at.y, 1e-9));
    expect(s.velocity.length, 0);
    expect(t.step(), TurnStatus.idle);
    t.dispose();
  });

  test('숫자가 아닌 값(NaN·무한대)으로 쏴도 판이 깨지지 않는다', () {
    final t = Table();
    final s = t.addStone(0, 0);
    t.shoot(s, double.nan, double.infinity, double.nan);
    t.runTurn();
    expect(s.position.x.isFinite && s.position.y.isFinite, isTrue);
    t.dispose();
  });

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
      final t = Table(settle: false);
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
      final t = Table(minDamping: 0, settle: false);
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
    test('재질 13종 · 처음 4종 값은 그대로(측정 재현)', () {
      expect(StoneMaterial.values.length, 13);
      expect(
        [
          for (final m in StoneMaterial.values.take(4))
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

    // 2026-10-14 형 「좋은 재질의 돌일수록 반탄력이 작아야 해 … 종류와 단계를 10여 가지 이상」.
    test('등급 1~13단이 하나씩 · 등급이 오를수록 반발과 맞았을 때 남는 빠르기가 줄어든다', () {
      final byGrade = [...StoneMaterial.values]
        ..sort((a, b) => a.grade - b.grade);
      expect(
        [for (final m in byGrade) m.grade],
        [for (var g = 1; g <= 13; g++) g],
      );
      for (var k = 1; k < byGrade.length; k++) {
        expect(
          byGrade[k].gameRestitution,
          lessThan(byGrade[k - 1].gameRestitution),
        );
        expect(byGrade[k].hitKeep, lessThan(byGrade[k - 1].hitKeep));
      }
      expect(StoneMaterial.cheongok.hitKeep, 1);
      expect(StoneMaterial.taegeuk.hitKeep, closeTo(0.52, 1e-9));
      expect(StoneMaterial.values.where((m) => m.shard).length, 3);
    });

    test('같은 힘으로 맞아도 높은 등급 돌일수록 덜 밀린다(맞은 직후 빠르기)', () {
      double kicked(StoneMaterial m) {
        // 등급 값만 본다(둘이 하기 규칙 — 내 편 미끄럼 보정 없이).
        final t = Table(favoredTeam: null);
        final me = t.addStone(0, 10);
        final tg = t.addStone(0, 0, material: m, shape: StoneShape.flat);
        t.shoot(me, -math.pi / 2, 30, 0);
        var guard = 0;
        while (t.impacts.isEmpty && guard++ < 600) {
          t.step();
        }
        final v = tg.velocity.length;
        t.dispose();
        return v;
      }

      // 같은 무게(청옥 1.0 · 빙백한옥 1.0)끼리 비교하면 등급 차이만 남는다(6단 → 0.8).
      expect(
        kicked(StoneMaterial.ice),
        closeTo(
          kicked(StoneMaterial.cheongok) * StoneMaterial.ice.hitKeep,
          0.5,
        ),
      );
      expect(
        kicked(StoneMaterial.ice),
        lessThan(kicked(StoneMaterial.cheongok)),
      );
    });

    // 2026-10-14 형 「내가 깐 공에 상대방은 잘 밀려야 하고 내 등급이 올라갈수록 상대는 잘 밀리고
    // 내 돌은 움직임이 작아져야 해」 — 친 돌과 맞은 돌의 등급 차이로 정한다.
    test('등급 차이: 높은 단이 치면 더 밀리고, 높은 단은 덜 밀린다(한 단에 4% · 0.5~1.5)', () {
      const c = StoneMaterial.cheongok, t13 = StoneMaterial.taegeuk;
      expect(c.pushedBy(c), 1);
      expect(c.pushedBy(t13), closeTo(1.48, 1e-9));
      expect(t13.pushedBy(c), closeTo(0.52, 1e-9));
      expect(StoneMaterial.ice.pushedBy(c), StoneMaterial.ice.hitKeep);
      for (final a in StoneMaterial.values) {
        for (final b in StoneMaterial.values) {
          expect(b.pushedBy(a), inInclusiveRange(0.5, 1.5));
        }
      }
    });

    // 2026-10-14 점검: 더 밀기가 연쇄 충돌마다 곱해져 줄 끝 돌이 3배 넘게 날아갔다.
    test('더 밀기는 쏜 돌이 직접 맞힌 돌에만 — 줄 끝 돌이 불어나지 않는다', () {
      final t = Table();
      final me = t.addStone(
        0,
        6.75,
        material: StoneMaterial.taegeuk,
        shape: StoneShape.flat,
      );
      final row = [
        for (var k = 0; k < 4; k++)
          t.addStone(0, 4.5 - k * 2.25, shape: StoneShape.flat),
      ];
      const v = 60.0;
      t.shoot(me, -math.pi / 2, v, 0);
      var top = 0.0;
      var guard = 0;
      while (t.step() == TurnStatus.moving && guard++ < 600) {
        top = math.max(top, row.last.velocity.length);
      }
      t.dispose();
      expect(top, lessThan(v * 1.8), reason: '줄 끝 돌 최고 빠르기 $top');
    });

    /// 붙여 놓고 쳐서(굴러가는 동안의 감속 차이를 없앰) 맞은 직후 (맞은 돌, 쏜 돌) 빠르기.
    (double, double) kick(
      StoneMaterial shooter,
      StoneMaterial target, {
      int shooterTeam = 0,
      int targetTeam = 1,
      int? favored = 0,
    }) {
      final t = Table(favoredTeam: favored);
      final me = t.addStone(
        0,
        2.4,
        material: shooter,
        shape: StoneShape.flat,
        team: shooterTeam,
      );
      final tg = t.addStone(
        0,
        0,
        material: target,
        shape: StoneShape.flat,
        team: targetTeam,
      );
      t.shoot(me, -math.pi / 2, 30, 0);
      var guard = 0;
      while (t.impacts.isEmpty && guard++ < 600) {
        t.step();
      }
      final v = (tg.velocity.length, me.velocity.length);
      t.dispose();
      return v;
    }

    const c = StoneMaterial.cheongok;

    test('둘이 하기(우대 편 없음): 같은 무게라도 높은 등급 돌로 치면 더 밀린다', () {
      // 청옥 1.0 · 빙백한옥 1.0 — 무게가 같고 6단이 친다 → 1 + 0.04 × 5 = 1.2배.
      final base = kick(c, c, favored: null).$1;
      expect(
        kick(StoneMaterial.ice, c, favored: null).$1,
        closeTo(base * 1.2, base * 0.05),
      );
    });

    test('내 돌로 친 상대 돌은 내 등급이 높을수록 더 밀린다(1단 ×1.2 → 13단 ×1.8)', () {
      final even = kick(c, c, favored: null).$1;
      expect(kick(c, c).$1, closeTo(even * 1.2, even * 0.05));
      // 빙백한옥(6단)도 무게 1.0 — 1.2 + 0.05 × 5 = 1.45배.
      expect(kick(StoneMaterial.ice, c).$1, closeTo(even * 1.45, even * 0.05));
      expect(StoneMaterial.taegeuk.strikeBoost, closeTo(1.8, 1e-9));
    });

    test('무거운 상대 돌(현철)도 내 돌에 맞으면 같은 무게를 친 만큼 이상 밀린다', () {
      final even = kick(c, c, favored: null).$1;
      final before = kick(c, StoneMaterial.hyeoncheol, favored: null).$1;
      final now = kick(c, StoneMaterial.hyeoncheol).$1;
      expect(before, lessThan(even * 0.7), reason: '무게 탓에 덜 밀리던 것');
      expect(now, greaterThan(even * 1.1));
    });

    test('상대 돌에 맞은 내 돌은 무게 이득 없이 내 등급만큼 덜 밀린다', () {
      final even = kick(c, c, favored: null).$1;
      double hitMine(StoneMaterial mine) => kick(
        StoneMaterial.hyeoncheol,
        mine,
        shooterTeam: 1,
        targetTeam: 0,
      ).$1;
      expect(hitMine(c), lessThanOrEqualTo(even * 1.05));
      // 빙백한옥(6단 · 무게 1.0): 등급 0.8 × 미끄럼 보정(감속이 청옥보다 작아 더 줄임).
      expect(hitMine(StoneMaterial.ice), lessThanOrEqualTo(even * 0.82));
    });

    test('상대 돌에 맞은 내 돌이 밀려난 거리: 13단은 1단의 3분의 2 아래 · 금강석도 청옥보다 덜', () {
      double pushed(StoneMaterial mine) {
        final t = Table();
        final foe = t.addStone(
          0,
          12,
          material: StoneMaterial.hyeoncheol,
          team: 1,
        );
        final me = t.addStone(0, 0, material: mine);
        final start = me.position.clone();
        t.shoot(foe, -math.pi / 2, 50, 0);
        var guard = 0;
        while (t.step() == TurnStatus.moving && guard++ < 3000) {}
        final d = (me.position - start).length;
        t.dispose();
        return d;
      }

      final low = pushed(c);
      expect(pushed(StoneMaterial.taegeuk), lessThan(low * 2 / 3));
      expect(pushed(StoneMaterial.diamond), lessThan(low));
    });

    test('내 쏜 돌은 상대 쏜 돌보다 덜 튕긴다', () {
      final mine = kick(c, StoneMaterial.hyeoncheol).$2;
      final theirs = kick(
        c,
        StoneMaterial.hyeoncheol,
        shooterTeam: 1,
        targetTeam: 0,
      ).$2;
      expect(mine, lessThan(theirs * 0.75));
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

  group('1-10 높이(2026-10-11): 아래를 맞으면 떠서 날고, 위를 맞으면 튀어 오른다', () {
    test('문턱 안쪽(|타격점| ≤ 0.5)은 뜨지 않고, ±1 이면 35° 로 들린다', () {
      expect(Table.liftOf(100, 0.5), (100.0, 0.0));
      expect(Table.liftOf(100, -0.5), (100.0, 0.0));
      final a = 35 * math.pi / 180;
      final (al, up) = Table.liftOf(100, -1);
      expect(al, closeTo(100 * math.cos(a), 1e-9));
      expect(up, closeTo(100 * math.sin(a), 1e-9));
      final (al2, up2) = Table.liftOf(100, 1);
      expect(al2, closeTo(100 * math.cos(a), 1e-9));
      expect(up2, closeTo(100 * math.sin(a) * 0.4, 1e-9), reason: '바닥 반발 0.4');
    });

    test('lift 를 끄면(기본) 예전과 똑같이 회전만 준다', () {
      final t = Table();
      final s = t.addStone(-15, 0);
      t.shoot(s, 0, 30, -1);
      expect(s.airborne, isFalse);
      t.dispose();
    });

    double hitTarget({required bool lift}) {
      final t = Table();
      final me = t.addStone(-10, 0);
      final tg = t.addStone(-4, 0);
      t.shoot(me, 0, 120, -1, lift: lift);
      var maxZ = 0.0;
      while (t.step() == TurnStatus.moving) {
        maxZ = math.max(maxZ, me.z);
      }
      final moved = tg.position.x - -4;
      t.dispose();
      return lift ? (maxZ > 2 ? moved : double.nan) : moved;
    }

    test('아래를 세게 맞아 떠서 날면 가까운 돌 위를 넘어간다(표적이 안 움직임)', () {
      expect(hitTarget(lift: false), greaterThan(5), reason: '안 뜨면 표적을 친다');
      expect(hitTarget(lift: true).abs(), lessThan(1e-6));
    });

    test('위를 맞으면 살짝 튀었다(뜬 높이 < 1cm) 바닥에 붙어 미끄러진다', () {
      final t = Table();
      final s = t.addStone(-20, 0);
      t.shoot(s, 0, 40, 1, lift: true);
      var maxZ = 0.0;
      var landed = -1;
      while (t.step() == TurnStatus.moving) {
        maxZ = math.max(maxZ, s.z);
        if (landed < 0 && !s.airborne) landed = t.turnSteps;
      }
      expect(maxZ, greaterThan(0));
      expect(maxZ, lessThan(1));
      expect(landed, greaterThan(0));
      expect(s.out, isFalse);
      t.dispose();
    });

    test('판 밖 위로 날아가면 떨어진 뒤에 장외가 된다', () {
      final t = Table();
      final s = t.addStone(15, 0);
      t.shoot(s, 0, 150, -1, lift: true);
      var outWhileFlying = false;
      while (t.step() == TurnStatus.moving) {
        if (s.airborne && s.out) outWhileFlying = true;
      }
      expect(outWhileFlying, isFalse);
      expect(s.out, isTrue);
      expect(s.airborne, isFalse);
      t.dispose();
    });

    test('충돌에도 부피가 든다: 구형(무거운) 돌로 치면 둥근 돌로 칠 때보다 멀리 밀어낸다', () {
      double push(StoneShape shape) {
        final t = Table();
        final me = t.addStone(-8, 0, shape: shape);
        final tg = t.addStone(0, 0);
        t.shoot(me, 0, 30, 0);
        t.runTurn();
        final x = tg.position.x;
        t.dispose();
        return x;
      }

      expect(push(StoneShape.sphere), greaterThan(push(StoneShape.round)));
      expect(push(StoneShape.round), greaterThan(push(StoneShape.flat)));
    });

    test('무게 = 재질 밀도 × 모양 부피', () {
      expect(stoneMass(StoneMaterial.cheongok, StoneShape.round), 2.43);
      expect(
        stoneMass(StoneMaterial.hyeoncheol, StoneShape.sphere),
        closeTo(2.5 * 5.58, 1e-9),
      );
      expect(
        stoneMass(StoneMaterial.wood, StoneShape.flat),
        closeTo(0.5 * 1.90, 1e-9),
      );
    });
  });

  group('1-11 내공 타격·무공·스킬 (설계서 §2.4·§2.6·§3.9)', () {
    test('내공 타격: 처음 속도 ×1.3(상한 180), 첫 충돌로 맞은 돌이 더 밀린다', () {
      final t = Table();
      final s = t.addStone(-15, 0);
      t.shoot(s, 0, 100, 0, inner: true);
      expect(s.velocity.x, closeTo(130, 1e-6));
      t.dispose();
      final t2 = Table();
      final s2 = t2.addStone(-15, 0);
      t2.shoot(s2, 0, 160, 0, inner: true);
      expect(s2.velocity.x, closeTo(180, 1e-6));
      t2.dispose();

      (double, List<TechniqueFx>) push({required bool inner}) {
        final t = Table();
        final me = t.addStone(-8, 0);
        final tg = t.addStone(0, 0);
        t.shoot(me, 0, inner ? 30 / 1.3 : 30, 0, inner: inner);
        final fx = <TechniqueFx>[];
        while (t.step() == TurnStatus.moving) {
          fx.addAll(t.events.map((e) => e.fx));
        }
        final x = tg.position.x;
        t.dispose();
        return (x, fx);
      }

      final (plain, _) = push(inner: false);
      final (strong, fx) = push(inner: true);
      expect(fx, contains(TechniqueFx.innerImpact));
      expect(
        strong,
        greaterThan(plain * 1.15),
        reason: '같은 처음 속도에서 맞은 돌 ×1.25',
      );
    });

    double shooterAfter(Technique tech) {
      final t = Table();
      final me = t.addStone(-8, 0);
      t.addStone(0, 0.6);
      t.shoot(me, 0, 30, 0, inner: true, technique: tech);
      t.runTurn();
      final x = me.position.x;
      t.dispose();
      return x;
    }

    test('검기: 첫 충돌 뒤 내 돌 감속 −40% 로 더 밀고 나간다', () {
      expect(
        shooterAfter(Technique.swordQi),
        greaterThan(shooterAfter(Technique.none)),
      );
    });

    test('진각: 충돌 지점 4cm 안의 다른 돌이 바깥으로 밀린다', () {
      double side({required Technique tech}) {
        final t = Table();
        final me = t.addStone(-8, 0);
        t.addStone(0, 0);
        final near = t.addStone(-1.1, 3.0); // 충돌 지점(약 −1.1, 0)에서 3cm
        t.shoot(me, 0, 30, 0, inner: true, technique: tech);
        t.runTurn();
        final y = near.position.y;
        t.dispose();
        return y;
      }

      expect(side(tech: Technique.none), closeTo(3.0, 1e-6));
      expect(side(tech: Technique.stomp), greaterThan(3.2));
    });

    test('태극: 첫 충돌 전까지 궤적이 휜다(휘는 방향 = curl 부호)', () {
      double y(double curl) {
        final t = Table();
        final me = t.addStone(-18, 0);
        t.shoot(
          me,
          0,
          40,
          0,
          inner: true,
          technique: Technique.taiji,
          curl: curl,
        );
        t.runTurn();
        final v = me.position.y;
        t.dispose();
        return v;
      }

      expect(y(0), closeTo(0, 1e-6));
      expect(y(1), greaterThan(2));
      expect(y(-1), lessThan(-2));
    });

    test('분신: 한 수에 상대 돌 2개를 맞히면 내 돌이 둘로 나뉜다 — 판당 1회, 수가 끝나면 사라짐', () {
      final t = Table();
      // 무거운 현철 구형 돌이라 첫 돌을 치고도 계속 나아가 두 번째 돌을 친다.
      final me = t.addStone(
        -10,
        0,
        material: StoneMaterial.hyeoncheol,
        shape: StoneShape.sphere,
      );
      t.addStone(-4, 0.5, team: 1);
      t.addStone(2, -0.5, team: 1);
      final n = t.stones.length;
      t.shoot(me, 0, 90, 0, inner: true, technique: Technique.clone);
      var cloned = 0;
      var maxStones = n;
      while (t.step() == TurnStatus.moving) {
        cloned += t.events.where((e) => e.fx == TechniqueFx.clone).length;
        maxStones = math.max(maxStones, t.stones.length);
      }
      expect(cloned, 1);
      expect(maxStones, n + 1);
      expect(t.stones.length, n, reason: '수가 끝나면 분신은 사라진다');
      expect(t.cloneUsed, isTrue);
      t.dispose();
    });

    test('흡성탄지: 첫 충돌 순간 6cm 안의 돌을 0.5초 끌어당긴다', () {
      double dist({required Technique tech}) {
        final t = Table();
        final me = t.addStone(-8, 0);
        t.addStone(0, 0);
        final near = t.addStone(-1.1, 5.0);
        t.shoot(me, 0, 30, 0, inner: true, technique: tech);
        t.runTurn();
        final d = (near.position - Vector2(-1.1, 0)).length;
        t.dispose();
        return d;
      }

      expect(dist(tech: Technique.none), closeTo(5.0, 1e-6));
      final pulled = dist(tech: Technique.absorb);
      expect(pulled, lessThan(4.5));
      expect(pulled, greaterThan(1.5), reason: '끌어당기되 내던지지 않는다');
    });

    test('내공 타격이 아니면 무공은 발동하지 않는다', () {
      final t = Table();
      final me = t.addStone(-8, 0);
      t.addStone(0, 0);
      final near = t.addStone(-1.1, 3.0);
      t.shoot(me, 0, 30, 0, technique: Technique.stomp);
      t.runTurn();
      expect(near.position.y, closeTo(3.0, 1e-6));
      t.dispose();
    });
  });

  group('1-12 지형·날씨 (설계서 §9.3·§9.4·§10.2)', () {
    double rollX({Weather w = Weather.clear}) {
      final t = Table(weather: w);
      final s = t.addStone(-18, 0);
      t.shoot(s, 0, 30, 0);
      t.runTurn();
      final x = s.position.x;
      t.dispose();
      return x;
    }

    test('야우: 감속 −50% 라 같은 힘에 더 멀리', () {
      expect(rollX(w: Weather.nightRain), greaterThan(rollX() + 5));
    });

    test('광풍: 바람에 밀려 곧게 가지 않는다(같은 씨앗이면 같은 길)', () {
      double y(int seed) {
        final t = Table(weather: Weather.gale, windSeed: seed);
        final s = t.addStone(-18, 0);
        t.shoot(s, 0, 40, 0);
        t.runTurn();
        final v = s.position.y;
        t.dispose();
        return v;
      }

      expect(y(3).abs(), greaterThan(0.5));
      expect(y(3), y(3));
    });

    test('청죽은 반발 1.5배 · 조약돌보다 세게 튕겨 낸다', () {
      double back(FeatureKind k) {
        final t = Table();
        t.addFeature(Feature(k, 0, 0));
        final s = t.addStone(-8, 0);
        t.shoot(s, 0, 40, 0);
        var minVx = 0.0;
        while (t.step() == TurnStatus.moving) {
          minVx = math.min(minVx, s.velocity.x);
        }
        t.dispose();
        return -minVx;
      }

      expect(
        back(FeatureKind.bamboo),
        greaterThan(back(FeatureKind.pebble) * 1.5),
      );
      expect(back(FeatureKind.bamboo), greaterThan(40), reason: '들어온 것보다 세게');
    });

    test('경종을 맞히면 8cm 안의 상대 돌이 바깥으로', () {
      final t = Table();
      t.addFeature(const Feature(FeatureKind.gong, 0, 0));
      final me = t.addStone(-8, 0);
      final foe = t.addStone(0, 5, team: 1);
      final friend = t.addStone(0, -5);
      t.shoot(me, 0, 40, 0);
      var rang = false;
      while (t.step() == TurnStatus.moving) {
        rang |= t.terrainEvents.any((e) => e.fx == TerrainFx.gong);
      }
      expect(rang, isTrue);
      expect(foe.position.y, greaterThan(6));
      expect(friend.position.y, closeTo(-5, 1e-6), reason: '내 편은 그대로');
      t.dispose();
    });

    test('블랙홀은 빨아들여 장외 · 지뢰석은 맞힌 돌이 터져 장외, 한 번 뒤 사라짐', () {
      final t = Table();
      t.addFeature(const Feature(FeatureKind.blackHole, 0, 0));
      final s = t.addStone(-4, 0);
      t.shoot(s, 0, 15, 0);
      t.runTurn();
      expect(s.out, isTrue);
      t.dispose();

      final t2 = Table();
      t2.addFeature(const Feature(FeatureKind.mine, 0, 0));
      final me = t2.addStone(-8, 0);
      final near = t2.addStone(0, 3.5, team: 1);
      t2.shoot(me, 0, 40, 0);
      t2.runTurn();
      expect(me.out, isTrue);
      expect(near.position.y, greaterThan(5));
      expect(t2.features, isEmpty);
      t2.dispose();
    });

    test('혹한: 세 번째 충돌에서 그 수에는 멈춘다', () {
      final t = Table(weather: Weather.frost);
      final me = t.addStone(
        -10,
        0,
        material: StoneMaterial.hyeoncheol,
        shape: StoneShape.sphere,
      );
      t.addStone(-7, 0.2, team: 1);
      t.addStone(-4.5, -0.2, team: 1);
      t.addStone(-2, 0.2, team: 1);
      t.shoot(me, 0, 120, 0);
      var stopped = false;
      while (t.step() == TurnStatus.moving) {
        stopped |= t.terrainEvents.any((e) => e.fx == TerrainFx.frostStop);
      }
      expect(stopped, isTrue);
      t.dispose();
    });

    // 2026-10-14 형 「둥글수록 … 내가 작동하는 부분은 엄청 잘 움직이지만 튕기는 부분과 상대가 맞췄을 때는
    // 강한 중력이 발생해서 잘 구르지 않는다는 설정이 있어야 잘 안 죽어」.
    test('무게중심: 맞은 구형 돌은 예전보다 · 납작한 돌보다 덜 구른다', () {
      double pushed(StoneShape shape, {required bool settle}) {
        final t = Table(settle: settle);
        final me = t.addStone(0, 10);
        final tg = t.addStone(0, 0, shape: shape);
        t.shoot(me, -math.pi / 2, 30, 0);
        t.runTurn();
        final d = tg.out ? double.infinity : -tg.position.y;
        t.dispose();
        return d;
      }

      final flat = pushed(StoneShape.flat, settle: true);
      final sphere = pushed(StoneShape.sphere, settle: true);
      final oldSphere = pushed(StoneShape.sphere, settle: false);
      expect(sphere, lessThan(flat), reason: '구형 $sphere · 납작 $flat');
      expect(sphere, lessThan(oldSphere * 0.8), reason: '예전 구형 $oldSphere');
    });

    test('무게중심: 내가 쏜 구형 돌은 충돌 전까지 예전처럼 멀리 구른다', () {
      double roll({required bool settle}) {
        final t = Table(settle: settle);
        final me = t.addStone(0, 10, shape: StoneShape.sphere);
        t.shoot(me, -math.pi / 2, 20, 0);
        t.runTurn();
        final d = 10 - me.position.y;
        t.dispose();
        return d;
      }

      expect(roll(settle: true), closeTo(roll(settle: false), 1e-6));
    });

    test('무게중심: 쏜 돌도 부딪혀 튕긴 뒤에는 무게중심이 걸린다', () {
      final t = Table();
      final me = t.addStone(0, 10, shape: StoneShape.sphere);
      t.addStone(0, 0);
      final free = me.body.linearDamping;
      t.shoot(me, -math.pi / 2, 60, 0);
      expect(me.body.linearDamping, lessThan(free), reason: '쏘는 순간 풀림');
      final loose = me.body.linearDamping;
      var guard = 0;
      while (t.impacts.isEmpty && guard++ < 600) {
        t.step();
      }
      expect(
        me.body.linearDamping,
        closeTo(loose * StoneShape.sphere.settleMultiplier, 1e-6),
      );
      t.dispose();
    });

    // 2026-10-14 형 「반탄력이 너무 커서 내 공격에 내 돌이 죽고 있어」.
    test('반탄력: 비껴 맞혀도 쏜 돌이 멀리 튕겨 나가지 않는다', () {
      (double, double) run({required bool settle}) {
        final t = Table(settle: settle);
        final me = t.addStone(1.6, 10, shape: StoneShape.flat);
        final tg = t.addStone(0, 0, shape: StoneShape.flat);
        t.shoot(me, -math.pi / 2, 80, 0);
        Vector2? at;
        var guard = 0;
        while (t.status == TurnStatus.moving && guard++ < 1200) {
          t.step();
          if (at == null && t.impacts.isNotEmpty) at = me.position.clone();
        }
        final shooterAfter = me.out
            ? double.infinity
            : (me.position - at!).length;
        final target = tg.out ? double.infinity : tg.position.length;
        t.dispose();
        return (shooterAfter, target);
      }

      final (meNew, tgNew) = run(settle: true);
      final (meOld, _) = run(settle: false);
      expect(meNew, lessThan(meOld * 0.5), reason: '쏜 돌 튕김 $meNew (예전 $meOld)');
      expect(tgNew, greaterThan(3), reason: '맞은 돌은 그래도 밀린다');
    });

    test('바닥 배수를 바꾸면 돌 감속이 바로 바뀐다(6장 얼음·불꽃)', () {
      final t = Table();
      final s = t.addStone(0, 0);
      final before = s.body.linearDamping;
      t.floorFactor = 0.5;
      expect(s.body.linearDamping, closeTo(math.max(0.3, before * 0.5), 1e-9));
      t.dispose();
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
