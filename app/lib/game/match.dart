import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/foundation.dart';

import 'arena.dart';

/// 판 모드.
enum MatchMode {
  /// 나 혼자 AI 와 대전.
  vsAi('혼자 하기'),

  /// 한 기기로 둘이 번갈아.
  twoPlayer('둘이 하기'),

  /// 상대 없이 마음껏 쳐 보기.
  practice('연습');

  const MatchMode(this.label);
  final String label;
}

/// 판의 규칙(설계서 §16.15 · 2026-10-11 형 지시 「규칙 변형 모드」). 대전(혼자·둘이)에만 쓴다.
enum MatchRule {
  /// 기본: 상대 돌을 모두 떨어뜨리면 이긴다.
  annihilate('전멸전', '상대 돌을 모두 떨어뜨리면 승리'),

  /// 장수전: 편마다 장수 돌 하나(금테). 상대 장수를 떨어뜨리면 이기고, 내 장수가 떨어지면(내 수라도) 진다.
  general('장수전', '상대 장수(금테 돌)를 떨어뜨리면 승리 · 내 장수를 잃으면 패배'),

  /// 점수전: 상대 돌 10점 · 가운데 붉은 보주 30점 · 내 돌을 잃으면 상대가 10점. 먼저 [scoreTarget] 점.
  score('점수전', '먼저 60점 · 돌 10점 · 가운데 보주 30점 · 제 돌 잃으면 상대 +10'),

  /// 여섯 수 승부: 한 사람 [shotLimit] 수씩. 다 치면 남은 돌이 많은 쪽이 이긴다.
  shots('여섯 수 승부', '한 사람 여섯 수 · 끝나면 남은 돌이 많은 쪽 승리');

  const MatchRule(this.label, this.help);
  final String label;
  final String help;

  /// 점수전 목표.
  static const int scoreTarget = 60;

  /// 점수전: 돌 하나·보주 값.
  static const int stonePoints = 10;
  static const int jewelPoints = 30;

  /// 여섯 수 승부: 한 사람이 칠 수 있는 수.
  static const int shotLimit = 6;

  /// 장수 돌 자리: 줄 세운 8개 가운데 4번째(가운데 왼쪽).
  static const int generalIndex = 3;

  /// 점수전 보주의 편 번호(아무도 칠 수 없는 돌).
  static const int jewelTeam = 3;
}

/// AI 난이도 (체크리스트 2-04: 조준 오차 크기로 구분).
enum Difficulty {
  easy('쉬움', angleError: 0.12, speedError: 0.25),
  normal('보통', angleError: 0.05, speedError: 0.12),
  skilled('숙련', angleError: 0.03, speedError: 0.08),
  hard('어려움', angleError: 0.015, speedError: 0.05);

  const Difficulty(
    this.label, {
    required this.angleError,
    required this.speedError,
  });
  final String label;

  /// 조준 각도 오차 최대치(라디안).
  final double angleError;

  /// 세기 오차 최대치(비율).
  final double speedError;
}

/// 한 수를 어떻게 치나 (설계서 §3.9).
enum StrikeMode {
  /// 평타: 내공을 안 쓴다. 회심이 터지면 내공 1칸이 찬다.
  plain('평타', cost: 0),

  /// 내공 타격: 내공 1칸 — 처음 속도 ×1.3, 맞은 돌 ×1.25, 문파 무공 발동.
  inner('내공 타격', cost: 1),

  /// 스킬 흡성탄지: 내공 2칸 — 내공 타격 + 첫 충돌 둘레 돌을 끌어당김.
  absorb('흡성탄지', cost: 2),

  /// 궁극기 어기어석: 내공 3칸(가득) — 내공 타격 + 쏜 뒤 느린 화면에서 한 번 꺾기(§3.7).
  ultimate('어기어석', cost: 3);

  const StrikeMode(this.label, {required this.cost});
  final String label;
  final int cost;
}

/// 내공 겨루기 수치(설계서 §4). [가정] 실기기에서 맞춘다.
abstract final class QiClash {
  /// 연타 시간(초).
  static const double seconds = 3;

  /// 초당 이보다 많으면 무효(설계서 §4: 15회).
  static const int maxRate = 15;

  /// 반발 ±20%.
  static const double maxSwing = 0.2;

  /// 이 빠르기(cm/s) 넘게 부딪혀야 겨룬다(센 정면 충돌만 — 정한 값).
  static const double minSpeed = 40;

  /// 정면 판정: 20° 안.
  static const double headOnCos = 0.94;

