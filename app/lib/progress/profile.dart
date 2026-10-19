import 'dart:convert';
import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart';

import 'daily.dart';

/// 캐릭터 10종 (설계서 §2.2·§16.3).
enum Fighter {
  seokdu('석두', '근력형 · 탄지 파워 +5%', starter: true),
  yeonbi('연비', '유연형 · 탄지 묘수 +0.1', starter: true),
  cheongmyeong('청명', '집중형 · 어기 +0.3초 · 판 시작 내공 +1칸', starter: true),
  banDal('반달', '통통의 제자 · 맞은 돌 +10%'),
  gurumi('구르미', '쿠비의 제자 · 회전 ×1.15'),
  jeonggak('정각', '로직의 제자 · 회심 폭 넓음'),
  yonga('용아', '맹주의 제자 · 내공 타격 ×1.35'),
  seolhwa('설화', '비무장 시즌 보상(온라인판)'),
  chwiseon('취선', '은둔 고수 · 회심 때 20% 로 내공 +2'),
  mukgaek('묵객', '은둔 고수 · 장외시키면 내공 +1(판당 2번)'),

  // 환생 전용(설계서 §10.1) — 환생할 때 하나를 만든다.
  magyo('마교 교주', '환생 · 흡성대법: 친 상대 돌의 감속을 그 판 동안 30% 빼앗음', rebirth: true),
  geomhwang(
    '검황',
    '환생 · 이기어검: 평타도 약하게 따라감, 궁극기 때 분신 둘이 다른 표적을 쫓음',
    rebirth: true,
  ),
  sinseung('신승', '환생 · 반탄공: 상대 돌에 맞을 때 30% 로 반발 2배', rebirth: true);

  const Fighter(
    this.label,
    this.trait, {
    this.starter = false,
    this.rebirth = false,
  });
  final String label;
  final String trait;
  final bool starter;

  /// 환생할 때만 만들 수 있는 캐릭터.
  final bool rebirth;
}

/// 윤회천기(설계서 §10.3): 천년내단 1개로 한 칸씩 연다(갈래마다 3칸).
enum TreeNode {
  legend('기연의 눈', '기인방 등장 0.5% → 칸마다 +0.1%p (최대 0.8%)'),
  training('깨달음', '목인항 첫 30타 보너스 600% → 최대 1000% (30타 내공 180 → 300)'),
  stamina('진기 그릇', '진기 최대 100 → 칸마다 +20 (최대 160)');

  const TreeNode(this.label, this.help);
  final String label;
  final String help;

  static const int maxLevel = 3;
}

/// 능력치 3종 (설계서 §2.3·§16.4). 0~20 단계.
enum Stat {
  power('탄지 파워', '최대 처음 속도 120 → 180cm/s'),
  finesse('탄지 묘수', '회전 효율 ×1.0 → ×1.3'),
  control('어기 정밀도', '어기어석 느린 화면 1.5 → 3.0초');

  const Stat(this.label, this.help);
  final String label;
  final String help;
}

/// 내공 단계 8단계 (설계서 §16.2).
const naegongStages = [
  ('삼류', 0.0),
  // 2026-10-11 경제 점검: 하루 깨달음 30타 = 90 이라 이류 100 이면 첫날 2장이 막혔다. 새 판이
  // 1·3·6·10·14·20·30일째에 고르게 열리게 바꿈 [가정 — 실기기로 다시 맞춘다].
  ('이류', 90.0),
  ('일류', 270.0),
  ('절정', 540.0),
  ('초절정', 900.0),
  ('화경', 1260.0),
  ('현경', 1800.0),
  ('생사경', 2700.0),
];

/// 쌓인 내공 → 단계(1~8).
int stageOf(double naegong) {
  var s = 1;
  for (var i = 0; i < naegongStages.length; i++) {
    if (naegong >= naegongStages[i].$2) s = i + 1;
  }
  return s;
}

/// 목인항 하루 수련 (설계서 §5.2): 처음 30타는 6배(깨달음), 31타부터 0.3배.
/// 2026-10-14 형 「육성 속도가 빠르게」: 3배·0.1배 → 6배·0.3배(하루 30타 내공 90 → 180).
abstract final class Training {
  static const int enlightened = 30;
  static const double bonus = 6;
  static const double after = 0.3;

  /// 그날 [hitsBefore] 타를 친 뒤 한 번 더 쳤을 때 얻는 내공. [first] 는 첫 30타 배수(윤회천기로 오름).
  static double gain(int hitsBefore, {double first = bonus}) =>
      hitsBefore < enlightened ? first : after;

