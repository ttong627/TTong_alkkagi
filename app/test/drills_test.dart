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
    expect(step.reward!.naegong, 15);
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
}
