import 'dart:math' as math;

import 'package:alkkagi/game/flick.dart';
import 'package:alkkagi/game/match.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

/// (x, y) 에서 (dx, dy) 만큼 [seconds] 동안 고르게 움직인 손가락.
List<FlickSample> swipe(
  Offset from,
  Offset by,
  double seconds, {
  int steps = 12,
}) => [
  for (var i = 0; i <= steps; i++)
    FlickSample(from + by * (i / steps), seconds * i / steps),
];

void main() {
  // 둥근 돌, 화면 (200, 300) 에 반지름 100.
  final face = StoneFace.of(StoneShape.round, const Offset(200, 300), 100);

  group('돌 모양(가까이 보기)', () {
    test('실루엣: 윗면·옆면 안은 닿음, 바깥은 안 닿음', () {
      expect(face.contains(face.center), isTrue);
      expect(face.contains(face.center.translate(0, face.thickness)), isTrue);
      expect(face.contains(Offset(200, face.bottom + 5)), isFalse);
      expect(face.contains(const Offset(320, 300)), isFalse);
    });
    test('닿은 높이 → 타격점: 맨 위 +1 · 가운데 0 · 맨 아래 −1', () {
      expect(face.hitAt(Offset(200, face.top)), 1);
      expect(face.hitAt(Offset(200, (face.top + face.bottom) / 2)), 0);
      expect(face.hitAt(Offset(200, face.bottom)), -1);
    });
    test('구형 돌은 원', () {
      final ball = StoneFace.of(StoneShape.sphere, const Offset(0, 0), 50);
      expect(ball.thickness, 0);
      expect(ball.top, -50);
      expect(ball.bottom, 50);
    });
  });

  group('튕기기 읽기', () {
    test('아래에서 위로 빠르게 쳐올림 → 위쪽(−π/2), 강한 세기', () {
      // 돌 아래 바깥에서 출발해 0.1초에 400px 위로: 4000px/s.
      final s = swipe(
        Offset(200, face.bottom + 60),
        const Offset(0, -400),
        0.1,
      );
      final r = readFlick(s, face);
      expect(r, isA<FlickShot>());
      final shot = r as FlickShot;
      expect(shot.angle, closeTo(-math.pi / 2, 1e-6));
      expect(shot.power, 1);
      expect(shot.speed, closeTo(baseMaxSpeed, 1e-9));
      // 아래에서 올라오며 처음 닿은 곳은 돌 아래쪽 → 끌어치기 쪽.
      expect(shot.hit, lessThan(-0.8));
    });

    test('돌 윗부분을 누른 채 위로 튕김 → 밀어치기(+)', () {
      final s = swipe(Offset(200, face.top + 5), const Offset(0, -200), 0.1);
      final shot = readFlick(s, face) as FlickShot;
      expect(shot.hit, greaterThan(0.8));
    });

    test('오른쪽 위 대각선 → 판 위 방향도 오른쪽 위(−π/4)', () {
      final s = swipe(
        face.center.translate(0, face.thickness / 2),
        const Offset(150, -150),
        0.1,
      );
      final shot = readFlick(s, face) as FlickShot;
      expect(shot.angle, closeTo(-math.pi / 4, 1e-6));
      expect(shot.hit.abs(), lessThan(0.1), reason: '가운데를 쳤으니 강타');
    });

    test('세기: 빠르기에 비례, 최소 12cm/s ~ 최대 120cm/s', () {
      expect(flickPower(FlickTuning.minPxPerSec), 0);
      expect(flickPower(FlickTuning.fullPxPerSec), 1);
      expect(flickPower(9999), 1);
      expect(powerToSpeed(0), FlickTuning.minShotSpeed);
      expect(powerToSpeed(1), baseMaxSpeed);
      final mid = (FlickTuning.minPxPerSec + FlickTuning.fullPxPerSec) / 2;
      expect(flickPower(mid), closeTo(0.5, 1e-9));
    });

    test('돌을 비껴가면 쏘지 않는다', () {
      final s = swipe(const Offset(40, 500), const Offset(0, -400), 0.1);
      expect(readFlick(s, face), FlickMiss.missed);
    });

    test('느리게 밀면 쏘지 않는다', () {
      // 1초에 100px = 100px/s < 300px/s.
      final s = swipe(face.center, const Offset(0, -100), 1);
      expect(readFlick(s, face), FlickMiss.tooWeak);
    });

    test('튕긴 뒤 바로 떼면 쏘고, 멈췄다가 떼면 쏘지 않는다', () {
      final s = swipe(
        Offset(200, face.bottom + 60),
        const Offset(0, -400),
        0.1,
      );
      expect(readFlick(s, face, releaseAt: 0.11), isA<FlickShot>());
      expect(readFlick(s, face, releaseAt: 0.3), FlickMiss.tooWeak);
    });

    test('점 사이가 멀어도(빠른 손) 지나간 돌을 놓치지 않는다', () {
      // 두 점만: 돌 아래 바깥 → 돌 위 바깥. 가운데를 지나간다.
      final s = [
        FlickSample(Offset(200, face.bottom + 40), 0),
        FlickSample(Offset(200, face.top - 40), 0.05),
      ];
      expect(firstContact(s, face), isNotNull);
      expect(readFlick(s, face), isA<FlickShot>());
    });

    test('손 뗄 때 빠르기는 마지막 0.08초만 본다(처음에 천천히 → 끝에 확)', () {
      final slow = swipe(face.center, const Offset(0, -20), 0.5, steps: 10);
      final fast = [
        for (var i = 1; i <= 5; i++)
          FlickSample(
            slow.last.pos + Offset(0, -60.0 * i),
            slow.last.t + 0.016 * i,
          ),
      ];
      final shot = readFlick([...slow, ...fast], face) as FlickShot;
      expect(shot.power, greaterThan(0.9));
    });
  });
}