  /// 연타 수 차이 → 반발 배수 차이. 초당 [maxRate] 를 넘긴 쪽은 0 회로 친다.
  static double swing(int mine, int theirs) {
    final cap = (maxRate * seconds).round();
    final m = mine > cap ? 0 : mine;
    final t = theirs > cap ? 0 : theirs;
    final top = m > t ? m : t;
    if (top == 0) return 0;
    return maxSwing * ((m - t) / top).clamp(-1.0, 1.0);
  }

  /// 고수의 연타 수(3초): 쉬움 18 · 보통 27 · 어려움 36, ±3.
  static int aiTaps(Difficulty d, math.Random r) =>
      switch (d) {
        Difficulty.easy => 18,
        Difficulty.normal => 27,
        Difficulty.skilled => 31,
        Difficulty.hard => 36,
      } +
      r.nextInt(7) -
      3;
}

/// 환생 전용 캐릭터의 비기(설계서 §10.1). 수치는 [가정].
enum RebirthArt {
  none,

  /// 마교 교주 · 흡성대법: 내 수에 맞은 상대 돌의 감속을 그 판 동안 30% 빼앗는다.
  steal,

  /// 검황 · 이기어검: 평타도 앞쪽 30° 안의 가장 가까운 상대 돌로 한 걸음에 0.6° 씩 따라가고(첫 충돌 전까지),
  /// 어기어석 때는 첫 충돌에서 분신 둘이 다른 상대 돌 둘을 60% 빠르기로 쫓는다.
  homing,

  /// 신승 · 반탄공: 상대 차례에 내 돌이 맞을 때 30% 로 반발 2배(친 돌을 되튕기고 내 돌은 덜 밀린다).
  reflect;

  static const double stealScale = 0.7;
  static const double homingCone = 30 * math.pi / 180;
  static const double homingTurn = 0.6 * math.pi / 180;
  static const double seekerSpeed = 0.6;
  static const double reflectChance = 0.3;
}

/// 내공 칸 수(가득).
const int maxQi = 3;

/// 고수(보스)의 버릇 — AI 가 치는 방식 (설계서 §16.1).
enum AiStyle {
  /// 보통 AI.
  plain,

  /// 촌장: 가르치는 사람. 가장 좋은 수를 일부러 자주 피한다.
  teacher,

  /// 통통: 늘 가장 센 힘으로 정면 강타.
  ram,

  /// 숨은 자객: 판 가장자리에 가까운 내 돌만 노린다.
  assassin,

  /// 쿠비: 끌어치기와 여러 돌을 한 번에 노리는 수를 즐긴다.
  spinner,

  /// 로직: 후보를 두 배로 읽고 계산한다.
  calculator,

  /// 무림맹주·숙적: 내공 타격과 무공을 쓴다.
  master,
}

/// 묘수풀이·특수 판의 돌 놓기.
class Placement {
  const Placement(
    this.x,
    this.y, {
    this.team = 1,
    this.material = StoneMaterial.cheongok,
    this.shape = StoneShape.round,
  });
  final double x;
  final double y;
  final int team;
  final StoneMaterial material;
  final StoneShape shape;
}

/// 판 설정.
class MatchConfig {
  const MatchConfig({
    required this.mode,
    this.difficulty = Difficulty.normal,
    this.myMaterial = StoneMaterial.cheongok,
    this.myShape = StoneShape.round,
    this.arena = Arena.dustyYard,
    this.martial = Technique.swordQi,
    this.opponentMaterial = StoneMaterial.cheongok,
    this.opponentShape = StoneShape.round,
    this.opponentMartial = Technique.none,
    this.aiStyle = AiStyle.plain,
    this.myStartQi = 0,
    this.opponentStartQi = 0,
    this.powerScale = 1,
    this.spinScale = 1,
    this.steers = 1,
    this.steerSeconds = 2.5,
    this.opponentName,
    this.training = false,
    this.myTrail,
    this.qiSaver = false,
    this.impactScale = 1,
    this.innerSpeed = TechniqueConstants.innerSpeed,
    this.critDoubleChance = 0,
    this.knockoutQiChance = 0,
    this.knockoutQiMax = 0,
    this.aimAssist = 2,
    this.critWidth = 0.15,
    this.layout,
    this.shotLimit,
    this.weather = Weather.clear,
    this.features = const [],
    this.civilians = const [],
    this.shiftingFloor = false,
    this.qiClash = false,
    this.demonWorld = false,
    this.art = RebirthArt.none,
    this.rule = MatchRule.annihilate,
    this.aiErrorScale = 1,
    this.aiPowerScale = 1,
    this.aiBlunder = 0,
  });

  /// AI 가 가장 좋은 수 대신 그 아래 후보에서 고를 확률(0~1). 「쉬움」의 실수.
  final double aiBlunder;

