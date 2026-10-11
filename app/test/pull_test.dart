import 'dart:math' as math;

import 'package:alkkagi/game/flick.dart';
import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/progress/settings.dart';
import 'package:alkkagi/screens/flick_view.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializePhysics();
  });

  group('당겨 쏘기(PullReader)', () {
    const disc = StoneDisc(Offset(200, 400), 100);

    test('돌 가까이를 눌러야 잡힌다', () {
      expect(PullReader(disc).down(const Offset(200, 400)), isTrue);
      expect(PullReader(disc).down(const Offset(200, 555)), isTrue);
      expect(PullReader(disc).down(const Offset(200, 700)), isFalse);
    });

    test('아래로 당기면 위로 · 덜 당기면 취소 · 많이 당길수록 세다', () {
      final r = PullReader(disc)..down(const Offset(200, 400));
      r.move(const Offset(200, 440));
      expect(r.aim, isNull, reason: '반지름 0.4 만큼은 겨누기만');
      r.move(const Offset(200, 400 + 100 * PullReader.fullPull));
      final (angle, power) = r.aim!;
      expect(angle, closeTo(-math.pi / 2, 1e-9));
      expect(power, 1);
      final shot = r.release()!;
      expect(shot.speed, closeTo(baseMaxSpeed, 1e-9));
      expect(shot.hit, 0);
      expect(r.release(), isNull, reason: '한 번만');

      final weak = PullReader(disc)..down(const Offset(200, 400));
      weak.move(const Offset(200, 430));
      expect(weak.release(), isNull);
    });

    test('오른쪽 아래로 당기면 왼쪽 위로', () {
      final r = PullReader(disc)..down(const Offset(200, 400));
      r.move(const Offset(400, 600));
      expect(r.aim!.$1, closeTo(-3 * math.pi / 4, 1e-9));
    });

    test('금빛 칸(회심 구간)에서 놓으면 회심 · 그 밖은 아님', () {
      double pullFor(double power) =>
          PullReader.minPull +
          power * (PullReader.fullPull - PullReader.minPull);
      FlickShot at(double power) {
        final r = PullReader(disc)..down(const Offset(200, 400));
        r.move(Offset(200, 400 + 100 * pullFor(power)));
        return r.release()!;
      }

      expect(at(0.68).critical, isTrue);
      expect(at(0.5).critical, isFalse);
      expect(at(0.9).critical, isFalse);
      expect(
        at(0.68).speed,
        closeTo(powerToSpeed(0.68) * CriticalRule.speedBonus, 1e-9),
      );
    });

    test('무거운 돌은 같은 당김에 덜 나간다', () {
      const heavy = StoneDisc(Offset(200, 400), 100, mass: 5);
      final a = PullReader(disc)..down(const Offset(200, 400));
      final b = PullReader(heavy)..down(const Offset(200, 400));
      a.move(const Offset(200, 600));
      b.move(const Offset(200, 600));
      expect(b.release()!.speed, lessThan(a.release()!.speed));
    });
  });

  group('가까이 보기에서 당겨 쏘기', () {
    tearDown(() => Settings.instance.pull = false);

    Future<(Match, List<FlickShot>, Offset, double)> open(
      WidgetTester tester,
    ) async {
      Settings.instance.pull = true;
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final m = Match(const MatchConfig(mode: MatchMode.vsAi));
      final shots = <FlickShot>[];
      final stone = m.table.stones.firstWhere((s) => s.team == 0);
      await tester.pumpWidget(
        MaterialApp(
          home: FlickView(
            match: m,
            stone: stone,
            onShot: (s, _) => shots.add(s),
            onCancel: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      // 돌 자리: FlickView 와 같은 셈(작은 지도 30% · 글 78).
      final pad = tester.getRect(find.byKey(const Key('flick-pad')));
      final miniH = pad.height * 0.3;
      final floorH = pad.height - miniH - 78;
      final r = math.min(pad.width * 0.28, floorH * 0.3);
      final c = pad.topLeft + Offset(pad.width / 2, miniH + floorH * 0.5);
      return (m, shots, c, r);
    }

    testWidgets('돌을 잡고 아래로 당겼다 놓으면 위로 쏜다', (tester) async {
      final (m, shots, c, r) = await open(tester);
      expect(find.text('돌을 잡고 뒤로 당겼다 놓기'), findsOneWidget);
      expect(find.text('당겨 쏘기'), findsOneWidget);
      final g = await tester.startGesture(c);
      for (var i = 0; i < 10; i++) {
        await g.moveBy(Offset(0, r * 0.3));
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(find.textContaining('내공'), findsWidgets);
      await g.up();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(shots, hasLength(1));
      expect(shots.single.angle, closeTo(-math.pi / 2, 0.02));
      expect(shots.single.power, greaterThan(0.5));
      m.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('덜 당기거나 돌 밖을 누르면 쏘지 않고 알려 준다', (tester) async {
      final (m, shots, c, r) = await open(tester);
      final g = await tester.startGesture(c);
      await g.moveBy(Offset(0, r * 0.3));
      await g.up();
      await tester.pump(const Duration(milliseconds: 50));
      expect(shots, isEmpty);
      expect(find.text('더 당겨야 나가요(놓으면 취소)'), findsOneWidget);
      await tester.tapAt(c + Offset(0, r * 2));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('돌을 눌러 잡고 뒤로 당기세요'), findsOneWidget);
      expect(shots, isEmpty);
      m.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('겨누는 화면 단추로 튕기기 ↔ 당겨 쏘기를 바꾼다(설정에도 남는다)', (tester) async {
      final (m, _, _, _) = await open(tester);
      await tester.tap(find.byKey(const Key('flick-control')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(Settings.instance.pull, isFalse);
      expect(find.text('검지로 돌을 튕기세요'), findsOneWidget);
      m.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  });
}