  /// 하루 [hits] 타의 내공 합.
  static double dayTotal(int hits, {double first = bonus}) =>
      math.min(hits, enlightened) * first +
      math.max(0, hits - enlightened) * after;
}

/// 목인항 진행 칸 값(2026-10-14 형 「다음 목표치와 진행 상황을 알 수 있게」).
class TrainingGoal {
  const TrainingGoal({
    required this.stageName,
    required this.nextName,
    required this.have,
    required this.need,
    required this.stageProgress,
    required this.todayHits,
  });

  final String stageName;

  /// 다음 경지 이름(마지막이면 null).
  final String? nextName;

  /// 쌓인 내공 · 다음 경지에 필요한 내공(마지막이면 같은 값).
  final double have, need;

  /// 지금 경지 안에서 다음 경지까지 간 비율(0~1).
  final double stageProgress;

  /// [day] 에 친 수.
  final int todayHits;

  static TrainingGoal of(Profile p, String day) {
    final i = p.stage - 1;
    final base = naegongStages[i].$2;
    final last = i + 1 >= naegongStages.length;
    final next = last ? base : naegongStages[i + 1].$2;
    return TrainingGoal(
      stageName: naegongStages[i].$1,
      nextName: last ? null : naegongStages[i + 1].$1,
      have: p.naegong,
      need: last ? p.naegong : next,
      stageProgress: last
          ? 1
          : ((p.naegong - base) / (next - base)).clamp(0.0, 1.0),
      todayHits: p.trainingDay == day ? p.trainingHits : 0,
    );
  }
}

/// 만물상 (설계서 §6.2A·§16.4) 가격(엽전).
///
/// 2026-10-14 형 「다음 돌 구입하는 구입가를 지금 가격의 10배 이상 올려서 쉽게 바꾸지 못하게」: 모두 ×10.
/// 조각 돌(천년온옥·용린석·태극석)은 팔지 않는다 — [shardNeeds] 만큼 조각을 모아 완성.
const materialPrices = {
  StoneMaterial.cheongok: 0,
  StoneMaterial.wood: 3000,
  StoneMaterial.hyeoncheol: 6000,
  StoneMaterial.obsidian: 7500,
  StoneMaterial.granite: 8000,
  StoneMaterial.ice: 9000,
  StoneMaterial.diamond: 12000,
  StoneMaterial.jageum: 18000,
  StoneMaterial.uncheol: 26000,
  StoneMaterial.hancheol: 36000,
};
const shapePrices = {
  StoneShape.flat: 0,
  StoneShape.round: 2000,
  StoneShape.sphere: 5000,
};

/// 조각 돌을 완성하는 데 드는 조각 수(2026-10-14 형 「기연이나 이벤트에서 조각을 모아서 완성하는 돌」).
const shardNeeds = {
  StoneMaterial.warmJade: 20,
  StoneMaterial.dragonScale: 30,
  StoneMaterial.taegeuk: 40,
};

/// 가방에서 조각 돌의 조각 이름.
String shardKey(StoneMaterial m) => 'frag:${m.name}';

/// 진기(행동력) (설계서 §7.2): 최대 100, 6분에 1, 강호유랑 1칸·투기장 1회 10, 지면 50% 돌려줌.
abstract final class Stamina {
  static const int max = 100;
  static const int regenMs = 6 * 60 * 1000;
  static const double cost = 10;
}

/// 능력치 단계 n → n+1 비용(수련 포인트).
/// 2026-10-11 경제 점검: 10×(n+1)(합계 6,300)은 환생 전에 절대 못 채웠다 → 6×(n+1)(합계 3,780).
int statCost(int level) => 6 * (level + 1);
const int maxStatLevel = 20;

/// 기기에 저장하는 진행 상태(오프라인판). 온라인판에서는 서버로 옮긴다(체크리스트 3-11).
class Profile {
  Profile();

  Fighter? hero;

  /// 문파 무공. 1장을 깨면 각성해 정한다(그 전엔 null).
  Technique? school;

  /// 깬 강호행 판(장·숙적전 id).
  final done = <String>{};
  final heroes = <Fighter>{};
  double naegong = 0;
  double trainingPoints = 0;
  String trainingDay = '';
  int trainingHits = 0;
  final stats = {for (final s in Stat.values) s: 0};
  int coins = 0;
  int silver = 0;
  final materials = <StoneMaterial>{StoneMaterial.cheongok};
  final shapes = <StoneShape>{StoneShape.flat};
  StoneMaterial material = StoneMaterial.cheongok;
  StoneShape shape = StoneShape.flat;

  /// 도감: 만난 고수·얻은 것 (설계서 §8.7).
  final codex = <String>{};

  /// 무림맹 징표 (설계서 §6.1).
  int tokens = 0;