  /// AI 세기 배수(1 = 그대로). 늘 세게 치는 고수(통통)를 「쉬움」에서 누그러뜨린다.
  final double aiPowerScale;

  /// AI 손 오차 배수(1 = [difficulty] 그대로, 클수록 서툴다). 강호행 「쉬움」이 판마다 정한다.
  final double aiErrorScale;

  /// 판의 규칙(대전에서만 — 연습·묘수·목인항은 늘 기본).
  final MatchRule rule;

  /// 내 환생 캐릭터의 비기(설계서 §10.1).
  final RebirthArt art;

  /// 환생 세계(어두운 마교 세계) 판인가.
  final bool demonWorld;

  /// 내공 겨루기(설계서 §4): 고수전에서 양편 가장 무거운 돌이 정면으로 부딪히면 연타로 겨룬다.
  final bool qiClash;

  /// 천기(날씨, 설계서 §9.3).
  final Weather weather;

  /// 판 위 지물·장애물(설계서 §9.4·§10.2).
  final List<Feature> features;

  /// 백성 돌(편 2, 3장): 떨어뜨리면 감점.
  final List<Placement> civilians;

  /// 6장: 수마다 얼음(×0.6)과 불꽃(×1.3) 바닥이 바뀐다.
  final bool shiftingFloor;

  /// 묘수풀이: 정해진 돌 놓기(내 돌 = 편 0). null 이면 보통 줄.
  final List<Placement>? layout;

  /// 묘수풀이: 칠 수 있는 수. 그 안에 상대 돌을 다 못 떨어뜨리면 실패.
  final int? shotLimit;

  /// 회심 판정 가운데 폭(정각 0.2).
  final double critWidth;

  /// 내 돌 잔상 빛깔 이름(꾸미기). null 이면 기본.
  final String? myTrail;

  /// 기인방 「내공 아낌」: 내공을 쓸 때 10% 로 1칸 돌려받음.
  final bool qiSaver;

  /// 내 수의 첫 충돌로 맞은 돌 빠르기 배수(기인방 +5%·반달 +10%).
  final double impactScale;

  /// 내공 타격 처음 속도 배수(용아 1.35).
  final double innerSpeed;

  /// 회심 때 내공 +1칸 더 받을 확률(취선 20%).
  final double critDoubleChance;

  /// 내가 상대 돌을 떨어뜨릴 때마다 내공 +1칸 받을 확률과 판당 최대(묵객 100%·2번, 기인방 10%).
  final double knockoutQiChance;
  final int knockoutQiMax;

  /// 예상 궤적(설계서 §7.1): 2 = 두 번째 충돌까지, 1 = 첫 충돌까지, 0.5 = 첫 충돌까지의 절반, 0 = 없음.
  final double aimAssist;

  /// 목인항: 내 돌 하나와 목각 더미 하나만 놓는다(설계서 §5.2·§8.1).
  final bool training;

  /// 상대 돌 재질·모양(보스마다 다름).
  final StoneMaterial opponentMaterial;
  final StoneShape opponentShape;

  /// 상대 무공(내공 타격 때). 둘이 하기에서는 위 편 사람의 무공.
  final Technique opponentMartial;

  /// AI 버릇(설계서 §16.1).
  final AiStyle aiStyle;

  /// 판 시작 내공 칸.
  final int myStartQi;
  final int opponentStartQi;

  /// 내 능력치(설계서 §2.3): 처음 속도 배수(탄지 파워 ÷ 120), 회전 배수(탄지 묘수).
  final double powerScale;
  final double spinScale;

  /// 어기어석 꺾기 횟수와 느린 화면 시간(초).
  final int steers;
  final double steerSeconds;

  /// 상대 이름(강호행 고수). 없으면 「상대」.
  final String? opponentName;

  final MatchMode mode;

  /// 내 문파 무공(검기·진각·태극·분신). 내공 타격 때 발동한다(설계서 §2.4·§3.9).
  final Technique martial;
  final Difficulty difficulty;
  final StoneMaterial myMaterial;
  final StoneShape myShape;

  /// 대전장(바닥 그림·미끄러움·판 모양).
  final Arena arena;
}

/// 처음 줄 세울 때 돌 사이 간격(cm) — 판이 허락하는 만큼([lineUp]).
///
/// 2026-10-14 형 「돌의 간격도 조금 많이 떨어뜨려줘」: 예전 3.4 → 4.4(약 30% 넓게).
const double startGap = 4.4;

/// 처음 줄의 판 중심에서 떨어진 거리(cm) — 보통 판(21) 기준. 판 크기에 비례한다([lineUp]).
const double startRow = 12;

