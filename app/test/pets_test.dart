import 'dart:math' as math;

import 'package:alkkagi/game/arena.dart';
import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/game/pets.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

/// 영수(펫)와 어기어석 동행(2026-10-20).
void main() {
  test('영수: 날쌘돌은 처음부터 · 데려오기·먹이는 엽전 · 저장 되읽기', () {
    final p = Profile()..coins = 5000;
    expect(p.pets, {PetKind.squirrel: 1});
    expect(p.pet, PetKind.squirrel);
    expect(p.adoptPet(PetKind.tiger), isFalse, reason: '엽전 모자람');
    expect(p.adoptPet(PetKind.turtle), isTrue);
    expect(p.coins, 1000);
    expect(p.pet, PetKind.turtle);
    expect(p.feedPet(PetKind.turtle), isTrue); // 300
    expect(p.feedPet(PetKind.turtle), isTrue); // 600
    expect(p.pets[PetKind.turtle], 3);
    final back = Profile.decode(p.encode());
    expect(back.pets[PetKind.turtle], 3);
    expect(back.pet, PetKind.turtle);
    expect(back.petLevel, 3);
  });

  /// 판 하나를 만들고 내 첫 돌로 위(상대 쪽)로 쏜 뒤, 움직이기 시작한 내 돌 수.
  int launched(Match m) {
    final me = m.table.stones.firstWhere((s) => s.team == 0);
    m.shoot(me, -math.pi / 2, 90, 0, mode: m.lastMode);
    m.step();
    return m.table.stones
        .where((s) => s.team == 0 && s.velocity.length > 1)
        .length;
  }

  test('백호 합공: 켜면 돌 2개가 함께 나가고 횟수가 준다', () {
    final m = Match(
      const MatchConfig(
        mode: MatchMode.vsAi,
        arena: Arena.turtleMarket,
        pet: PetKind.tiger,
      ),
    );
    expect(m.volleysLeft, 1);
    m.toggleVolley();
    expect(m.volleyArmed, isTrue);
    expect(launched(m), 2);
    expect(m.lastVolley, isTrue);
    expect(m.volleysLeft, 0);
    m.dispose();
  });

  test('어기어석 동행: 내공 경지만큼 내 돌이 함께 나간다', () {
    final m = Match(
      const MatchConfig(
        mode: MatchMode.vsAi,
        arena: Arena.turtleMarket,
        ultimateWing: 2,
        myStartQi: maxQi,
      ),
    );
    final me = m.table.stones.firstWhere((s) => s.team == 0);
    m.shoot(me, -math.pi / 2, 90, 0, mode: StrikeMode.ultimate);
    m.step();
    expect(m.lastWing, 2);
    expect(
      m.table.stones.where((s) => s.team == 0 && s.velocity.length > 1),
      hasLength(3),
    );
    m.dispose();
  });

  test('금강 수호: 상대 수에 내 돌이 덜 밀린다', () {
    double pushed(int level) {
      final t = Table()..heroGuard = PetKind.guard(level);
      final foe = t.addStone(0, -2.4, team: 1);
      final me = t.addStone(0, 0);
      t.shoot(foe, math.pi / 2, 30, 0);
      var guard = 0;
      while (t.impacts.isEmpty && guard++ < 600) {
        t.step();
      }
      final v = me.velocity.length;
      t.dispose();
      return v;
    }

    expect(pushed(10), lessThan(pushed(1)));
    expect(PetKind.guard(10), closeTo(0.6, 0.02));
  });
}