  /// 목인항 평생 타격 수(보급소 열림 조건 1,000타).
  int totalHits = 0;

  /// 진기(행동력, 설계서 §7.2)와 마지막으로 계산한 시각(밀리초).
  double stamina = Stamina.max.toDouble();
  int staminaAt = 0;

  /// 기인방 특수효과(설계서 §6.2C) — 산 물건에 붙어 온 효과들(같은 효과는 하나만).
  final perks = <String>{};

  /// 은둔 고수 비급: 모든 능력치 +n (설계서 §5.3). 환생 한 번에 [maxSecretArts] 까지(보급소·기인방·은둔 고수 합).
  int secretArts = 0;

  /// 2026-10-11 경제 점검: 상한이 없어 징표만 모으면 능력치가 최대가 됐다.
  static const int maxSecretArts = 3;

  /// 비급 하나 더 얻기(상한이면 false).
  bool gainSecretArt() {
    if (secretArts >= maxSecretArts) return false;
    secretArts++;
    return true;
  }

  /// 보급소 비급 값(징표): 10 → 20 → 30.
  int get secretArtPrice => 10 * (secretArts + 1);

  /// 폐관수련동 큰 보상을 받은 날(하루 한 번).
  String seclusionDay = '';

  /// 이번 주 강호유랑에서 이긴 전투 수(완주 보상 조건).
  int wanderWins = 0;

  /// 오늘 뽑은 기연 수(하루 상한).
  String encounterDay = '';
  int encountersToday = 0;

  /// 꾸미기: 잔상 빛깔(보급소·기인방).
  final trails = <String>{'기본'};
  String trail = '기본';

  /// 기인방이 열려 있는 끝 시각(밀리초)과 진열품.
  int legendaryUntil = 0;
  final legendary = <String>[];

  /// 깬 목인항 묘수풀이(퍼즐) 번호.
  final puzzles = <int>{};

  /// 트릭샷 판마다 가장 좋은 별(0~3).
  final puzzleStars = <int, int>{};

  /// 트릭샷 별 합계.
  int get trickStarTotal => puzzleStars.values.fold(0, (a, b) => a + b);

  /// 더 좋은 별만 남긴다. 새로 늘어난 별 수를 돌려준다.
  int recordPuzzleStars(int id, int stars) {
    final old = puzzleStars[id] ?? 0;
    if (stars <= old) return 0;
    puzzleStars[id] = stars.clamp(0, 3);
    return puzzleStars[id]! - old;
  }

  /// 강호유랑: 이번 주 번호와 지나온 칸 수.
  String wanderWeek = '';
  int wanderRow = 0;

  /// 투기장 최고 연승.
  int arenaBest = 0;

  // --- 환생(설계서 §10) ---
  /// 환생한 횟수.
  int rebirths = 0;

  /// 아직 안 쓴 천년내단.
  int danCores = 0;

  /// 윤회천기 갈래별 연 칸 수(0~3).
  final tree = {for (final n in TreeNode.values) n: 0};

  /// 외형(설계서 §2.5): 얼굴형·머리 모양·도복 색 번호. 능력치에는 영향 없다.
  int face = 0;
  int hair = 0;
  int robe = 0;

  /// 은자로 산 머리·도복 디자인 번호(기본 것은 늘 있음).
  final hairs = <int>{0, 1, 2};
  final robes = <int>{0, 1, 2};

  // --- 요즘 게임 구성(설계서 §16.9) ---
  /// 입문(강제 수련)을 마쳤나. 마치기 전에는 로비로 못 간다.
  bool tutorialDone = false;

  /// 강호행 난이도 「쉬움」(설계서 §16.16): 고수의 손 오차가 판마다 커진다. 처음엔 쉬움.
  bool easyMode = true;

  /// 출석: 마지막으로 받은 날(yyyymmdd)과 받은 횟수.
  String attendDay = '';
  int attendCount = 0;

  /// 일일 임무: 날짜, 오늘 센 수, 받은 임무 번호(99 = 셋 다 끝낸 덤).
  String missionDay = '';
  final missionCounts = <Deed, int>{};
  final missionClaimed = <int>{};

  /// 평생 센 일(업적).
  final lifetime = <Deed, int>{};

  /// 받은 업적.
  final achieved = <String>{};

  /// 가방: 재료·일회용 아이템 이름 → 개수(quests.dart · 2026-10-14).
  final bag = <String, int>{};

  /// 주간·월간·연간 퀘스트: 기간 열쇠 · 센 수('week:win' 등) · 받은 것('week:0' 등).
  final questKeys = <String, String>{};
  final questCounts = <String, int>{};
  final questClaimed = <String>{};