/// 판 크기에 맞춘 처음 줄: (줄 거리, 돌 간격). 네모 판은 끝 돌이 가장자리에서 2.6 안쪽,
/// 둥근 판은 모서리 돌이 가장자리에서 3 안쪽에 오도록 간격을 줄인다.
(double row, double gap) lineUp(Boundary boundary, double half) {
  final row = startRow * half / PhysicsConstants.halfBoard;
  final reach = (stonesPerTeam - 1) / 2;
  final maxX = boundary == Boundary.square
      ? half - 2.6
      : math.sqrt(math.max(0, (half - 3) * (half - 3) - row * row));
  return (row, math.min(startGap, maxX / reach));
}

/// 한 편 돌 수.
const int stonesPerTeam = 8;

/// 손으로 쏠 때 최대 세기(cm/s). 탄지 파워 기본값(설계서 §2.3).
const double baseMaxSpeed = 120;

/// 알까기 한 판. 차례·승패를 관리하고, 물리는 [Table] 이 맡는다.
class Match extends ChangeNotifier {
  Match(this.config)
    : table = Table(
        floorFactor: config.arena.floorFactor,
        boundary: config.arena.boundary,
        weather: config.weather,
        windSeed: DateTime.now().millisecondsSinceEpoch & 0xffff,
        // 무게중심(둥근 돌이 맞으면 덜 구름 · 2026-10-14)은 대전에만. 묘수풀이·트릭샷은 정해 둔 풀이가
        // 예전 물리로 찾은 것이라 그대로 둔다.
        settle: config.layout == null,
        // 판 크기도 대전에만(묘수풀이·트릭샷 배치는 보통 판 21 로 짰다).
        half: config.layout == null
            ? config.arena.half
            : PhysicsConstants.halfBoard,
      ) {
    for (final f in config.features) {
      table.addFeature(f);
    }
    for (final c in config.civilians) {
      table.addStone(c.x, c.y, team: 2, material: c.material, shape: c.shape);
    }
    final layout = config.layout;
    if (layout != null) {
      for (final pl in layout) {
        table.addStone(
          pl.x,
          pl.y,
          material: pl.team == 0 ? config.myMaterial : pl.material,
          shape: pl.team == 0 ? config.myShape : pl.shape,
          team: pl.team,
        );
      }
      return;
    }
    if (config.training) {
      table.addStone(
        0,
        startRow,
        material: config.myMaterial,
        shape: config.myShape,
      );
      table.addStone(0, 0, team: 1, shape: StoneShape.sphere);
      return;
    }
    final (row, gap) = lineUp(config.arena.boundary, table.half);
    for (var i = 0; i < stonesPerTeam; i++) {
      final x = (i - (stonesPerTeam - 1) / 2) * gap;
      table.addStone(
        x,
        row,
        material: config.myMaterial,
        shape: config.myShape,
        team: 0,
      );
    }
    for (var i = 0; i < stonesPerTeam; i++) {
      final x = (i - (stonesPerTeam - 1) / 2) * gap;
      table.addStone(
        x,
        -row,
        material: config.opponentMaterial,
        shape: config.opponentShape,
        team: 1,
      );
    }
    if (rule == MatchRule.general) {
      final mine = table.stones.where((s) => s.team == 0).toList();
      final theirs = table.stones.where((s) => s.team == 1).toList();
      generals[0] = mine[MatchRule.generalIndex].id;
      generals[1] = theirs[MatchRule.generalIndex].id;
    }
    if (rule == MatchRule.score) {
      // 가운데 붉은 보주: 무겁고 둥근 돌(쉽게 안 밀린다).
      jewelId = table
          .addStone(
            0,
            0,
            material: StoneMaterial.hyeoncheol,
            shape: StoneShape.sphere,
            team: MatchRule.jewelTeam,
          )
          .id;
    }
  }

  /// 이 판에 실제로 쓰는 규칙. 대전(혼자·둘이)에서만 바꿀 수 있고, 묘수·목인항·연습은 늘 기본.
  MatchRule get rule =>
      config.mode == MatchMode.practice ||
          config.layout != null ||
          config.training
      ? MatchRule.annihilate
      : config.rule;

  /// 장수전: 편마다 장수 돌 id.
  final generals = <int, int>{};

  /// 점수전: 가운데 보주 id(없으면 null).
  int? jewelId;

  /// 점수전 점수(편 0, 편 1).
  final scores = [0, 0];

  /// 여섯 수 승부: 편마다 친 수.
  final shotsTaken = [0, 0];

  /// 이 돌이 장수인가.
  bool isGeneral(Stone s) => generals[s.team] == s.id;

