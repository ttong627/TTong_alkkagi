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

/// AI 난이도 (체크리스트 2-04: 조준 오차 크기로 구분).
enum Difficulty {
  easy('쉬움', angleError: 0.12, speedError: 0.25),
  normal('보통', angleError: 0.05, speedError: 0.12),
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
  });

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

/// 처음 줄 세울 때 돌 사이 간격(cm). 둥근 판에서도 모서리 돌이 안쪽에 오게 잡았다.
const double startGap = 3.4;

/// 처음 줄의 판 중심에서 떨어진 거리(cm).
const double startRow = 12;

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
      ) {
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
    for (var i = 0; i < stonesPerTeam; i++) {
      final x = (i - (stonesPerTeam - 1) / 2) * startGap;
      table.addStone(
        x,
        startRow,
        material: config.myMaterial,
        shape: config.myShape,
        team: 0,
      );
    }
    for (var i = 0; i < stonesPerTeam; i++) {
      final x = (i - (stonesPerTeam - 1) / 2) * startGap;
      table.addStone(
        x,
        -startRow,
        material: config.opponentMaterial,
        shape: config.opponentShape,
        team: 1,
      );
    }
  }

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

  /// 화면 프레임마다 1/60초씩 진행한다. 한 수가 끝나면 true.
  bool step() {
    if (!isMoving) return false;
    final st = table.step();
    final shooterId = table.shooter?.id;
    for (final i in table.impacts) {
      if (i.a == shooterId) touchedThisTurn.add(i.b);
      if (i.b == shooterId) touchedThisTurn.add(i.a);
    }
    if (st == TurnStatus.moving) return false;
    table.endTurn();
    _finishTurn();
    notifyListeners();
    return true;
  }

  int _aliveBefore = 0;

  void _finishTurn() {
    if (config.training) return;
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

  /// 돌 중심과 손가락 사이 거리(cm).
  static double distance(Vector2 a, double x, double y) =>
      math.sqrt((a.x - x) * (a.x - x) + (a.y - y) * (a.y - y));

  @override
  void dispose() {
    table.dispose();
    super.dispose();
  }
}