  /// 판마다 얻은 별(가장 좋았던 것).
  final stars = <String, int>{};

  int get totalStars => stars.values.fold(0, (a, b) => a + b);

  /// 이미 본 첫 방문 안내(화면 이름).
  final seenHints = <String>{};

  /// 축하를 보여 준 내공 경지(이보다 높아지면 로비·목인항에서 한 번 축하).
  int celebratedStage = 1;

  /// 고른 잔상(기본이면 null — 판 설정 [MatchConfig.myTrail] 에 그대로).
  String? get trailOrNull => trail == '기본' ? null : trail;

  /// 비승(환생) 메뉴가 열렸나: 6장 우승 + 내공 생사경(8단계).
  bool get canRebirth => done.contains('c6') && stage >= naegongStages.length;

  /// 목인항 첫 30타 배수: 6 → 윤회천기 「깨달음」 칸마다 +4/3 (최대 10).
  double get trainingFirst => Training.bonus + tree[TreeNode.training]! * 4 / 3;

  /// 진기 최대: 100 → 「진기 그릇」 칸마다 +20 (최대 160).
  int get staminaMax => Stamina.max + 20 * tree[TreeNode.stamina]!;

  /// 윤회천기 한 칸 열기(천년내단 1개).
  bool openTree(TreeNode n) {
    if (danCores < 1 || tree[n]! >= TreeNode.maxLevel) return false;
    danCores--;
    tree[n] = tree[n]! + 1;
    return true;
  }

  /// 환생(환골탈태, 설계서 §10): 레벨(내공·능력치)·강호행 진행·엽전·수련 포인트·문파를 처음으로,
  /// 은자·징표·재질·모양·외형·꾸미기·캐릭터·도감·기인방 효과는 그대로. 천년내단 1개와
  /// 환생 전용 캐릭터([chosen]) 하나를 얻는다.
  bool rebirth(Fighter chosen) {
    if (!canRebirth || !chosen.rebirth) return false;
    rebirths++;
    danCores++;
    naegong = 0;
    // 내공이 0 으로 돌아가니 경지 축하도 처음부터(두 번째 회차에 축하가 나오지 않던 것 · 2026-10-14 점검).
    celebratedStage = 1;
    trainingPoints = 0;
    for (final st in Stat.values) {
      stats[st] = 0;
    }
    done.clear();
    coins = 0;
    school = null;
    secretArts = 0;
    wanderRow = 0;
    heroes.add(chosen);
    hero = chosen;
    codex
      ..add('환생:$rebirths')
      ..add('캐릭터:${chosen.name}');
    return true;
  }

  int get stage => stageOf(naegong);
  String get stageName => naegongStages[stage - 1].$1;

  /// 다음 단계까지 남은 내공(마지막 단계면 null).
  double? get toNextStage =>
      stage >= naegongStages.length ? null : naegongStages[stage].$2 - naegong;

  // --- 능력치 값 ---
  /// 능력치 단계 + 도감 세트 보너스 + 은둔 고수 비급(최대 20).
  int level(Stat s) =>
      math.min(maxStatLevel, stats[s]! + codexBonus + secretArts);

  /// 어기어석 꺾기: 내공 단계 + 기인방 효과 「꺾기 +1」.
  int get steersTotal => steers + (perks.contains('꺾기+1') ? 1 : 0);

  // --- 진기 ---
  /// 지금(밀리초) 진기. 6분마다 1 찬다(최대 [Stamina.max]).
  double staminaNow(int now) {
    if (staminaAt == 0) return stamina;
    // 시계를 되돌려도 줄지 않게(0 아래로 안 감).
    final regen = math.max(0, now - staminaAt) / Stamina.regenMs;
    return math.min(staminaMax.toDouble(), stamina + regen);
  }

  /// 진기 시각을 [now]로 옮긴다. 시계를 되돌린 채 쓰고 다시 돌려 그 사이 진기를 공짜로 채우지 못하게,
  /// 저장된 시각이 더 뒤면 그대로 둔다 — 단 30일 넘게 앞서 있으면(시계가 잘못 앞서 갔던 흔적) [now]로(10-14 이틀 → 30일).
  /// 2026-10-11 점검.
  void _markStamina(int now) {
    const grace = 30 * Duration.millisecondsPerDay;
    staminaAt = (staminaAt > now && staminaAt - now <= grace) ? staminaAt : now;
  }

  /// 진기를 쓴다. 모자라면 false.
  bool spendStamina(int now, double n) {
    final cur = staminaNow(now);
    if (cur < n) return false;
    stamina = cur - n;
    _markStamina(now);
    return true;
  }

  void refundStamina(int now, double n) {
    stamina = math.min(staminaMax.toDouble(), staminaNow(now) + n);
    _markStamina(now);
  }