  bool _isOut(int? id) {
    if (id == null) return false;
    for (final s in table.stones) {
      if (s.id == id) return s.out;
    }
    return false;
  }

  bool _jewelBefore = false;

  final MatchConfig config;
  final Table table;

  int _turn = 0;
  final _rand = math.Random();
  int _knockoutQiGiven = 0;
  late final _qi = [
    math.min(maxQi, config.myStartQi),
    math.min(maxQi, config.opponentStartQi),
  ];

  /// 마지막 수가 회심 일격이었나(연출용).
  bool lastCritical = false;

  /// 마지막 수의 방식(연출용).
  StrikeMode lastMode = StrikeMode.plain;

  /// 어기어석으로 꺾을 수 있는 남은 횟수(쏜 뒤 느린 화면 동안).
  int steersLeft = 0;
  int? _winner;
  bool _draw = false;
  int _turnCount = 0;

  /// 지금 차례인 편(0 = 아래, 1 = 위).
  int get turn => _turn;

  /// 이긴 편. 아직 안 끝났으면 null.
  int? get winner => _winner;

  /// 둘 다 돌이 없어 비김.
  bool get isDraw => _draw;

  bool get isOver => _winner != null || _draw;

  /// 돌이 움직이는 중인가.
  bool get isMoving => table.status == TurnStatus.moving;

  /// 지금까지 둔 수.
  int get turnCount => _turnCount;

  /// [team] 의 남은 돌 수.
  int alive(int team) =>
      table.stones.where((s) => s.team == team && !s.out).length;

  /// 지금 차례에 쏠 수 있는 돌인가.
  bool canShoot(Stone s) => !isOver && !isMoving && !s.out && s.team == _turn;

  /// 시험·연출 확인용: 내공을 채운다.
  @visibleForTesting
  void grantQi(int team, int n) => _qi[team] = math.min(maxQi, n);

  /// [team] 의 내공 칸 수(0~[maxQi]).
  int qi(int team) => _qi[team];

  /// [team] 이 이 방식으로 칠 수 있나(내공이 모자라면 못 친다).
  bool canUse(int team, StrikeMode mode) => _qi[team] >= mode.cost;

  /// 한 수를 쏜다. [lift] 면 타격점이 위·아래 끝에 가까울 때 돌이 뜬다(손으로 친 수).
  ///
  /// [mode] 의 내공을 쓴다(모자라면 평타로 친다). 평타가 [critical] 이면 내공 1칸이 찬다.
  void shoot(
    Stone s,
    double angle,
    double speed,
    double hit, {
    bool lift = false,
    StrikeMode mode = StrikeMode.plain,
    bool critical = false,
    double curl = 0,
  }) {
    if (!canShoot(s)) return;
    touchedThisTurn.clear();
    final team = s.team;
    final m = canUse(team, mode) ? mode : StrikeMode.plain;
    _qi[team] -= m.cost;
    final mine = team == 0;
    if (mine && m.cost > 0 && config.qiSaver && _rand.nextDouble() < 0.1) {
      _qi[team] += 1;
    }
    if (m == StrikeMode.plain && critical) {
      final extra = mine && _rand.nextDouble() < config.critDoubleChance
          ? 1
          : 0;
      _qi[team] = math.min(maxQi, _qi[team] + 1 + extra);
    }
    _aliveBefore = alive(1 - team);
    _jewelBefore = jewelId != null && !_isOut(jewelId);
    shotsTaken[team]++;
    _ownBefore = alive(team);
    lastCritical = critical && m == StrikeMode.plain;
    lastMode = m;
    steersLeft = m == StrikeMode.ultimate ? config.steers : 0;
    final technique = switch (m) {
      StrikeMode.plain => Technique.none,
      StrikeMode.absorb => Technique.absorb,
      StrikeMode.inner || StrikeMode.ultimate =>
        team == 0 ? config.martial : config.opponentMartial,
    };
    table.shoot(
      s,
      angle,
      speed,
      hit,
      lift: lift,
      inner: m != StrikeMode.plain,
      technique: technique,
      curl: curl,
      spinScale: mine ? config.spinScale : 1,
      impactScale: mine ? config.impactScale : 1,
      innerSpeed: mine ? config.innerSpeed : TechniqueConstants.innerSpeed,
    );
    _turnCount++;
    notifyListeners();
  }

  /// 어기어석: 쏜 돌을 [angle] 쪽으로 꺾는다(빠르기는 그대로). 남은 횟수가 없으면 무시.
  void steer(double angle) {
    if (steersLeft <= 0 || !isMoving) return;
    steersLeft--;
    table.redirect(angle);
    notifyListeners();
  }

