import 'dart:io';

import 'package:alkkagi/game/arena.dart';
import 'package:alkkagi/progress/daily.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/ui/art.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('출석(설계서 §16.9)', () {
    test('하루 한 번 · 7칸을 차례로 · 빠진 날이 있어도 끊기지 않음', () {
      final p = Profile();
      expect(Attendance.canClaim(p, '20261011'), isTrue);
      final r1 = Attendance.claim(p, '20261011')!;
      expect(p.coins, attendanceRewards[0].coins);
      expect(r1.coins, 100);
      expect(Attendance.claim(p, '20261011'), isNull, reason: '같은 날 두 번 안 됨');
      // 사흘 건너뛰어도 다음 칸(2일째).
      Attendance.claim(p, '20261015');
      expect(p.trainingPoints, attendanceRewards[1].tp);
      for (var d = 16; d <= 20; d++) {
        Attendance.claim(p, '202610$d');
      }
      expect(p.attendCount, 7);
      expect(Attendance.nextIndex(p), 0, reason: '7일 뒤 처음으로');
      final coins = attendanceRewards.fold<int>(0, (a, r) => a + r.coins);
      expect(p.coins, coins);
    });
  });

  group('일일 임무', () {
    test('날마다 셋 · 다 하면 받기 · 셋 다 받으면 덤 · 날이 바뀌면 새로', () {
      final p = Profile();
      const day = '20261011';
      final ms = Missions.of(day);
      expect(ms.length, 3);
      expect(ms.map((m) => m.deed).toSet().length, 3, reason: '같은 임무 둘 없음');
      expect(Missions.claim(p, 0, day), isNull, reason: '아직 안 함');
      for (final m in ms) {
        Missions.record(p, m.deed, day, m.goal);
      }
      final before = p.coins + p.silver + p.trainingPoints;
      for (var i = 0; i < 3; i++) {
        expect(Missions.claim(p, i, day), isNotNull);
        expect(Missions.claim(p, i, day), isNull, reason: '두 번 안 됨');
      }
      expect(p.coins + p.silver + p.trainingPoints, greaterThan(before));
      expect(Missions.hasClaimable(p, day), isTrue, reason: '덤이 남음');
      expect(Missions.claimBonus(p, day), isNotNull);
      expect(Missions.claimBonus(p, day), isNull);
      expect(Missions.hasClaimable(p, day), isFalse);
      // 다음 날: 오늘 센 것은 처음부터, 평생 센 것은 그대로.
      final knocks = p.lifetime[Deed.knock] ?? 0;
      Missions.record(p, Deed.knock, '20261012');
      expect(p.missionCounts[Deed.knock], 1);
      expect(p.lifetime[Deed.knock], knocks + 1);
    });

    test('날짜마다 고르는 임무가 돈다', () {
      final a = Missions.of('20261011').map((m) => m.deed).toList();
      final b = Missions.of('20261012').map((m) => m.deed).toList();
      expect(a, isNot(equals(b)));
    });
  });

  group('업적', () {
    test('평생 센 수로 열리고 한 번만 받는다', () {
      final p = Profile();
      final first = achievements.firstWhere((a) => a.id == 'win1');
      expect(Achievements.ready(p, first), isFalse);
      Missions.record(p, Deed.win, '20261011');
      expect(Achievements.ready(p, first), isTrue);
      expect(Achievements.claim(p, first), isNotNull);
      expect(Achievements.claim(p, first), isNull);
      expect(p.achieved, contains('win1'));
    });
  });

  group('별', () {
    test('이기면 1 · 절반 넘게 남기면 2 · 하나도 안 잃으면 3 · 지면 0', () {
      expect(starsFor(won: false, myLeft: 8, myStart: 8), 0);
      expect(starsFor(won: true, myLeft: 8, myStart: 8), 3);
      expect(starsFor(won: true, myLeft: 5, myStart: 8), 2);
      expect(starsFor(won: true, myLeft: 4, myStart: 8), 1);
      expect(starsFor(won: true, myLeft: 1, myStart: 8), 1);
    });

    test('더 좋은 별만 남긴다', () {
      final p = Profile();
      expect(recordStars(p, 'c1', 2), 2);
      expect(recordStars(p, 'c1', 1), 0);
      expect(recordStars(p, 'c1', 3), 1);
      expect(p.stars['c1'], 3);
      expect(p.totalStars, 3);
    });
  });

  test('새 칸들이 저장·불러오기를 거쳐도 그대로', () {
    final p = Profile()
      ..tutorialDone = true
      ..attendDay = '20261011'
      ..attendCount = 4;
    Missions.record(p, Deed.critical, '20261011', 2);
    p.missionClaimed.add(1);
    p.achieved.add('win1');
    p.stars['c2'] = 2;
    final q = Profile.decode(p.encode());
    expect(q.tutorialDone, isTrue);
    expect(q.attendDay, '20261011');
    expect(q.attendCount, 4);
    expect(q.missionDay, '20261011');
    expect(q.missionCounts[Deed.critical], 2);
    expect(q.lifetime[Deed.critical], 2);
    expect(q.missionClaimed, {1});
    expect(q.achieved, {'win1'});
    expect(q.stars, {'c2': 2});
  });

  test('입문이 생기기 전 저장은 입문을 한 번 거친다(진행은 그대로)', () {
    final old = Profile()
      ..hero = Fighter.seokdu
      ..coins = 500;
    final j = old.toJson()..remove('tutorial');
    final p = Profile.fromJson(j);
    expect(p.tutorialDone, isFalse);
    expect(p.hero, Fighter.seokdu);
    expect(p.coins, 500);
  });

  test('그림 파일이 모두 있다(캐릭터 두 자세·아이콘·배경·대전장 바닥)', () {
    final want = [
      for (final id in Art.characterIds) ...[Art.character(id), Art.character(id, attack: true)],
      ...Art.iconNames.map(Art.icon),
      Art.background('lobby'),
      for (final a in Arena.values) ...[Art.arenaBackground(a), Art.floor(a)],
    ];
    for (final f in want) {
      final file = File(f);
      expect(file.existsSync(), isTrue, reason: f);
      expect(file.lengthSync(), greaterThan(500), reason: f);
    }
    // 고를 수 있는 캐릭터·강호행 고수 모두 그림이 있다.
    for (final h in Fighter.values) {
      expect(Art.characterIds, contains(h.name), reason: h.label);
    }
    for (final b in ['촌장', '통통', '묵현', '숨은 자객', '쿠비', '로직', '무림맹주']) {
      expect(Art.bossId(b), isNotNull, reason: b);
    }
  });
}