  /// 무림맹 보급소가 열렸나(설계서 §6.2B): 주말, 또는 목인항 1,000타, 또는 6장 격파.
  bool depotOpen(DateTime now) =>
      now.weekday >= DateTime.saturday ||
      totalHits >= 1000 ||
      done.contains('c6');

  /// 기인방이 지금 열려 있나(10분).
  bool legendaryOpen(int now) => now < legendaryUntil && legendary.isNotEmpty;

  /// 단계마다 +1.5cm/s(20단계 ×1.25) · 석두 +5%. 예전 +3(×1.5)·+10% 는 같은 손으로 쳐도 단계에 따라
  /// 너무 달라 손맛(손가락 빠르기)보다 능력치가 앞섰다(2026-10-11 형 「단계별 차이가 너무 많이 나지 않게」).
  double get maxSpeed =>
      (120 + 1.5 * level(Stat.power)) * (hero == Fighter.seokdu ? 1.05 : 1);
  double get spinScale =>
      (1 + 0.015 * level(Stat.finesse)) +
      (hero == Fighter.yeonbi ? 0.1 : 0) +
      (hero == Fighter.gurumi ? 0.15 : 0) +
      // 목인항 끌어치기 수련(2026-10-14).
      (perks.contains('회전 숙련') ? 0.1 : 0);
  double get steerSeconds =>
      1.5 +
      0.075 * level(Stat.control) +
      (hero == Fighter.cheongmyeong ? 0.3 : 0);

  /// 판 시작 내공 칸: 화경(6단계)부터 1칸, 청명 +1.
  int get startQi =>
      (stage >= 6 ? 1 : 0) +
      (hero == Fighter.cheongmyeong ? 1 : 0) +
      // 목인항 내공 타격 수련(2026-10-14).
      (perks.contains('내공 숙련') ? 1 : 0);

  /// 목인항 단계별 수련(drills.dart · 2026-10-14): 깬 단계 수 · 지금 하는 단계 · 그 단계 진행.
  int drillCleared = 0;
  int drillIndex = 0;
  int drillProgress = 0;

  /// 어기어석 꺾기 횟수(설계서 §3.7·§16.2).
  int get steers => stage >= 7 ? 3 : (stage >= 5 ? 2 : 1);

  /// 도감 세트 보너스: 재질 7종(2026-10-14 셋 더함)을 모두 모으면 능력치 3종 +1, 모양 3종 모두 +1 (설계서 §8.7).
  int get codexBonus =>
      (materials.length == StoneMaterial.values.length ? 1 : 0) +
      (shapes.length == StoneShape.values.length ? 1 : 0);

  // --- 목인항 ---
  /// 오늘([day] = yyyymmdd) 한 타. 얻은 내공을 돌려준다. 날이 바뀌면 처음부터 센다.
  double trainHit(String day) {
    // 날짜는 앞으로만 넘어간다(기기 시계를 되돌려 깨달음 30타를 다시 받는 것 막기).
    if (day.compareTo(saneDay(trainingDay, day)) > 0) {
      trainingDay = day;
      trainingHits = 0;
    }
    final g = Training.gain(trainingHits, first: trainingFirst);
    trainingHits++;
    totalHits++;
    // 일일 임무「목인항 치기」(빠져 있어 그 임무를 끝낼 수 없었다 — 2026-10-11 고침).
    Missions.record(this, Deed.train, trainingDay);
    naegong += g;
    trainingPoints += g;
    return g;
  }

  // --- 능력치 올리기 ---
  bool canRaise(Stat s) =>
      stats[s]! < maxStatLevel &&
      level(s) < maxStatLevel &&
      trainingPoints >= statCost(stats[s]!);

  bool raise(Stat s) {
    if (!canRaise(s)) return false;
    trainingPoints -= statCost(stats[s]!);
    stats[s] = stats[s]! + 1;
    return true;
  }

  // --- 만물상 ---
  bool buyMaterial(StoneMaterial m) {
    final p = materialPrices[m];
    if (p == null || materials.contains(m) || coins < p) return false;
    coins -= p;
    materials.add(m);
    codex.add('재질:${m.name}');
    return true;
  }

  /// 조각 돌: 조각이 [shardNeeds] 만큼 모였나.
  bool canForge(StoneMaterial m) {
    final need = shardNeeds[m];
    return need != null &&
        !materials.contains(m) &&
        (bag[shardKey(m)] ?? 0) >= need;
  }