  /// 이번 수에 쏜 돌과 부딪힌 돌(목인항·연출용).
  final touchedThisTurn = <int>{};

  /// 목인항: 내 돌을 제자리로, 더미를 [x],[y] 로 옮긴다.
  void resetTraining(double x, double y) {
    void place(Stone s, double px, double py) {
      s.out = false;
      s.body.isEnabled = true;
      s.body.setTransform(Vector2(px, py), s.body.rotation);
      s.body.linearVelocity = Vector2.zero();
      s.body.angularVelocity = 0;
    }

    place(table.stones[0], 0, startRow);
    place(table.stones[1], x, y);
    _winner = null;
    _turn = 0;
    notifyListeners();
  }

  /// 내공 겨루기를 기다리는 중이면 (내 돌 id, 상대 돌 id). 이 동안 물리를 멈춘다.
  (int, int)? clash;
  bool _clashThisTurn = false;

  /// [team] 의 살아 있는 돌 가운데 가장 무거운 무게. 한 편 돌은 보통 모두 같은 무게라
  /// 「가장 무거운 두 돌」은 이 무게를 가진 양편 돌 한 쌍이다.
  double heaviestMass(int team) {
    var m = 0.0;
    for (final s in table.stones) {
      if (s.team == team && !s.out && s.mass > m) m = s.mass;
    }
    return m;
  }

  /// 화면 프레임마다 1/60초씩 진행한다. 한 수가 끝나면 true.
  /// 환생 비기가 터진 자리(연출용, 한 걸음마다 새로).
  final artEvents = <(String, double, double)>[];
  final _stolen = <int>{};
  bool _artThisTurn = false;

  bool step() {
    if (!isMoving) return false;
    if (clash != null) return false;
    artEvents.clear();
    _homingBefore();
    final watch = config.qiClash && !_clashThisTurn && !config.training;
    final before = watch
        ? {for (final s in table.stones) s.id: s.velocity.clone()}
        : const <int, Vector2>{};
    final st = table.step();
    if (watch && st == TurnStatus.moving) _checkClash(before);
    if (st == TurnStatus.moving) _artAfter();
    final shooterId = table.shooter?.id;
    for (final i in table.impacts) {
      if (i.a == shooterId) touchedThisTurn.add(i.b);
      if (i.b == shooterId) touchedThisTurn.add(i.a);
    }
    if (st == TurnStatus.moving) return false;
    table.endTurn();
    _clashThisTurn = false;
    _artThisTurn = false;
    _finishTurn();
    notifyListeners();
    return true;
  }

  int _aliveBefore = 0;
  int _ownBefore = 0;

  /// 지난 수에 쏜 편이 떨어뜨린 상대 돌 수.
  int lastKnocked = 0;

  /// 지난 수에 쏜 편이 잃은 제 돌 수(자살수).
  int lastSelfLost = 0;

  /// 지난 수를 쏜 편.
  int lastShooter = 0;

  /// 일타쌍피(설계서 §16.7): 내가 한 수에 2개 이상 떨어뜨리면 1개에 엽전 [multiKnockCoin].
  int bonusCoins = 0;
  static const int multiKnockCoin = 10;

  /// 오늘의 한 수: 내가 한 수에 가장 많이 떨어뜨린 상대 돌 수(결과 화면 · 2026-10-13 재미 점검).
  int bestKnock = 0;

  /// 떨어진 백성 돌 수(3장 감점).
  int get civiliansLost =>
      table.stones.where((s) => s.team == 2 && s.out).length;

  /// 6장 바닥이 지금 불꽃인가.
  bool fireFloor = false;

