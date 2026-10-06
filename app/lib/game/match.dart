import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/foundation.dart';

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

/// 판 설정.
class MatchConfig {
  const MatchConfig({
    required this.mode,
    this.difficulty = Difficulty.normal,
    this.myMaterial = StoneMaterial.cheongok,
    this.myShape = StoneShape.round,
  });

  final MatchMode mode;
  final Difficulty difficulty;
  final StoneMaterial myMaterial;
  final StoneShape myShape;
}

/// 판 한 칸 간격(cm). 19줄.
const double gridGap = PhysicsConstants.board / 19;

/// 한 편 돌 수.
const int stonesPerTeam = 8;

/// 손으로 쏠 때 최대 세기(cm/s). 탄지 파워 기본값(설계서 §2.3).
const double baseMaxSpeed = 120;

/// 알까기 한 판. 차례·승패를 관리하고, 물리는 [Table] 이 맡는다.
class Match extends ChangeNotifier {
  Match(this.config) : table = Table() {
    for (var i = 0; i < stonesPerTeam; i++) {
      final x = (i * 2 - 7) * gridGap;
      table.addStone(
        x,
        6 * gridGap,
        material: config.myMaterial,
        shape: config.myShape,
        team: 0,
      );
    }
    for (var i = 0; i < stonesPerTeam; i++) {
      final x = (i * 2 - 7) * gridGap;
      table.addStone(x, -6 * gridGap, team: 1);
    }
  }

  final MatchConfig config;
  final Table table;

  int _turn = 0;
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

  /// 한 수를 쏜다.
  void shoot(Stone s, double angle, double speed, double hit) {
    if (!canShoot(s)) return;
    table.shoot(s, angle, speed, hit);
    _turnCount++;
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

  /// 손가락으로 끈 길이(cm)를 쏘는 속도로 바꾼다. [maxDrag] 를 끌면 최대.
  static double dragToSpeed(double dragCm, {double maxDrag = 10}) =>
      (dragCm / maxDrag).clamp(0.0, 1.0) * baseMaxSpeed;

  /// 돌 중심과 손가락 사이 거리(cm).
  static double distance(Vector2 a, double x, double y) =>
      math.sqrt((a.x - x) * (a.x - x) + (a.y - y) * (a.y - y));

  @override
  void dispose() {
    table.dispose();
    super.dispose();
  }
}
