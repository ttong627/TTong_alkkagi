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

/// 판 설정.
class MatchConfig {
  const MatchConfig({
    required this.mode,
    this.difficulty = Difficulty.normal,
    this.myMaterial = StoneMaterial.cheongok,
    this.myShape = StoneShape.round,
    this.arena = Arena.dustyYard,
    this.martial = Technique.swordQi,
  });

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
      table.addStone(x, -startRow, team: 1);
    }
  }

  final MatchConfig config;
  final Table table;

  int _turn = 0;
  final _qi = [0, 0];

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
    final team = s.team;
    final m = canUse(team, mode) ? mode : StrikeMode.plain;
    _qi[team] -= m.cost;
    if (m == StrikeMode.plain && critical) {
      _qi[team] = math.min(maxQi, _qi[team] + 1);
    }
    lastCritical = critical && m == StrikeMode.plain;
    lastMode = m;
    steersLeft = m == StrikeMode.ultimate ? 1 : 0;
    final technique = switch (m) {
      StrikeMode.plain => Technique.none,
      StrikeMode.absorb => Technique.absorb,
      StrikeMode.inner || StrikeMode.ultimate => config.martial,
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

  /// 화면 프레임마다 1/60초씩 진행한다. 한 수가 끝나면 true.
  bool step() {
    if (!isMoving) return false;
    final st = table.step();
    if (st == TurnStatus.moving) return false;
    table.endTurn();
    _finishTurn();
    notifyListeners();
    return true;
  }

  void _finishTurn() {
    if (config.mode == MatchMode.practice) {
      if (alive(1) == 0 || alive(0) == 0) _winner = alive(0) > 0 ? 0 : 1;
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