  void _finishTurn() {
    if (config.shiftingFloor) {
      fireFloor = !fireFloor;
      table.floorFactor = fireFloor ? 1.3 : config.arena.floorFactor;
    }
    if (config.training) return;
    lastShooter = _turn;
    lastKnocked = _aliveBefore - alive(1 - _turn);
    lastSelfLost = _ownBefore - alive(_turn);
    if (_turn == 0) bestKnock = math.max(bestKnock, lastKnocked);
    if (_turn == 0 && lastKnocked >= 2 && config.mode == MatchMode.vsAi) {
      bonusCoins += multiKnockCoin * lastKnocked;
    }
    // 내가 상대 돌을 떨어뜨리면 내공(묵객·기인방 「장외 시 기」).
    if (_turn == 0 && config.knockoutQiChance > 0) {
      final knocked = _aliveBefore - alive(1);
      for (var i = 0; i < knocked; i++) {
        if (_knockoutQiGiven >= config.knockoutQiMax) break;
        if (_rand.nextDouble() < config.knockoutQiChance) {
          _qi[0] = math.min(maxQi, _qi[0] + 1);
          _knockoutQiGiven++;
        }
      }
    }
    if (config.mode == MatchMode.practice) {
      // 묘수풀이: 백성 돌을 하나라도 떨어뜨리면 실패.
      if (config.layout != null && civiliansLost > 0) {
        _winner = 1;
        return;
      }
      // 상대 돌을 다 떨어뜨렸으면 내 돌이 같이 나가도 성공.
      if (alive(1) == 0) {
        _winner = 0;
      } else if (alive(0) == 0) {
        _winner = 1;
      }
      final limit = config.shotLimit;
      if (_winner == null && limit != null && _turnCount >= limit) _winner = 1;
      return;
    }
    switch (rule) {
      case MatchRule.annihilate:
        break;
      case MatchRule.general:
        // 내 장수가 떨어지면(상대 장수를 함께 떨어뜨려도) 반칙패.
        if (_isOut(generals[_turn])) {
          _winner = 1 - _turn;
          return;
        }
        if (_isOut(generals[1 - _turn])) {
          _winner = _turn;
          return;
        }
      case MatchRule.score:
        final jewel = _jewelBefore && _isOut(jewelId);
        scores[_turn] +=
            lastKnocked * MatchRule.stonePoints +
            (jewel ? MatchRule.jewelPoints : 0);
        scores[1 - _turn] += lastSelfLost * MatchRule.stonePoints;
        final done =
            scores[0] >= MatchRule.scoreTarget ||
            scores[1] >= MatchRule.scoreTarget ||
            alive(0) == 0 ||
            alive(1) == 0;
        if (done) {
          _endByCount(scores[0], scores[1]);
          return;
        }
      case MatchRule.shots:
        final a0 = alive(0), a1 = alive(1);
        if (a0 > 0 &&
            a1 > 0 &&
            shotsTaken[0] >= MatchRule.shotLimit &&
            shotsTaken[1] >= MatchRule.shotLimit) {
          _endByCount(a0, a1);
          return;
        }
    }
    final a0 = alive(0), a1 = alive(1);
    if (a0 == 0 && a1 == 0) {
      _draw = true;
    } else if (a1 == 0) {
      _winner = 0;
    } else if (a0 == 0) {
      _winner = 1;
    } else {
      _turn = 1 - _turn;
    }
  }

  /// 많은 쪽이 이긴다(같으면 비김).
  void _endByCount(int mine, int theirs) {
    if (mine == theirs) {
      _draw = true;
    } else {
      _winner = mine > theirs ? 0 : 1;
    }
  }

  /// 시간이 다 됐다(묘수풀이 시간 제한): 실패로 끝낸다.
  void timeUp() {
    if (isOver) return;
    _winner = 1;
    notifyListeners();
  }

  /// 판 아래에 보일 규칙 상황 한 줄(기본 규칙이면 null).
  String? get ruleStatus => switch (rule) {
    MatchRule.annihilate => null,
    MatchRule.general => '장수전 · 금테 돌을 지켜라',
    MatchRule.score =>
      '점수 ${scores[0]} : ${scores[1]} · 먼저 ${MatchRule.scoreTarget}점',
    MatchRule.shots =>
      '남은 수 ${MatchRule.shotLimit - shotsTaken[0]} : '
          '${MatchRule.shotLimit - shotsTaken[1]}',
  };

  /// 검황: 첫 충돌 전 평타가 앞쪽 상대 돌로 살짝 따라간다.
  void _homingBefore() {
    if (config.art != RebirthArt.homing || lastMode != StrikeMode.plain) return;
    final sh = table.shooter;
    if (sh == null || sh.team != 0 || sh.out || sh.airborne) return;
    if (touchedThisTurn.isNotEmpty) return;
    final v = sh.velocity;
    if (v.length < 5) return;
    final heading = math.atan2(v.y, v.x);
    Stone? best;
    var bestD = double.infinity;
    var bestA = 0.0;
    for (final s in table.stones) {
      if (s.team != 1 || s.out || s.phantom) continue;
      final d = s.position - sh.position;
      final a = math.atan2(d.y, d.x);
      final diff = _wrap(a - heading);
      if (diff.abs() > RebirthArt.homingCone) continue;
      if (d.length < bestD) {
        bestD = d.length;
        best = s;
        bestA = diff;
      }
    }
    if (best == null) return;
    final turn = bestA.clamp(-RebirthArt.homingTurn, RebirthArt.homingTurn);
    table.redirect(heading + turn);
  }

  static double _wrap(double a) {
    while (a > math.pi) {
      a -= 2 * math.pi;
    }
    while (a < -math.pi) {
      a += 2 * math.pi;
    }
    return a;
  }

