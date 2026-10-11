import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/story/campaign.dart';
import 'package:alkkagi/story/chapters.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('목인항 (설계서 §5.2): 하루 처음 30타 ×3, 그 뒤 ×0.1', () {
    test('표의 값: 30타 90 · 100타 97 · 300타 117 · 1,000타 187', () {
      expect(Training.dayTotal(30), closeTo(90, 1e-9));
      expect(Training.dayTotal(100), closeTo(97, 1e-9));
      expect(Training.dayTotal(300), closeTo(117, 1e-9));
      expect(Training.dayTotal(1000), closeTo(187, 1e-9));
    });

    test('날이 바뀌면 처음부터 센다 · 30일×30타 = 2,700', () {
      final p = Profile();
      for (var d = 1; d <= 30; d++) {
        for (var i = 0; i < 30; i++) {
          p.trainHit('202611${d.toString().padLeft(2, '0')}');
        }
      }
      expect(p.naegong, closeTo(2700, 1e-6));
      expect(p.trainingPoints, closeTo(2700, 1e-6));
      final q = Profile();
      for (var i = 0; i < 900; i++) {
        q.trainHit('20261101');
      }
      expect(q.naegong, closeTo(177, 1e-6));
    });
  });

  test('내공 단계 8단계 (설계서 §16.2)', () {
    expect(stageOf(0), 1);
    expect(stageOf(99.9), 1);
    expect(stageOf(100), 2);
    expect(stageOf(1600), 6);
    expect(stageOf(9999), 8);
    final p = Profile()..naegong = 1600;
    expect(p.stageName, '화경');
    expect(p.startQi, 1);
    expect(p.steers, 2);
  });

  test('능력치: 단계 n→n+1 비용 10×(n+1), 파워 단계마다 +3cm/s, 20단계 180', () {
    final p = Profile()..trainingPoints = 100000;
    for (var i = 0; i < 25; i++) {
      p.raise(Stat.power);
    }
    expect(p.stats[Stat.power], maxStatLevel);
    expect(p.maxSpeed, 180);
    expect(p.trainingPoints, 100000 - 2100);
    final q = Profile()..trainingPoints = 15;
    expect(q.raise(Stat.finesse), isTrue);
    expect(q.raise(Stat.finesse), isFalse, reason: '두 번째는 20 필요');
  });

  test('만물상: 엽전이 있어야 사고, 산 것만 고를 수 있고, 세트를 모으면 보너스', () {
    final p = Profile()..coins = 250;
    expect(p.buyMaterial(StoneMaterial.wood), isFalse);
    expect(p.buyShape(StoneShape.round), isTrue);
    expect(p.coins, 50);
    p.coins = 10000;
    for (final m in StoneMaterial.values) {
      p.buyMaterial(m);
    }
    expect(p.codexBonus, 1);
    p.buyShape(StoneShape.sphere);
    expect(p.codexBonus, 2);
    expect(p.level(Stat.power), 2);
  });

  test('저장했다 읽으면 같다', () {
    final p = Profile()
      ..hero = Fighter.yeonbi
      ..school = Technique.taiji
      ..naegong = 321.5
      ..coins = 77
      ..trainingDay = '20261011'
      ..trainingHits = 12;
    p.done.add('c1');
    p.materials.add(StoneMaterial.ice);
    p.material = StoneMaterial.ice;
    p.stats[Stat.control] = 4;
    p.codex.add('고수:촌장');
    final q = Profile.decode(p.encode());
    expect(q.encode(), p.encode());
    expect(q.material, StoneMaterial.ice);
    expect(Profile.decode('{}').coins, 0, reason: '빈 저장도 읽힌다');
  });

  group('강호행', () {
    test('처음엔 1장만 열림 · 앞 판을 깨고 내공 단계가 되어야 다음 판', () {
      final p = Profile();
      expect(Campaign.lockReason(p, 0), isNull);
      expect(Campaign.lockReason(p, 1), contains('앞 판'));
      p.done.add('c1');
      expect(Campaign.lockReason(p, 1), contains('내공'));
      p.naegong = 100;
      expect(Campaign.lockReason(p, 1), isNull);
    });

    test('이기면 보상(처음 ×2·은자 5), 1장은 문파 각성, 장을 깨면 캐릭터', () {
      final p = Profile();
      final r1 = Campaign.finish(p, campaign[0], won: true);
      expect(r1.coins, (30 + 10) * 2);
      expect(r1.silver, 5);
      expect(r1.awaken, isTrue);
      final again = Campaign.finish(p, campaign[0], won: true);
      expect(again.coins, 40);
      expect(again.first, isFalse);
      final c2 = campaign.firstWhere((s) => s.id == 'c2');
      expect(Campaign.finish(p, c2, won: true).hero, Fighter.banDal);
      final r = campaign.firstWhere((s) => s.id == 'r1');
      expect(Campaign.finish(p, r, won: true).coins, 100);
      final lost = Campaign.finish(p, campaign[3], won: false);
      expect(lost.won, isFalse);
      expect(p.codex, contains('고수:${campaign[3].boss}'));
    });

    test('판 설정에 내 돌·무공·능력치·고수의 돌·버릇이 들어간다', () {
      final p = Profile()
        ..school = Technique.stomp
        ..naegong = 1600;
      p.stats[Stat.power] = 10;
      final s = campaign.firstWhere((s) => s.id == 'c6');
      final c = Campaign.configFor(p, s);
      expect(c.martial, Technique.stomp);
      expect(c.opponentMaterial, StoneMaterial.hyeoncheol);
      expect(c.aiStyle, AiStyle.master);
      expect(c.opponentStartQi, 3);
      expect(c.myStartQi, 1);
      expect(c.powerScale, closeTo(150 / 120, 1e-9));
      expect(c.steers, 2);
    });

    test('강호행은 9판(6장 + 숙적 3)이고 id 가 겹치지 않는다', () {
      expect(campaign.length, 9);
      expect(campaign.map((s) => s.id).toSet().length, 9);
      expect(campaign.where((s) => s.chapter != null).length, 6);
    });
  });
}
