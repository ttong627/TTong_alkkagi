import 'dart:math' as math;

import 'package:alkkagi/game/arena.dart';
import 'package:alkkagi/game/flick.dart';
import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/progress/drills.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-10-14 형 「목인항 수련 단계별로 해주고 지금처럼 돌로 돌 맞추기만 하는 게 아니라 여러 가지의 기술과
// 내공을 익힐 수 있도록 단계별 수련을 할 수 있게 해줘」.
void main() {
  setUpAll(initializePhysics);

  test('수련 10단계 · 기술마다 다른 조건 · 숙련 셋', () {
    expect(drills.length, 10);
    expect(drills.map((d) => d.check).toSet().length, 10, reason: '단계마다 다른 기술');
    expect(drills.where((d) => d.perk != null).length, 3);
  });

  test('조건: 끌어치기는 아래쪽 타점 · 일타쌍피는 더미 둘 · 박살은 회심 장외', () {
    final draw = drills.firstWhere((d) => d.check == DrillCheck.draw);
    expect(Drills.counts(draw, const DrillShot(touched: 1, hit: -0.6)), isTrue);
    expect(Drills.counts(draw, const DrillShot(touched: 1, hit: 0.2)), isFalse);
    final dbl = drills.firstWhere((d) => d.check == DrillCheck.double);
    expect(dbl.dummies, 2);
    expect(Drills.counts(dbl, const DrillShot(touched: 1)), isFalse);
    expect(Drills.counts(dbl, const DrillShot(touched: 2)), isTrue);
    final smash = drills.firstWhere((d) => d.check == DrillCheck.shatter);
    expect(Drills.counts(smash, const DrillShot(touched: 1, out: 1)), isFalse);
    expect(
      Drills.counts(smash, const DrillShot(touched: 1, out: 1, critical: true)),
      isTrue,
    );
  });

  test('차례대로 열리고, 처음 깨면 내공·수련 포인트 · 숙련은 판 설정에 붙는다', () {
    final p = Profile();
    expect(Drills.open(p), 1);
    for (var k = 0; k < 9; k++) {
      Drills.record(p, 0, const DrillShot(touched: 1));
    }
    expect(p.drillCleared, 0);
    final step = Drills.record(p, 0, const DrillShot(touched: 1));
    expect(step.cleared, isTrue);
    expect(step.reward!.naegong, 30);
    expect(p.drillCleared, 1);
    expect(Drills.open(p), 2);
    // 다시 깨면 보상 없음.
    for (var k = 0; k < 10; k++) {
      final s = Drills.record(p, 0, const DrillShot(touched: 1));
      if (k == 9) expect(s.reward, isNull);
    }
    // 끌어치기(3단계)를 처음 깨면 회전 숙련.
    p.drillCleared = 2;
    final spin = p.spinScale;
    for (var k = 0; k < 5; k++) {
      Drills.record(p, 2, const DrillShot(touched: 1, hit: -0.8));
    }
    expect(p.perks, contains(perkSpin));
    expect(p.spinScale, closeTo(spin + 0.1, 1e-9));
  });

  test('연속 정타는 빗나가면 처음부터', () {
    final p = Profile()..drillCleared = 9;
    for (var k = 0; k < 6; k++) {
      Drills.record(p, 9, const DrillShot(touched: 1));
    }
    expect(p.drillProgress, 6);
    Drills.record(p, 9, const DrillShot(touched: 0));
    expect(p.drillProgress, 0);
  });

  test('수련 진행은 저장했다 불러와도 그대로', () {
    final p = Profile()
      ..drillCleared = 4
      ..drillIndex = 4
      ..drillProgress = 2;
    final q = Profile.decode(p.encode());
    expect(q.drillCleared, 4);
    expect(q.drillIndex, 4);
    expect(q.drillProgress, 2);
  });

  test('일타쌍피 수련 판은 더미 둘이 나란히 · 내 돌은 그대로 하나', () {
    final m = Match(
      const MatchConfig(
        mode: MatchMode.practice,
        training: true,
        trainingDummies: 2,
      ),
    );
    expect(m.table.stones.where((s) => s.team == 1), hasLength(2));
    expect(m.table.stones.where((s) => s.team == 0), hasLength(1));
    m.resetTraining(-3, -5);
    final d = [
      for (final s in m.table.stones)
        if (s.team == 1) s.position.clone(),
    ];
    expect((d[1] - d[0]).length, closeTo(2.6, 1e-6));
    m.dispose();
  });

  test('검지 튕기기 안내·실패 도움말 및 손가락 스와이프(!pulled) 판정', () {
    final flick = drills[5];
    expect(flick.check, DrillCheck.flick);
    expect(flick.how, isNot(contains('돌 앞에서 손끝을 떼어')));
    const disc = StoneDisc(Offset(200, 400), 100);
    final r = StrikeReader(disc)..down(const FlickSample(Offset(200, 650), 0));
    FlickShot? swipeShot;
    for (var i = 1; i <= 10 && swipeShot == null; i++) {
      swipeShot = r.move(
        FlickSample(Offset(200, 650 - 300 * i / 10), i * 0.02),
      );
    }
    expect(swipeShot, isNotNull);
    expect(swipeShot!.flick, isFalse, reason: '돌에 닿아 민 일반 스와이프');
    expect(swipeShot.pulled, isFalse, reason: '당겨 쏘기가 아닌 손가락 타격');
    expect(
      Drills.counts(flick, DrillShot(touched: 1, flick: !swipeShot.pulled)),
      isTrue,
    );
    expect(
      Drills.missHint(flick, const DrillShot(touched: 1, flick: false)),
      contains('손가락으로 돌을 밀어'),
    );
    expect(
      Drills.missHint(drills[7], const DrillShot(touched: 1, inner: false)),
      contains('내공'),
    );
  });

  test('장외·박살 수련은 첫 수부터 더미가 판 끝에 놓이고, 일타쌍피는 연쇄 충돌도 센다', () {
    final edgeMatch = Match(
      const MatchConfig(
        mode: MatchMode.practice,
        training: true,
        arena: Arena.murimIce,
        trainingEdge: true,
      ),
    );
    final dummy = edgeMatch.table.stones.firstWhere((s) => s.team == 1);
    expect(
      dummy.position.y,
      closeTo(-(edgeMatch.table.half - 3.5), 1e-6),
      reason: '첫 수부터 판 끝 가까이에 배치',
    );
    edgeMatch.dispose();

    // 일타쌍피: 두 더미를 세로로 붙여 놓고 아래 더미만 정통으로 맞혀도 연쇄 충돌로 둘 다 인정.
    final chain = Match(
      const MatchConfig(
        mode: MatchMode.practice,
        training: true,
        trainingDummies: 2,
      ),
    );
    final d1 = chain.table.stones[1];
    final d2 = chain.table.stones[2];
    d1.body.setTransform(Vector2(0, 0), d1.body.rotation);
    d2.body.setTransform(Vector2(0, -2.55), d2.body.rotation);
    chain.shoot(chain.table.stones[0], -math.pi / 2, 95, 0);
    var guard = 0;
    while (chain.isMoving && guard++ < 2000) {
      chain.step();
    }
    expect(chain.touchedThisTurn, equals({d1.id}), reason: '직접 닿은 돌은 앞 더미 하나');
    expect(
      chain.bumpedThisTurn,
      containsAll([d1.id, d2.id]),
      reason: '앞 더미가 뒤 더미를 친 연쇄 충돌까지 일타쌍피로 인정',
    );
    chain.dispose();
  });
}
