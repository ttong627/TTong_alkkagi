import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/progress/encounters.dart';
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
    // 2026-10-11 경제 점검: 0/90/270/540/900/1260/1800/2700(예전 끝 단계 4800 은 수개월 걸렸다).
    expect(stageOf(0), 1);
    expect(stageOf(89.9), 1);
    expect(stageOf(90), 2);
    expect(stageOf(1600), 6);
    expect(stageOf(2699), 7);
    expect(stageOf(2700), 8);
    expect(stageOf(9999), 8);
    final p = Profile()..naegong = 1600;
    expect(p.stageName, '화경');
    expect(p.startQi, 1);
    expect(p.steers, 2);
  });

  test('능력치: 단계 n→n+1 비용 6×(n+1), 파워 단계마다 +1.5cm/s, 20단계 150', () {
    final p = Profile()..trainingPoints = 100000;
    for (var i = 0; i < 25; i++) {
      p.raise(Stat.power);
    }
    expect(p.stats[Stat.power], maxStatLevel);
    expect(p.maxSpeed, 150);
    expect(p.trainingPoints, 100000 - 1260);
    final q = Profile()..trainingPoints = 10;
    expect(q.raise(Stat.finesse), isTrue);
    expect(q.raise(Stat.finesse), isFalse, reason: '두 번째는 12 필요');
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
      // 다시 깨면 처음 값의 절반의 절반(기본의 반 — 1장 되풀이로 엽전을 벌지 않게 · 2026-10-11).
      final again = Campaign.finish(p, campaign[0], won: true);
      expect(again.coins, 20);
      expect(again.first, isFalse);
      final c2 = campaign.firstWhere((s) => s.id == 'c2');
      expect(Campaign.finish(p, c2, won: true).hero, Fighter.banDal);
      // 숙적: 처음 이기면 징표 2, 다시 이기면 징표 없음.
      final r = campaign.firstWhere((s) => s.id == 'r1');
      final tokens = p.tokens;
      expect(Campaign.finish(p, r, won: true).coins, 100);
      expect(p.tokens, tokens + 2);
      Campaign.finish(p, r, won: true);
      expect(p.tokens, tokens + 2, reason: '숙적 되풀이로 징표를 벌지 않는다');
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
      // 시작 내공은 판 표(3)를 보통 난이도 표가 2로 누그러뜨린다(설계서 §16.16).
      expect(c.opponentStartQi, Campaign.tune(s).bossQi ?? s.bossQi);
      expect(c.opponentStartQi, 2);
      expect(c.myStartQi, 1);
      // 단계마다 +1.5cm/s(2026-10-11 · 예전 +3).
      expect(c.powerScale, closeTo(135 / 120, 1e-9));
      expect(c.steers, 2);
    });

    test('지형·날씨가 판 설정과 판에 들어간다(설계서 §9.1·§9.3·§9.4)', () {
      final p = Profile();
      Stage st(String id) => campaign.firstWhere((s) => s.id == id);
      expect(Campaign.configFor(p, st('c3')).civilians.length, 5);
      expect(Campaign.configFor(p, st('c4')).features.length, 5);
      expect(Campaign.configFor(p, st('c5')).features.length, 3);
      expect(Campaign.configFor(p, st('c6')).shiftingFloor, isTrue);
      expect(Campaign.configFor(p, st('r1')).weather, Weather.nightRain);
      expect(Campaign.configFor(p, st('r2')).weather, Weather.gale);
      expect(Campaign.configFor(p, st('r3')).weather, Weather.frost);
      // 판을 실제로 만들어 본다: 백성 돌은 편 2, 처음 줄 돌과 지물·백성 돌이 2cm 안에 겹치지 않는다.
      for (final s in campaign) {
        final m = Match(Campaign.configFor(p, s));
        expect(
          m.table.stones.where((x) => x.team == 2).length,
          s.civilians.length,
        );
        final things = [
          for (final f in s.features) (f.x, f.y),
          for (final c in s.civilians) (c.x, c.y),
        ];
        for (final stone in m.table.stones.where((x) => x.team != 2)) {
          final pos = stone.body.position;
          for (final (x, y) in things) {
            final d = (pos.x - x) * (pos.x - x) + (pos.y - y) * (pos.y - y);
            expect(d, greaterThan(4), reason: '${s.id} ($x,$y)');
          }
        }
        m.dispose();
      }
    });

    test('백성 돌을 떨어뜨리면 하나에 엽전 10 을 물어 준다(0 아래로는 안 감)', () {
      final p = Profile()..coins = 15;
      final c3 = campaign.firstWhere((s) => s.id == 'c3');
      final win = Campaign.finish(p, c3, won: true, civiliansLost: 2);
      expect(win.fine, 20);
      expect(win.coins, 120 - 20); // 3장 = 30 + 3×10 = 60, 처음 깬 판 ×2 = 120
      expect(p.coins, 15 + 100);
      final lose = Campaign.finish(p, c3, won: false, civiliansLost: 20);
      expect(lose.fine, 200);
      expect(p.coins, 0);
    });

    test('강호행은 9판(6장 + 숙적 3)이고 id 가 겹치지 않는다', () {
      expect(campaign.length, 9);
      expect(campaign.map((s) => s.id).toSet().length, 9);
      expect(campaign.where((s) => s.chapter != null).length, 6);
    });
  });

  group('환생(설계서 §10)', () {
    Profile ready() {
      final p = Profile()
        ..naegong = 3500
        ..coins = 900
        ..silver = 7
        ..tokens = 4
        ..trainingPoints = 50
        ..school = Technique.stomp;
      p.done.addAll(['c1', 'c6']);
      p.stats[Stat.power] = 12;
      p.materials.add(StoneMaterial.ice);
      p.codex.add('고수:촌장');
      return p;
    }

    test('조건: 6장 우승 + 생사경. 환생 전용 캐릭터만 고를 수 있다', () {
      final p = Profile()..naegong = 3500;
      expect(p.canRebirth, isFalse);
      p.done.add('c6');
      expect(p.canRebirth, isTrue);
      expect(p.rebirth(Fighter.seokdu), isFalse);
      expect(Fighter.values.where((f) => f.rebirth).length, 3);
    });

    test('처음으로 / 그대로 / 얻음', () {
      final p = ready();
      expect(p.rebirth(Fighter.magyo), isTrue);
      // 처음으로
      expect(p.naegong, 0);
      expect(p.stage, 1);
      expect(p.stats[Stat.power], 0);
      expect(p.done, isEmpty);
      expect(p.coins, 0);
      expect(p.trainingPoints, 0);
      expect(p.school, isNull);
      // 그대로
      expect(p.silver, 7);
      expect(p.tokens, 4);
      expect(p.materials, contains(StoneMaterial.ice));
      expect(p.codex, contains('고수:촌장'));
      // 얻음
      expect(p.rebirths, 1);
      expect(p.danCores, 1);
      expect(p.hero, Fighter.magyo);
      expect(p.heroes, contains(Fighter.magyo));
      expect(p.canRebirth, isFalse);
    });

    test('윤회천기: 내단 1개로 한 칸, 갈래마다 3칸 — 30타 내공 90 → 150 · 진기 160 · 기인방 0.8%', () {
      final p = Profile()..danCores = 9;
      expect(Training.dayTotal(30, first: p.trainingFirst), closeTo(90, 1e-9));
      for (var i = 0; i < 4; i++) {
        p.openTree(TreeNode.training);
        p.openTree(TreeNode.stamina);
        p.openTree(TreeNode.legend);
      }
      expect(p.danCores, 0);
      expect(p.tree[TreeNode.training], 3);
      expect(Training.dayTotal(30, first: p.trainingFirst), closeTo(150, 1e-9));
      expect(p.staminaMax, 160);
      expect(legendaryChance(p.tree[TreeNode.legend]!), closeTo(0.008, 1e-12));
      expect(p.openTree(TreeNode.legend), isFalse);
    });

    test('환생 세계: 블랙홀·지뢰석이 더해지고 묵현 무공이 바뀐다 · 저장 되읽기', () {
      final p = ready()..rebirth(Fighter.sinseung);
      final r1 = campaign.firstWhere((s) => s.id == 'r1');
      final c = Campaign.configFor(p, r1);
      expect(c.demonWorld, isTrue);
      expect(
        c.features.map((f) => f.kind),
        containsAll([FeatureKind.blackHole, FeatureKind.mine]),
      );
      expect(c.opponentMartial, isNot(r1.martial));
      final back = Profile.decode(p.encode());
      expect(back.rebirths, 1);
      expect(back.danCores, 1);
      expect(back.hero, Fighter.sinseung);
    });
  });

  test('외형: 앞 3가지는 처음부터, 나머지는 은자 5개 · 저장 되읽기', () {
    final p = Profile()..silver = 6;
    expect(p.hairs, {0, 1, 2});
    expect(p.buyHair(1), isFalse);
    expect(p.buyHair(4), isTrue);
    expect(p.silver, 1);
    expect(p.buyRobe(5), isFalse);
    p
      ..hair = 4
      ..face = 2
      ..robe = 1;
    final back = Profile.decode(p.encode());
    expect(back.hair, 4);
    expect(back.face, 2);
    expect(back.robe, 1);
    expect(back.hairs, contains(4));
  });
}
