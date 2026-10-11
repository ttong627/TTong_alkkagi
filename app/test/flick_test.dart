import 'dart:math' as math;

import 'package:alkkagi/game/flick.dart';
import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/input/touch_feed.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// [from] 에서 [by] 만큼 [seconds] 동안 고르게 움직인 손가락(1초에 120점).
List<FlickSample> swipe(Offset from, Offset by, double seconds) {
  final n = math.max(2, (seconds * 120).round());
  return [
    for (var i = 0; i <= n; i++)
      FlickSample(from + by * (i / n), seconds * i / n),
  ];
}

/// 손가락 길을 처음부터 끝까지 넣어 본다. 쳐 냈으면 그 결과, 아니면 손 뗄 때 까닭.
Object run(StoneDisc disc, List<FlickSample> s, {TouchProfile? profile}) {
  final r = StrikeReader(disc, profile: profile ?? TouchProfile());
  r.down(s.first);
  for (final p in s.skip(1)) {
    final shot = r.move(p);
    if (shot != null) return shot;
  }
  return r.up()!;
}

double deg(double rad) => rad * 180 / math.pi;

void main() {
  // 돌: 화면 (200, 400), 반지름 100.
  const disc = StoneDisc(Offset(200, 400), 100);

  group('폰 = 대전장 바닥: 손끝이 돌에 부딪히는 순간', () {
    test('아래에서 돌 가운데로 밀면 곧게 위로(−90°), 손 떼기 전에 바로 나간다', () {
      final s = swipe(const Offset(200, 700), const Offset(0, -600), 0.5);
      final r = StrikeReader(disc)..down(s.first);
      FlickShot? shot;
      var at = 0;
      for (var i = 1; i < s.length && shot == null; i++) {
        shot = r.move(s[i]);
        at = i;
      }
      expect(shot, isNotNull);
      expect(deg(shot!.angle), closeTo(-90, 1e-6));
      // 돌 가장자리(y = 500)에 닿은 바로 그 점에서 나갔다.
      expect(s[at - 1].pos.dy, greaterThan(500));
      expect(s[at].pos.dy, lessThanOrEqualTo(500));
      expect(shot.contact.dy, closeTo(500, 1e-6));
      expect(shot.hit, 0);
    });

    test('세기 = 닿을 때 손끝 빠르기: 1,200화소/초 → 내공 (1200−60)/(1500−60)', () {
      final s = swipe(const Offset(200, 740), const Offset(0, -480), 0.4);
      final shot = run(disc, s) as FlickShot;
      expect(shot.power, closeTo((1200 - 60) / (1500 - 60), 1e-6));
      // 한가운데를 알맞은 세기(0.79)로 → 회심 일격, 처음 속도 ×1.15.
      expect(shot.critical, isTrue);
      expect(
        shot.speed,
        closeTo(powerToSpeed(shot.power) * CriticalRule.speedBonus, 1e-9),
      );
    });

    test('살살(150화소/초) 밀어도 나간다 — 세게 칠 필요 없다', () {
      final s = swipe(const Offset(200, 560), const Offset(0, -150), 1.0);
      final shot = run(disc, s);
      expect(shot, isA<FlickShot>());
      expect((shot as FlickShot).power, greaterThan(0));
    });

    test('가운데 근처(반지름 20%)를 맞히면 마찰로 붙어 손끝 방향 그대로 나간다', () {
      final s = swipe(const Offset(220, 700), const Offset(0, -600), 0.5);
      final shot = run(disc, s) as FlickShot;
      expect(deg(shot.angle), closeTo(-90, 1e-6));
    });

    test('가장자리를 맞히면 비스듬히: 오른쪽을 치면 왼쪽으로 꺾이고, 끝일수록 더 꺾인다', () {
      double cutAt(double b) {
        final s = swipe(Offset(200 + b, 700), const Offset(0, -600), 0.5);
        return deg((run(disc, s) as FlickShot).angle);
      }

      final a60 = cutAt(60), a80 = cutAt(80), a95 = cutAt(95);
      // 오른쪽(+x)을 치면 돌은 왼쪽 위로(−90° 보다 작은 쪽).
      expect(a60, lessThan(-90));
      expect(a80, lessThan(a60));
      expect(a95, lessThan(a80));
      // 마찰 0.3 · 옮김 1: 꺾이는 각 = 법선각 − atan(0.3).
      final normal80 = deg(math.asin(0.8));
      expect(-90 - a80, closeTo(normal80 - deg(math.atan(0.3)), 1e-6));
    });

    test('끝을 스치면 약하게 나간다(같은 빠르기라도)', () {
      final straight = run(
        disc,
        swipe(const Offset(200, 700), const Offset(0, -600), 0.5),
      ) as FlickShot;
      final graze = run(
        disc,
        swipe(const Offset(295, 700), const Offset(0, -600), 0.5),
      ) as FlickShot;
      expect(graze.power, lessThan(straight.power * 0.5));
    });

    test('돌을 비껴가면 쏘지 않고 다시 하라고 알려 준다', () {
      final s = swipe(const Offset(320, 700), const Offset(0, -600), 0.5);
      expect(run(disc, s), FlickMiss.missed);
    });

    test('돌 위에 손을 대고 밀어도 민 방향으로 나간다', () {
      final s = swipe(const Offset(200, 400), const Offset(80, -80), 0.1);
      final shot = run(disc, s) as FlickShot;
      expect(deg(shot.angle), closeTo(-45, 1e-6));
    });

    test('돌 위에 손만 대고 떼면 쏘지 않는다', () {
      final r = StrikeReader(disc)
        ..down(const FlickSample(Offset(200, 400), 0));
      expect(r.move(const FlickSample(Offset(202, 401), 0.05)), isNull);
      expect(r.up(), FlickMiss.tooWeak);
    });

    test('다가오는 동안 어디로 얼마나 나갈지 미리 보여 준다', () {
      final r = StrikeReader(disc);
      final s = swipe(const Offset(260, 800), const Offset(0, -150), 0.125);
      r.down(s.first);
      for (final p in s.skip(1)) {
        expect(r.move(p), isNull, reason: '아직 닿지 않음');
      }
      final (angle, power) = r.predict()!;
      expect(deg(angle), lessThan(-90), reason: '오른쪽을 칠 길 → 왼쪽으로 꺾임');
      expect(power, greaterThan(0.5));
    });

    test('점 사이가 멀어도(빠른 손) 지나간 돌을 놓치지 않고 가장자리에서 맞힌다', () {
      final s = [
        const FlickSample(Offset(200, 560), 0),
        const FlickSample(Offset(200, 240), 0.02),
      ];
      final shot = run(disc, s) as FlickShot;
      expect(shot.contact.dy, closeTo(500, 1e-6));
      expect(shot.power, 1);
      expect(shot.speed, baseMaxSpeed);
    });
  });

  group('위아래 타격점 = 손끝이 화면에 닿은 넓이 (이 폰의 평소 값과 견줌)', () {
    TouchProfile trained() {
      final p = TouchProfile();
      // 평소 손대기: 넓이 10~20 고르게.
      for (var i = 0; i < 200; i++) {
        p.add(10 + (i % 101) / 10);
      }
      return p;
    }

    List<FlickSample> withArea(double area) => [
      for (final p in swipe(const Offset(200, 700), const Offset(0, -600), 0.5))
        FlickSample(p.pos, p.t, area: area),
    ];

    test('평소보다 넓게(손끝을 눕혀 낮게) 닿으면 아래(−), 좁게(손끝만) 닿으면 위(+)', () {
      final p = trained();
      final low = run(disc, withArea(22), profile: p) as FlickShot;
      final mid = run(disc, withArea(15), profile: p) as FlickShot;
      final high = run(disc, withArea(9), profile: p) as FlickShot;
      expect(low.hit, -1);
      expect(mid.hit.abs(), lessThan(0.1));
      expect(high.hit, 1);
    });

    test('자료가 모자라거나 폰이 넓이를 늘 같게 알려 주면 가운데(0)', () {
      final few = TouchProfile();
      for (var i = 0; i < 10; i++) {
        few.add(10 + i.toDouble());
      }
      expect((run(disc, withArea(30), profile: few) as FlickShot).hit, 0);
      final flat = TouchProfile();
      for (var i = 0; i < 100; i++) {
        flat.add(1);
      }
      expect(flat.range, isNull);
      expect((run(disc, withArea(1), profile: flat) as FlickShot).hit, 0);
    });

    test('넓이를 모르는 점(웹·시험)이면 가운데(0)', () {
      final shot = run(
        disc,
        swipe(const Offset(200, 700), const Offset(0, -600), 0.5),
        profile: trained(),
      ) as FlickShot;
      expect(shot.hit, 0);
    });
  });

  group('돌 무게(재질 밀도 × 모양 부피)', () {
    test('기준(둥근 청옥)은 그대로, 무거운 돌은 덜, 가벼운 돌은 더 나간다', () {
      expect(massFactor(referenceMass), 1);
      final heavy = stoneMass(StoneMaterial.hyeoncheol, StoneShape.sphere);
      final light = stoneMass(StoneMaterial.wood, StoneShape.flat);
      expect(
        massFactor(heavy),
        closeTo((3 * 2.43 + 2.43) / (3 * 2.43 + heavy), 1e-12),
      );
      expect(massFactor(heavy), lessThan(0.5));
      expect(massFactor(light), greaterThan(1.1));
    });

    test('같은 손놀림이면 무거운 돌의 처음 속도가 무게 비율만큼 작다', () {
      final s = swipe(const Offset(200, 700), const Offset(0, -600), 0.5);
      final ref = run(disc, s) as FlickShot;
      const heavyDisc = StoneDisc(Offset(200, 400), 100, mass: 13.95);
      final heavy = run(heavyDisc, s) as FlickShot;
      expect(heavy.power, ref.power);
      expect(heavy.speed / ref.speed, closeTo(massFactor(13.95), 1e-12));
    });
  });

  group('안드로이드 손끝 점 묶음 읽기', () {
    test('사이에 찍힌 점까지 모두 읽고, 닿은 길이가 없으면 넓이 비율을 쓴다', () {
      final e = TouchFeed.parse(
        Float64List.fromList([
          2, 2, //
          1000, 10, 20, 30, 0.2, 1, //
          1008, 12, 24, 0, 0.25, 1,
        ]),
      )!;
      expect(e.action, 2);
      expect(e.points, hasLength(2));
      expect(e.points[0].t, 1.0);
      expect(e.points[0].px, const Offset(10, 20));
      expect(e.points[0].area, 30);
      expect(e.points[1].t, closeTo(1.008, 1e-12));
      expect(e.points[1].area, 0.25);
    });

    test('모양이 틀린 묶음은 버린다', () {
      expect(TouchFeed.parse(null), isNull);
      final hover = TouchFeed.parse(
        Float64List.fromList([7, 1, 1000, 10, 20, 0, 0, 0]),
      )!;
      expect(hover.isHover, isTrue);
      expect(hover.isDown, isFalse);
      expect(
        TouchFeed.parse(Float64List.fromList([10, 1, 1000, 10, 20, 0, 0, 0]))!
            .isHoverEnd,
        isTrue,
      );
      expect(TouchFeed.parse(Float64List.fromList([2, 3, 1, 2])), isNull);
    });
  });

  group('회심 일격(크리티컬) — 평타에서 터지면 내공 1칸', () {
    test('한가운데 · 알맞은 세기면 회심', () {
      final s = swipe(const Offset(200, 700), const Offset(0, -500), 0.5);
      final shot = run(disc, s) as FlickShot;
      expect(shot.offset, lessThan(1e-9));
      expect(shot.critical, isTrue);
    });

    test('가장자리(비껴 맞음 0.3)면 회심이 아니다', () {
      final s = swipe(const Offset(230, 700), const Offset(0, -500), 0.5);
      final shot = run(disc, s) as FlickShot;
      expect(shot.offset, closeTo(0.3, 1e-6));
      expect(shot.critical, isFalse);
    });

    test('너무 세게(내공 100%) 치면 회심이 아니다 · 너무 약해도 아니다', () {
      final hard = run(
        disc,
        swipe(const Offset(200, 700), const Offset(0, -1200), 0.5),
      ) as FlickShot;
      expect(hard.power, 1);
      expect(hard.critical, isFalse);
      final soft = run(
        disc,
        swipe(const Offset(200, 560), const Offset(0, -300), 1.0),
      ) as FlickShot;
      expect(soft.critical, isFalse);
    });

    test('돌에 손을 대고 민 것은 회심이 아니다', () {
      final s = swipe(const Offset(200, 400), const Offset(0, -100), 0.1);
      final shot = run(disc, s) as FlickShot;
      expect(shot.critical, isFalse);
    });

    test('쓸고 간 쪽이 태극의 휘는 방향(curl 부호)', () {
      final right = run(
        disc,
        swipe(const Offset(260, 700), const Offset(0, -500), 0.5),
      ) as FlickShot;
      final left = run(
        disc,
        swipe(const Offset(140, 700), const Offset(0, -500), 0.5),
      ) as FlickShot;
      expect(right.curl.sign, -left.curl.sign);
      expect(right.curl.abs(), closeTo(1, 1e-9));
    });
  });

  group('검지로 튕기기 — 손끝이 돌 앞에서 화면을 떠나도 그 빠르기로 날아가 맞는다', () {
    const disc = StoneDisc(Offset(200, 400), 74);

    /// 아래에서 위로 [speed] 화소/초로 1.5R 스치고, 돌 가장자리 앞 [gapR]·R 에서 손을 뗀다.
    (FlickShot?, FlickMiss?) flick(
      double gapR, {
      double speed = 1500,
      double dx = 0,
    }) {
      final r = StrikeReader(disc, profile: TouchProfile.off);
      final yEnd = 400 + 74 * (1 + gapR);
      final y0 = yEnd + 74 * 1.5;
      final dur = (y0 - yEnd) / speed;
      r.down(FlickSample(Offset(200 + dx, y0), 0));
      FlickShot? s;
      for (var i = 1; i <= 10 && s == null; i++) {
        s = r.move(
          FlickSample(
            Offset(200 + dx, y0 + (yEnd - y0) * i / 10),
            dur * i / 10,
          ),
        );
      }
      s ??= r.release();
      return (s, s == null ? r.up() : null);
    }

    test('가장자리 앞 0.3R~2.4R 에서 떼도 위로 곧게 나가고, 일찍 뗄수록 위쪽(+1)을 맞는다', () {
      for (final g in [0.3, 0.6, 1.0, 2.0, 2.4]) {
        final (s, _) = flick(g);
        expect(s, isNotNull, reason: 'gap $g');
        expect(s!.flick, isTrue);
        expect(s.angle, closeTo(-math.pi / 2, 1e-6));
        expect(s.hit, closeTo(math.min(1, g), 1e-6));
      }
      // 닿은 채로 가장자리까지 오면 예전처럼(튕김 아님).
      expect(flick(0).$1!.flick, isFalse);
    });

    test('3R 넘게 떨어져 떼거나, 천천히 떼거나, 돌을 비껴 가면 쏘지 않는다', () {
      expect(flick(3.0).$1, isNull);
      expect(flick(1.0, speed: 200).$1, isNull); // 그냥 손을 뗀 것
      expect(flick(1.0, dx: 120).$1, isNull); // 돌 옆으로 지나감
      expect(flick(1.0, dx: 120).$2, FlickMiss.missed);
    });

    test('가장자리 쪽으로 튕기면 꺾인다(닿은 채 친 것과 같은 법칙)', () {
      final (s, _) = flick(1.0, dx: 55);
      expect(s, isNotNull);
      expect(s!.angle, lessThan(-math.pi / 2 - 0.2)); // 오른쪽을 맞아 왼쪽 위로
    });

    test('아주 짧게(점 2개·10ms) 스치고 떠도 맞는다', () {
      final r = StrikeReader(disc, profile: TouchProfile.off);
      r.down(const FlickSample(Offset(200, 400 + 74 * 2.0 + 20), 0));
      expect(
        r.move(const FlickSample(Offset(200, 400 + 74 * 2.0), 0.01)),
        isNull,
      );
      final s = r.release();
      expect(s, isNotNull);
      expect(s!.angle, closeTo(-math.pi / 2, 1e-6));
    });
  });
}