  /// 한 걸음 뒤: 흡성대법·이기어검 분신·반탄공.
  void _artAfter() {
    final art = config.art;
    if (art == RebirthArt.none) return;
    final sh = table.shooter;
    if (sh == null) return;
    for (final i in table.impacts) {
      if (i.a != sh.id && i.b != sh.id) continue;
      final other = _byId(i.a == sh.id ? i.b : i.a);
      if (other == null || other.phantom) continue;
      switch (art) {
        case RebirthArt.steal:
          if (sh.team == 0 && other.team == 1 && _stolen.add(other.id)) {
            table.setDampingScale(other, RebirthArt.stealScale);
            artEvents.add(('흡성대법', i.x, i.y));
          }
        case RebirthArt.homing:
          if (sh.team == 0 &&
              other.team == 1 &&
              lastMode == StrikeMode.ultimate &&
              !_artThisTurn) {
            _artThisTurn = true;
            final targets =
                table.stones
                    .where(
                      (s) =>
                          s.team == 1 &&
                          !s.out &&
                          !s.phantom &&
                          s.id != other.id,
                    )
                    .toList()
                  ..sort(
                    (a, b) => a.position
                        .distanceTo(sh.position)
                        .compareTo(b.position.distanceTo(sh.position)),
                  );
            final speed =
                math.max(sh.velocity.length, i.speed) * RebirthArt.seekerSpeed;
            table.spawnSeekers(sh, targets.take(2).toList(), speed);
            artEvents.add(('이기어검', i.x, i.y));
          }
        case RebirthArt.reflect:
          if (sh.team == 1 &&
              other.team == 0 &&
              !_artThisTurn &&
              _rand.nextDouble() < RebirthArt.reflectChance) {
            _artThisTurn = true;
            final n = sh.position - other.position;
            if (n.length > 1e-6) {
              n.normalize();
              sh.body.linearVelocity = sh.velocity + n * i.speed;
              other.body.linearVelocity = other.velocity * 0.5;
              artEvents.add(('반탄공', i.x, i.y));
            }
          }
        case RebirthArt.none:
          break;
      }
    }
  }

  Stone? _byId(int id) {
    for (final s in table.stones) {
      if (s.id == id) return s;
    }
    return null;
  }

  void _checkClash(Map<int, Vector2> before) {
    final m0 = heaviestMass(0), m1 = heaviestMass(1);
    for (final i in table.impacts) {
      if (i.speed < QiClash.minSpeed) continue;
      final a = _byId(i.a), b = _byId(i.b);
      if (a == null || b == null || a.phantom || b.phantom) continue;
      if (a.team + b.team != 1) continue;
      final mine = a.team == 0 ? a : b, theirs = a.team == 0 ? b : a;
      if (mine.mass < m0 - 1e-9 || theirs.mass < m1 - 1e-9) continue;
      // 정면: 더 빨리 오던 돌의 방향이 두 돌 중심을 잇는 선과 20° 안.
      final va = before[mine.id], vb = before[theirs.id];
      if (va == null || vb == null) continue;
      final mover = va.length >= vb.length ? va : vb;
      final line = theirs.position - mine.position;
      if (mover.length < 1e-6 || line.length < 1e-6) continue;
      final cos = mover.dot(line).abs() / (mover.length * line.length);
      if (cos < QiClash.headOnCos) continue;
      _clashThisTurn = true;
      clash = (mine.id, theirs.id);
      notifyListeners();
      return;
    }
  }

  /// 내공 겨루기 결과를 넣고 물리를 다시 돌린다. [myTaps]·[aiTaps] 는 [QiClash.seconds] 동안 연타 수.
  /// 돌려주는 값은 반발 배수 차이(−0.2~+0.2, 내 쪽이 이기면 +). 초당 15회를 넘긴 연타는 무효(0).
  double resolveClash(int myTaps, int aiTaps) {
    final c = clash;
    if (c == null) return 0;
    clash = null;
    final d = QiClash.swing(myTaps, aiTaps);
    final mine = _byId(c.$1), theirs = _byId(c.$2);
    if (mine == null || theirs == null) return 0;
    mine.body.linearVelocity = mine.velocity * (1 - d);
    theirs.body.linearVelocity = theirs.velocity * (1 + d);
    notifyListeners();
    return d;
  }

  /// 돌 중심과 손가락 사이 거리(cm).
  static double distance(Vector2 a, double x, double y) =>
      math.sqrt((a.x - x) * (a.x - x) + (a.y - y) * (a.y - y));

  @override
  void dispose() {
    table.dispose();
    super.dispose();
  }
}
