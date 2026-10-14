import 'dart:convert';
import 'dart:io';

import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/progress/daily.dart';
import 'package:alkkagi/progress/encounters.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/progress/store.dart';
import 'package:alkkagi/story/chapters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-11 적대 점검에서 찾아 고친 것들이 되살아나지 않게.
void main() {
  group('시계가 잘못 앞서 갔다 돌아와도 잠기지 않는다', () {
    test('출석: 이틀 넘게 앞선 날은 잊고, 하루 되돌린 것은 막는다', () {
      final p = Profile();
      Attendance.claim(p, '20270101');
      expect(Attendance.canClaim(p, '20261012'), isTrue, reason: '석 달 앞선 날');
      final q = Profile();
      Attendance.claim(q, '20261012');
      expect(
        Attendance.canClaim(q, '20261011'),
        isFalse,
        reason: '하루 되돌려 또 받기',
      );
    });

    test('임무: 앞선 날의 셈이 남지 않고, 화면 날과 받는 날이 같다', () {
      final p = Profile();
      Missions.record(p, Deed.play, '20270101', 3);
      Missions.record(p, Deed.play, '20261012');
      expect(p.missionDay, '20261012');
      expect(p.missionCounts[Deed.play], 1, reason: '날마다 새로 센다');
      expect(Missions.effectiveDay(p, '20261012'), '20261012');
      // 하루 되돌림: 받는 날과 화면 날이 함께 앞날.
      expect(Missions.effectiveDay(p, '20261011'), '20261012');
    });

    test('목인항·기연: 앞선 날은 잊는다', () {
      final p = Profile()..trainingDay = '20270101';
      p.trainHit('20261012');
      expect(p.trainingDay, '20261012');
      expect(p.trainingHits, 1);
      final q = Profile()
        ..encounterDay = '20270101'
        ..encountersToday = encountersPerDay;
      expect(takeEncounterTurn(q, '20261012'), isTrue);
    });

    test('진기: 시계를 되돌린 채 쓰고 다시 돌려도 공짜로 차지 않는다', () {
      const hour = 3600 * 1000;
      final p = Profile()
        ..stamina = 50
        ..staminaAt = 100 * hour;
      // 한 시간 되돌려 쓴다 → 시각은 앞선 값 그대로.
      expect(p.spendStamina(99 * hour, 10), isTrue);
      expect(p.staminaAt, 100 * hour);
      expect(p.staminaNow(100 * hour), 40, reason: '되돌린 한 시간만큼 공짜로 차면 안 됨');
      // 50일 앞선 시각(잘못된 시계)은 지금으로(10-14 유예 이틀 → 30일).
      final q = Profile()
        ..stamina = 50
        ..staminaAt = (100 + 50 * 24) * hour;
      q.spendStamina(100 * hour, 1);
      expect(q.staminaAt, 100 * hour);
    });

    // 2026-10-14 점검: 유예 이틀이면 날짜를 사흘 앞뒤로 흔들어 출석을 계속 다시 받았다.
    test('출석: 사흘 앞서 받고 되돌려도 또 받지 못한다', () {
      final p = Profile();
      Attendance.claim(p, '20261015');
      expect(Attendance.canClaim(p, '20261012'), isFalse);
    });
  });

  group('경제 점검', () {
    test('비급은 환생 한 번에 셋까지 · 보급소 값은 오른다', () {
      final p = Profile();
      expect(p.secretArtPrice, 10);
      expect(p.gainSecretArt(), isTrue);
      expect(p.secretArtPrice, 20);
      p.gainSecretArt();
      p.gainSecretArt();
      expect(p.gainSecretArt(), isFalse);
      expect(p.secretArts, Profile.maxSecretArts);
    });

    test('기연은 하루 상한까지만 뽑는다', () {
      final p = Profile();
      for (var i = 0; i < encountersPerDay; i++) {
        expect(takeEncounterTurn(p, '20261012'), isTrue);
      }
      expect(takeEncounterTurn(p, '20261012'), isFalse);
      expect(takeEncounterTurn(p, '20261013'), isTrue, reason: '다음 날 새로');
    });

    test('난이도: 5장·숙적 3 은 숙련, 6장은 어려움', () {
      Stage s(String id) => campaign.firstWhere((x) => x.id == id);
      expect(s('c5').difficulty, Difficulty.skilled);
      expect(s('r3').difficulty, Difficulty.skilled);
      expect(s('c6').difficulty, Difficulty.hard);
      expect(Difficulty.skilled.angleError, lessThan(0.05));
      expect(Difficulty.skilled.angleError, greaterThan(0.015));
    });
  });

  group('저장·백업 코드', () {
    test('이상한 숫자(무한대·음수·넘침)는 쓸 수 있는 범위로', () {
      final j = Profile().toJson()
        ..['coins'] = -5
        ..['naegong'] = double.infinity
        ..['tp'] = double.nan
        ..['tokens'] = 1 << 62;
      final p = Profile.fromJson(j);
      expect(p.coins, 0);
      expect(p.naegong, 0);
      expect(p.trainingPoints, 0);
      expect(p.tokens, lessThanOrEqualTo(1000000000));
    });

    test('모르는 저장 판은 거절', () {
      expect(() => Profile.decode('{"v":2}'), throwsFormatException);
      expect(Profile.decode('{"v":1}').coins, 0);
    });

    test('압축 폭탄: 풀린 크기가 한도를 넘으면 멈춘다', () {
      final bomb = gzip.encode(List<int>.filled(4 * 1024 * 1024, 32));
      expect(
        () => ProfileStore.inflateCapped(bomb, 512 * 1024),
        throwsFormatException,
      );
      final ok = gzip.encode(utf8.encode('{"v":1}'));
      expect(utf8.decode(ProfileStore.inflateCapped(ok, 1024)), '{"v":1}');
    });

    test('백업 코드: 너무 긴 코드·폭탄 코드는 거절하고 진행은 그대로', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ProfileStore.instance..profile = (Profile()..coins = 77);
      expect(await store.importCode('TJ1-0000-${'A' * 70000}'), isFalse);
      final body = base64Url.encode(
        gzip.encode(utf8.encode('{"v":1,"coins":5}${' ' * 3000000}')),
      );
      var h = 0;
      for (final c in body.codeUnits) {
        h = (h * 31 + c) & 0xFFFF;
      }
      final code = 'TJ1-${h.toRadixString(16).padLeft(4, '0')}-$body';
      expect(code.length, lessThan(ProfileStore.maxCodeLength));
      expect(await store.importCode(code), isFalse);
      expect(store.profile.coins, 77);
      // 정상 코드는 그대로 된다.
      final good = store.exportCode();
      store.profile = Profile();
      expect(await store.importCode(good), isTrue);
      expect(store.profile.coins, 77);
    });

    test('깨진 저장은 옮겨 두고 직전 정상본으로 되살린다', () async {
      final good = (Profile()..coins = 321).encode();
      SharedPreferences.setMockInitialValues({
        'profile.v1': '{깨짐',
        'profile.v1.bak': good,
      });
      final store = await ProfileStore.load();
      expect(store.profile.coins, 321);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('profile.v1.corrupt'), '{깨짐');
    });

    test('저장할 때 직전 내용을 백업으로 남긴다', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ProfileStore.instance..profile = (Profile()..coins = 1);
      expect(await store.save(), isTrue);
      store.profile.coins = 2;
      await store.save();
      final prefs = await SharedPreferences.getInstance();
      expect(Profile.decode(prefs.getString('profile.v1.bak')!).coins, 1);
      expect(Profile.decode(prefs.getString('profile.v1')!).coins, 2);
    });
  });
}
