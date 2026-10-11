import 'package:alkkagi_physics/alkkagi_physics.dart';

import '../game/arena.dart';
import '../game/flick.dart';
import '../game/match.dart';
import '../progress/profile.dart';
import 'chapters.dart';

/// 강호행 진행 규칙(설계서 §7.3·§16.1·§16.4). 화면과 떨어진 순수한 계산.
abstract final class Campaign {
  /// [i] 번째 판이 막힌 까닭. 열려 있으면 null.
  static String? lockReason(Profile p, int i) {
    final s = campaign[i];
    if (i > 0 && !p.done.contains(campaign[i - 1].id)) {
      return '앞 판(${campaign[i - 1].title})을 먼저 깨세요';
    }
    if (p.stage < s.needStage) {
      final (name, need) = naegongStages[s.needStage - 1];
      return '내공 $name(${need.toInt()}) 이 필요합니다 — 목인항에서 수련하세요';
    }
    return null;
  }

  /// 이 판을 칠 판 설정: 내 돌·무공·능력치와 고수의 돌·버릇.
  /// 환생 세계(설계서 §10.2): 같은 판에 블랙홀·지뢰석이 더해진다(처음 줄·다른 지물과 2cm 넘게 떨어진 자리).
  static const rebirthFeatures = [
    Feature(FeatureKind.blackHole, 9.5, -6),
    Feature(FeatureKind.mine, -9.5, 6),
  ];

  /// 숙적 묵현은 환생할 때마다 다른 문파의 무공을 익혀 나타난다(설계서 §9.2).
  static Technique rivalMartial(Stage s, int rebirths) {
    if (s.rival == null || rebirths == 0) return s.martial;
    const order = [
      Technique.swordQi,
      Technique.stomp,
      Technique.taiji,
      Technique.clone,
    ];
    final i = order.indexOf(s.martial);
    return order[(i < 0 ? 0 : i + rebirths) % order.length];
  }

  static MatchConfig configFor(
    Profile p,
    Stage s, {
    bool easy = false,
    double? aiErrorScale,
  }) => playerConfig(
    p,
    arena: s.arena,
    difficulty: s.difficulty,
    aiErrorScale: aiErrorScale ?? (easy ? easyErrorScale(s) : 1),
    opponentMaterial: s.material,
    opponentShape: s.shape,
    opponentMartial: rivalMartial(s, p.rebirths),
    aiStyle: s.style,
    opponentStartQi: s.bossQi,
    opponentName: s.boss,
    aimAssist: aimAssistFor(s),
    weather: s.weather,
    features: [...s.features, if (p.rebirths > 0) ...rebirthFeatures],
    civilians: s.civilians,
    shiftingFloor: s.shiftingFloor,
    qiClash: true,
  );

  /// 강호행 「쉬움」: 판마다 AI 손 오차 배수(가상 대전으로 맞춘다 · 설계서 §16.16).
  static double easyErrorScale(Stage s) => 1;

  /// 예상 궤적(설계서 §7.1): 1~2장 두 번째 충돌까지, 3~4장 첫 충돌까지, 5~6장 그 절반.
  static double aimAssistFor(Stage s) {
    final ch = s.chapter ?? (s.rival == 1 ? 2 : (s.rival == 2 ? 4 : 5));
    return ch <= 2 ? 2 : (ch <= 4 ? 1 : 0.5);
  }

