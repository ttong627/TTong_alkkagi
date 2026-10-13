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
    double? aiPowerScale,
    double? aiBlunder,
    AiStyle? aiStyle,
    int? bossQi,
    StoneMaterial? bossMaterial,
  }) {
    final t = tune(s, easy: easy);
    return playerConfig(
      p,
      arena: s.arena,
      difficulty: s.difficulty,
      aiErrorScale: aiErrorScale ?? t.errorScale,
      aiPowerScale: aiPowerScale ?? t.powerScale,
      aiBlunder: aiBlunder ?? t.blunder,
      opponentMaterial: bossMaterial ?? t.bossMaterial ?? s.material,
      myMaterial: t.myMaterial,
      opponentShape: s.shape,
      opponentMartial: rivalMartial(s, p.rebirths),
      aiStyle: aiStyle ?? s.style,
      opponentStartQi: bossQi ?? t.bossQi ?? s.bossQi,
      opponentName: s.boss,
      aimAssist: aimAssistFor(s),
      weather: s.weather,
      features: [...s.features, if (p.rebirths > 0) ...rebirthFeatures],
      civilians: s.civilians,
      shiftingFloor: s.shiftingFloor,
      qiClash: true,
    );
  }

  /// 판마다 고수를 얼마나 누그러뜨리나(설계서 §16.16 · 가상 대전 tool/campaign_sim.dart 로 맞춘 값 [가정]).
  ///
  /// 2026-10-11 형 「단계별 차이가 너무 많이 나지 않게 · 쉬움은 2막 보스 전까지 쉽게 깰 수 있게」.
  /// 실측(보통 사람 손 흉내 · 평타만): 예전엔 1장 53% → 2장 통통 8% → 숙적1 61% → 3장 18% … 숙적3·6장 0%.
  /// 가장 큰 벽은 고수의 **현철 돌**(밀도 2.5배)이었다 — 같은 AI 라도 통통이 청옥이면 58%.
  static AiTune tune(Stage s, {bool easy = false}) =>
      (easy ? _easy : _normal)[s.id] ?? const AiTune();

  /// 쉬움 — 실측(PROG=1, 60판): 보통 사람 손 1장 ~90% · 2장 ~80% … 6장 40% / 초보 손 1장 85% · 2장 70% · 숙적1 57%.
  static const _easy = <String, AiTune>{
    'c1': AiTune(errorScale: 4, blunder: 0.3),
    'c2': AiTune(
      errorScale: 4,
      blunder: 0.3,
      bossMaterial: StoneMaterial.cheongok,
      note: ('통통', '허허, 처음 왔구먼. 오늘은 가벼운 청옥 돌로 상대해 주지!'),
    ),
    'r1': AiTune(errorScale: 3, blunder: 0.3),
    'c3': AiTune(errorScale: 3),
    'c4': AiTune(errorScale: 3),
    'r2': AiTune(errorScale: 3),
    'c5': AiTune(errorScale: 2),
    'r3': AiTune(errorScale: 3, bossQi: 1),
    'c6': AiTune(errorScale: 4, blunder: 0.3, bossQi: 0),
  };

  /// 보통 — 실측(보통 사람 손): 65 · 43 · 58 · 50 · 50 · 58 · 87 · 28 · 28%(예전 53 · 8 · 61 · 18 · 42 · 31 · 43 · 0 · 0%).
  static const _normal = <String, AiTune>{
    'c1': AiTune(errorScale: 1.5),
    'c2': AiTune(
      errorScale: 1.5,
      myMaterial: StoneMaterial.hyeoncheol,
      note: ('통통', '현철엔 현철이지! 내 돌 한 벌 빌려줄 테니 공평하게 붙어 보세.'),
    ),
    'c3': AiTune(errorScale: 2.2),
    'c4': AiTune(errorScale: 1.5),
    'r3': AiTune(errorScale: 2.5, bossQi: 1),
    'c6': AiTune(errorScale: 1.5, bossQi: 2),
  };

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
    double aiPowerScale = 1,
    double aiBlunder = 0,
    StoneMaterial? myMaterial,
    int opponentStones = stonesPerTeam,
  }) {
    final h = p.hero;
    final perkKnock = p.perks.contains('장외 시 기');
    return MatchConfig(
      mode: MatchMode.vsAi,
      difficulty: difficulty,
      myMaterial: myMaterial ?? p.material,
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
      aiPowerScale: aiPowerScale,
      aiBlunder: aiBlunder,
      opponentStones: opponentStones,
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

/// 판 하나의 고수 누그러뜨리기([Campaign.tune]).
class AiTune {
  const AiTune({
    this.errorScale = 1,
    this.powerScale = 1,
    this.blunder = 0,
    this.bossMaterial,
    this.myMaterial,
    this.bossQi,
    this.note,
  });

  /// 손 오차 배수 · 세기 배수 · 실수 확률([MatchConfig.aiErrorScale] 등).
  final double errorScale;
  final double powerScale;
  final double blunder;

  /// 고수 돌 재질·내 돌 재질(이 판만)·고수 시작 내공(null 이면 판 그대로).
  final StoneMaterial? bossMaterial;
  final StoneMaterial? myMaterial;
  final int? bossQi;

  /// 바뀐 것을 알려 주는 대사 한 줄(판 앞 대사 끝에 붙는다).
  final (String, String)? note;
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