  /// 조각을 모두 써서 조각 돌을 완성한다.
  bool forgeShardStone(StoneMaterial m) {
    if (!canForge(m)) return false;
    final left = bag[shardKey(m)]! - shardNeeds[m]!;
    if (left > 0) {
      bag[shardKey(m)] = left;
    } else {
      bag.remove(shardKey(m));
    }
    materials.add(m);
    codex.add('재질:${m.name}');
    return true;
  }

  bool buyShape(StoneShape s) {
    final p = shapePrices[s]!;
    if (shapes.contains(s) || coins < p) return false;
    coins -= p;
    shapes.add(s);
    codex.add('모양:${s.name}');
    return true;
  }

  // --- 저장 ---
  Map<String, Object?> toJson() => {
    'v': 1,
    'hero': hero?.name,
    'school': school?.name,
    'done': done.toList(),
    'heroes': heroes.map((h) => h.name).toList(),
    'naegong': naegong,
    'tp': trainingPoints,
    'tday': trainingDay,
    'thits': trainingHits,
    'stats': {for (final e in stats.entries) e.key.name: e.value},
    'coins': coins,
    'silver': silver,
    'materials': materials.map((m) => m.name).toList(),
    'shapes': shapes.map((s) => s.name).toList(),
    'material': material.name,
    'shape': shape.name,
    'codex': codex.toList(),
    'tokens': tokens,
    'totalHits': totalHits,
    'stamina': stamina,
    'staminaAt': staminaAt,
    'perks': perks.toList(),
    'secretArts': secretArts,
    'trails': trails.toList(),
    'trail': trail,
    'legUntil': legendaryUntil,
    'legendary': legendary,
    'puzzles': puzzles.toList(),
    'puzzleStars': {for (final e in puzzleStars.entries) '${e.key}': e.value},
    'wanderWeek': wanderWeek,
    'wanderRow': wanderRow,
    'arenaBest': arenaBest,
    'rebirths': rebirths,
    'danCores': danCores,
    'tree': {for (final e in tree.entries) e.key.name: e.value},
    'face': face,
    'hair': hair,
    'robe': robe,
    'hairs': hairs.toList(),
    'robes': robes.toList(),
    'tutorial': tutorialDone,
    'easy': easyMode,
    'attendDay': attendDay,
    'attendCount': attendCount,
    'missionDay': missionDay,
    'missionCounts': {
      for (final e in missionCounts.entries) e.key.name: e.value,
    },
    'missionClaimed': missionClaimed.toList(),
    'lifetime': {for (final e in lifetime.entries) e.key.name: e.value},
    'achieved': achieved.toList(),
    'bag': bag,
    'drillCleared': drillCleared,
    'drillIndex': drillIndex,
    'drillProgress': drillProgress,
    'questKeys': questKeys,
    'questCounts': questCounts,
    'questClaimed': questClaimed.toList(),
    'stars': stars,
    'seenHints': seenHints.toList(),
    'seclusionDay': seclusionDay,
    'wanderWins': wanderWins,
    'encDay': encounterDay,
    'encToday': encountersToday,
    'celebrated': celebratedStage,
  };