  /// 내 진행(캐릭터·능력치·내공·기인방 효과)을 담은 대전 설정. 강호행·투기장·강호유랑이 같이 쓴다.
  static MatchConfig playerConfig(
    Profile p, {
    required Arena arena,
    required Difficulty difficulty,
    StoneMaterial opponentMaterial = StoneMaterial.cheongok,
    StoneShape opponentShape = StoneShape.round,
    Technique opponentMartial = Technique.none,
    AiStyle aiStyle = AiStyle.plain,
    int opponentStartQi = 0,
    String? opponentName,
    double aimAssist = 1,
    Weather weather = Weather.clear,
    List<Feature> features = const [],
    List<Placement> civilians = const [],
    bool shiftingFloor = false,
    bool qiClash = false,
    double aiErrorScale = 1,
  }) {
    final h = p.hero;
    final perkKnock = p.perks.contains('장외 시 기');
    return MatchConfig(
      mode: MatchMode.vsAi,
      difficulty: difficulty,
      myMaterial: p.material,
      myShape: p.shape,
      arena: arena,
      martial: p.school ?? Technique.none,
      opponentMaterial: opponentMaterial,
      opponentShape: opponentShape,
      opponentMartial: opponentMartial,
      aiStyle: aiStyle,
      myStartQi: p.startQi,
      opponentStartQi: opponentStartQi,
      powerScale: p.maxSpeed / baseMaxSpeed,
      spinScale: p.spinScale,
      steers: p.steersTotal,
      steerSeconds: p.steerSeconds,
      opponentName: opponentName,
      myTrail: p.trail == '기본' ? null : p.trail,
      qiSaver: p.perks.contains('내공 아낌'),
      impactScale:
          (p.perks.contains('첫 충돌 반발+5%') ? 1.05 : 1) *
          (h == Fighter.banDal ? 1.1 : 1),
      innerSpeed: h == Fighter.yonga ? 1.35 : TechniqueConstants.innerSpeed,
      critDoubleChance: h == Fighter.chwiseon ? 0.2 : 0,
      knockoutQiChance: h == Fighter.mukgaek ? 1 : (perkKnock ? 0.1 : 0),
      knockoutQiMax: h == Fighter.mukgaek ? 2 : (perkKnock ? 99 : 0),
      critWidth: h == Fighter.jeonggak ? 0.2 : CriticalRule.maxOffset,
      aimAssist: aimAssist,
      weather: weather,
      features: features,
      civilians: civilians,
      shiftingFloor: shiftingFloor,
      qiClash: qiClash,
      aiErrorScale: aiErrorScale,
      demonWorld: p.rebirths > 0,
      art: switch (h) {
        Fighter.magyo => RebirthArt.steal,
        Fighter.geomhwang => RebirthArt.homing,
        Fighter.sinseung => RebirthArt.reflect,
        _ => RebirthArt.none,
      },
    );
  }

  /// 판이 끝났다. 이겼으면 보상을 주고 무엇을 받았는지 돌려준다.
  /// [civiliansLost] 는 3장에서 떨어뜨린 백성 돌 수 — 하나에 엽전 [civilianPenalty] 를 뺀다(0 아래로는 안 감).
  static Reward finish(
    Profile p,
    Stage s, {
    required bool won,
    int civiliansLost = 0,
    int bonusCoins = 0,
  }) {
    p.codex.add('고수:${s.boss}');
    if (s.weather != Weather.clear) p.codex.add('천기:${s.weather.name}');
    for (final f in s.features) {
      p.codex.add('지물:${f.kind.name}');
    }
    final fine = civiliansLost * civilianPenalty;
    if (!won) {
      // 일타쌍피 엽전은 져도 받는다(설계서 §16.7 은 승패 조건을 두지 않았다).
      p.coins = (p.coins + bonusCoins - fine).clamp(0, 1 << 30);
      return Reward(won: false, fine: fine, bonus: bonusCoins);
    }
    final first = !p.done.contains(s.id);
    final coins = (s.coins(first: first) + bonusCoins - fine).clamp(0, 1 << 30);
    final silver = first && s.chapter != null ? 5 : 0;
    p.coins += coins;
    p.silver += silver;
    // 숙적을 처음 이기면 무림맹 징표 2(다시 이겨도 매번 주던 구멍을 막음 — 2026-10-11 경제 점검).
    if (s.rival != null && first) p.tokens += 2;
    p.done.add(s.id);
    Fighter? hero;
    final h = unlockByStage[s.id];
    if (first && h != null) {
      hero = Fighter.values.firstWhere((x) => x.name == h);
      p.heroes.add(hero);
      p.codex.add('캐릭터:$h');
    }
    return Reward(
      won: true,
      first: first,
      coins: coins,
      silver: silver,
      hero: hero,
      awaken: s.id == 'c1' && p.school == null,
      fine: fine,
      bonus: bonusCoins,
    );
  }
}

/// 한 판의 보상.
class Reward {
  const Reward({
    required this.won,
    this.first = false,
    this.coins = 0,
    this.silver = 0,
    this.hero,
    this.awaken = false,
    this.fine = 0,
    this.bonus = 0,
  });
  final bool won;
  final bool first;
  final int coins;
  final int silver;
  final Fighter? hero;

  /// 1장을 처음 깨 문파를 고를 때다.
  final bool awaken;

  /// 백성 돌을 떨어뜨려 물어 준 엽전.
  final int fine;

  /// 일타쌍피로 더 받은 엽전(이긴 판이면 [coins] 에 들어 있다).
  final int bonus;
}