  static T? _byName<T extends Enum>(List<T> values, Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  factory Profile.fromJson(Map<String, Object?> j) {
    final p = Profile();
    p.hero = _byName(Fighter.values, j['hero']);
    p.school = _byName(Technique.values, j['school']);
    p.done.addAll(_strs(j['done']));
    for (final h in _list(j['heroes'])) {
      final v = _byName(Fighter.values, h);
      if (v != null) p.heroes.add(v);
    }
    p.naegong = _num(j['naegong'], 0);
    p.trainingPoints = _num(j['tp'], 0);
    p.trainingDay = _str(j['tday'], '');
    p.trainingHits = _int(j['thits'], 0);
    final st = _map(j['stats']);
    for (final s in Stat.values) {
      p.stats[s] = _int(st[s.name], 0).clamp(0, maxStatLevel);
    }
    p.coins = _int(j['coins'], 0);
    p.silver = _int(j['silver'], 0);
    for (final m in _list(j['materials'])) {
      final v = _byName(StoneMaterial.values, m);
      if (v != null) p.materials.add(v);
    }
    for (final m in _list(j['shapes'])) {
      final v = _byName(StoneShape.values, m);
      if (v != null) p.shapes.add(v);
    }
    final mat = _byName(StoneMaterial.values, j['material']);
    if (mat != null && p.materials.contains(mat)) p.material = mat;
    final sh = _byName(StoneShape.values, j['shape']);
    if (sh != null && p.shapes.contains(sh)) p.shape = sh;
    p.codex.addAll(_strs(j['codex']));
    p.tokens = _int(j['tokens'], 0);
    p.totalHits = _int(j['totalHits'], 0);
    p.stamina = _num(j['stamina'], Stamina.max);
    p.staminaAt = _int(j['staminaAt'], 0);
    p.perks.addAll(_strs(j['perks']));
    p.secretArts = _int(j['secretArts'], 0).clamp(0, Profile.maxSecretArts);
    p.trails.addAll(_strs(j['trails']));
    p.trail = _str(j['trail'], '기본');
    p.legendaryUntil = _int(j['legUntil'], 0);
    p.legendary.addAll(_strs(j['legendary']));
    p.puzzles.addAll(_ints(j['puzzles']));
    final ps = _map(j['puzzleStars']);
    for (final e in ps.entries) {
      final id = int.tryParse('${e.key}');
      if (id != null && e.value is int) {
        p.puzzleStars[id] = (e.value as int).clamp(0, 3);
      }
    }
    p.wanderWeek = _str(j['wanderWeek'], '');
    p.wanderRow = _int(j['wanderRow'], 0);
    p.arenaBest = _int(j['arenaBest'], 0);
    p.rebirths = _int(j['rebirths'], 0);
    p.danCores = _int(j['danCores'], 0);
    final tr = _map(j['tree']);
    for (final n in TreeNode.values) {
      p.tree[n] = _int(tr[n.name], 0).clamp(0, TreeNode.maxLevel);
    }
    p.hairs.addAll(_ints(j['hairs']));
    p.robes.addAll(_ints(j['robes']));
    p.face = _int(j['face'], 0).clamp(0, faceShapes.length - 1);
    final h = _int(j['hair'], 0);
    p.hair = p.hairs.contains(h) ? h : 0;
    final r = _int(j['robe'], 0);
    p.robe = p.robes.contains(r) ? r : 0;
    // 입문 칸이 없는 옛 저장(입문이 생기기 전 판)도 새 입문을 한 번 거친다(형 지시 2026-10-11:
    // 처음 할 일을 강제로 익히게). 진행은 그대로 두고 입문만 한다.
    p.tutorialDone = _bool(j['tutorial'], false);
    p.easyMode = _bool(j['easy'], true);
    p.attendDay = _str(j['attendDay'], '');
    p.attendCount = _int(j['attendCount'], 0);
    p.missionDay = _str(j['missionDay'], '');
    final mc = _map(j['missionCounts']);
    final lt = _map(j['lifetime']);
    for (final d in Deed.values) {
      if (mc[d.name] is int) p.missionCounts[d] = mc[d.name] as int;
      if (lt[d.name] is int) p.lifetime[d] = lt[d.name] as int;
    }
    p.missionClaimed.addAll(_ints(j['missionClaimed']));
    p.achieved.addAll(_strs(j['achieved']));
    for (final e in _map(j['bag']).entries) {
      if (e.value is int && (e.value as int) > 0) {
        p.bag['${e.key}'] = e.value as int;
      }
    }
    p.drillCleared = _int(j['drillCleared'], 0).clamp(0, 99);
    p.drillIndex = _int(j['drillIndex'], 0).clamp(0, 99);
    p.drillProgress = _int(j['drillProgress'], 0).clamp(0, 999);
    for (final e in _map(j['questKeys']).entries) {
      if (e.value is String) p.questKeys['${e.key}'] = e.value as String;
    }
    for (final e in _map(j['questCounts']).entries) {
      if (e.value is int) p.questCounts['${e.key}'] = e.value as int;
    }
    p.questClaimed.addAll(_strs(j['questClaimed']));
    final st2 = _map(j['stars']);
    for (final e in st2.entries) {
      if (e.value is int) {
        p.stars['${e.key}'] = (e.value as int).clamp(0, 3);
      }
    }
    p.seenHints.addAll(_strs(j['seenHints']));
    p.seclusionDay = _str(j['seclusionDay'], '');
    p.wanderWins = _int(j['wanderWins'], 0);
    p.encounterDay = _str(j['encDay'], '');
    p.encountersToday = _int(j['encToday'], 0);
    // 칸이 없는 옛 저장은 지금 경지를 이미 축하한 것으로 본다(켜자마자 몰아서 축하하지 않게).
    p.celebratedStage = _int(j['celebrated'], p.stage);
    p._sanitize();
    return p;
  }

  /// 저장·백업 코드에서 들어온 숫자를 쓸 수 있는 범위로 묶는다
  /// (`1e999`→무한대, 최대 정수 +1→음수 같은 값에 화면이 터지지 않게 · 2026-10-11 점검).
  void _sanitize() {
    const cap = 1000000000;
    double f(double v, [double max = 1e9]) => v.isFinite ? v.clamp(0, max) : 0;
    int i(int v) => v.clamp(0, cap);
    naegong = f(naegong);
    trainingPoints = f(trainingPoints);
    stamina = f(stamina, staminaMax.toDouble());
    coins = i(coins);
    silver = i(silver);
    tokens = i(tokens);
    totalHits = i(totalHits);
    danCores = i(danCores);
    rebirths = i(rebirths);
    arenaBest = i(arenaBest);
    wanderRow = i(wanderRow);
    wanderWins = i(wanderWins);
    attendCount = i(attendCount);
    trainingHits = i(trainingHits);
    encountersToday = i(encountersToday);
    celebratedStage = i(celebratedStage);
    for (final d in Deed.values) {
      if (missionCounts[d] case final v?) missionCounts[d] = i(v);
      if (lifetime[d] case final v?) lifetime[d] = i(v);
    }
    bag.updateAll((_, v) => i(v));
    questCounts.updateAll((_, v) => i(v));
  }

  String encode() => jsonEncode(toJson());

  /// 모르는 판(v)은 거절한다 — 나중 판의 저장을 옛 앱이 읽고 덮어쓰지 않게.
  static Profile decode(String s) {
    final j = (jsonDecode(s) as Map).cast<String, Object?>();
    final v = j['v'] as int? ?? 1;
    if (v != 1) throw FormatException('모르는 저장 판: $v');
    return Profile.fromJson(j);
  }
}

/// 외형(설계서 §2.5) — 얼굴형 3 · 머리 6 · 도복 색 8. 앞 3개는 처음부터, 나머지는 만물상에서 은자로.
const faceShapes = ['둥근 얼굴', '갸름한 얼굴', '각진 얼굴'];
const hairStyles = ['상투', '총각머리', '풀어 내린 머리', '민머리', '쌍상투', '무사 묶음'];
const robeColors = [
  0xFF3A4A6B, // 쪽빛
  0xFF6B3A3A, // 팥빛
  0xFF3F5E3A, // 솔빛
  0xFFEDE6D6, // 흰 무명
  0xFF1E1E22, // 먹빛
  0xFFB8862B, // 황금빛
  0xFF7A4FA0, // 보랏빛(마교)
  0xFFC0392B, // 진홍
];
const robeNames = ['쪽빛', '팥빛', '솔빛', '흰 무명', '먹빛', '황금빛', '보랏빛', '진홍'];

/// 머리·도복 하나 값(은자).
/// 2026-10-11 경제 점검: 3(합계 24)이면 5일째 은자 쓸 곳이 사라졌다.
const int lookPrice = 5;

/// 오늘 날짜(기기 시간, yyyymmdd). 온라인판에서는 서버 시간을 쓴다(설계서 §11.4).
String today([DateTime? now]) {
  final d = now ?? DateTime.now();
  return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}

/// 날짜는 앞으로만 넘어간다(시계를 되돌려 같은 보상을 또 받는 것 막기). 그런데 시계가 한 번 잘못 앞서
/// 갔으면(2027년) 그날까지 출석·임무·목인항이 잠겼다 → 저장된 날이 [day]보다 [graceDays]일 넘게 앞서
/// 있으면 잘못된 날로 보고 잊는다(빈 문자열) · 2026-10-11 점검.
/// 2026-10-14 점검: 유예가 이틀이면 날짜를 사흘 앞뒤로 흔들어 출석·임무·깨달음을 계속 다시 받았다 → 30일.
String saneDay(String stored, String day, {int graceDays = 30}) {
  final a = _dayNumber(stored), b = _dayNumber(day);
  if (a == null || b == null) return stored;
  return a - b > graceDays ? '' : stored;
}

int? _dayNumber(String yyyymmdd) {
  if (yyyymmdd.length != 8) return null;
  final y = int.tryParse(yyyymmdd.substring(0, 4));
  final m = int.tryParse(yyyymmdd.substring(4, 6));
  final d = int.tryParse(yyyymmdd.substring(6, 8));
  if (y == null || m == null || d == null) return null;
  return DateTime.utc(y, m, d).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}

// 저장 읽기 — 칸 하나의 형식이 틀려도 그 칸만 기본값으로 읽는다(예전엔 하나만 틀려도 진행 전체를 버렸다 ·
// 2026-10-14 점검).
List<Object?> _list(Object? v) => v is List ? v : const [];
Map<Object?, Object?> _map(Object? v) => v is Map ? v : const {};
Iterable<String> _strs(Object? v) => _list(v).whereType<String>();
Iterable<int> _ints(Object? v) => _list(v).whereType<int>();
int _int(Object? v, int d) => v is int ? v : d;
double _num(Object? v, num d) => (v is num ? v : d).toDouble();
String _str(Object? v, String d) => v is String ? v : d;
bool _bool(Object? v, bool d) => v is bool ? v : d;
