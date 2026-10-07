import 'dart:math' as math;

import 'package:forge2d/forge2d.dart';

import 'constants.dart';
import 'materials.dart';

/// 물리 엔진을 한 번 준비한다. 판([Table])을 만들기 전에 반드시 기다린다.
Future<void> initializePhysics() => initializeForge2D();

/// 판 위의 돌 하나.
class Stone {
  Stone._(this.id, this.team, this.material, this.shape, this.body);

  /// 판 안에서 붙인 번호(0부터).
  final int id;

  /// 편(0 = 나, 1 = 상대).
  final int team;
  final StoneMaterial material;
  final StoneShape shape;
  final Body body;

  /// 장외(판 밖으로 나가 탈락)인가.
  bool out = false;

  double _spin = 0;
  bool _spinUsed = true;

  /// 지금 위치(cm). 판 중심이 (0, 0).
  Vector2 get position => body.position;

  /// 지금 속도(cm/s).
  Vector2 get velocity => body.linearVelocity;

  /// 지금 남은 회전량(−1~+1 × 모양 회전 효율).
  double get spin => _spin;
}

/// 판 모양. 돌 중심이 이 경계 밖으로 나가면 장외.
enum Boundary {
  /// 한 변 [PhysicsConstants.board] 인 네모 판.
  square,

  /// 지름 [PhysicsConstants.board] 인 둥근 판(객잔 원탁 등).
  circle;

  /// (x, y) 가 판 밖인가.
  bool isOut(double x, double y) {
    const h = PhysicsConstants.halfBoard;
    return switch (this) {
      Boundary.square => x.abs() > h || y.abs() > h,
      Boundary.circle => x * x + y * y > h * h,
    };
  }

  /// (x, y) 에서 가장 가까운 판 가장자리까지 거리(cm). 밖이면 음수.
  double edgeDistance(double x, double y) {
    const h = PhysicsConstants.halfBoard;
    return switch (this) {
      Boundary.square => h - math.max(x.abs(), y.abs()),
      Boundary.circle => h - math.sqrt(x * x + y * y),
    };
  }
}

/// 한 수의 진행 상태.
enum TurnStatus {
  /// 아직 쏘지 않았거나 이미 끝남.
  idle,

  /// 돌이 움직이는 중.
  moving,

  /// 모든 돌이 멈춤.
  rested,

  /// 10초가 지나 강제로 멈춤.
  timedOut,
}

/// 한 수를 끝까지 계산한 결과.
class TurnResult {
  const TurnResult({required this.steps, required this.timedOut});

  /// 걸린 스텝 수(60스텝 = 1초).
  final int steps;

  /// 10초 강제 정지였는가.
  final bool timedOut;

  /// 게임 속 시간(초).
  double get seconds => steps * PhysicsConstants.step;
}

/// 바둑판 하나(물리 세계 하나).
///
/// 위에서 내려다본 2D. 바닥 마찰은 감속 값으로, 상·중·하 타격은 회전 보정으로 만든다
/// (설계서 v2 §3.2·§3.3).
class Table {
  Table({
    this.minDamping = PhysicsConstants.minDamping,
    this.floorFactor = 1.0,
    this.boundary = Boundary.square,
  }) : world = World(
         gravity: Vector2.zero(),
         definition: WorldDef(gravity: Vector2.zero(), hitEventThreshold: 0.01),
       );

  /// 감속 하한. 게임은 기본값 0.3 을 쓰고, 시험만 다른 값을 쓴다.
  final double minDamping;

  /// 바닥 감속 배수(대전장마다 다름). 1 이면 재질 × 모양 그대로.
  /// 흙바닥은 크게(잘 멈춤), 기름·얼음 바닥은 작게(잘 미끄러짐) 준다.
  final double floorFactor;

  /// 판 모양.
  final Boundary boundary;
  final World world;
  final List<Stone> stones = [];

  Stone? _shooter;
  int _turnSteps = 0;
  TurnStatus _status = TurnStatus.idle;

  /// 지금 한 수의 상태.
  TurnStatus get status => _status;

  /// 지금 한 수에서 지난 스텝 수.
  int get turnSteps => _turnSteps;

  /// 이 재질·모양에 실제로 쓰는 감속 값(바닥 배수를 곱한 뒤 하한 적용).
  double dampingOf(StoneMaterial material, StoneShape shape) => math.max(
    minDamping,
    material.damping * shape.dampingMultiplier * floorFactor,
  );

  /// 돌을 놓는다.
  Stone addStone(
    double x,
    double y, {
    StoneMaterial material = StoneMaterial.cheongok,
    StoneShape shape = StoneShape.round,
    int team = 0,
  }) {
    final body = world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: Vector2(x, y),
        linearDamping: dampingOf(material, shape),
        angularDamping: PhysicsConstants.angularDamping,
        isBullet: true,
        enableSleep: false,
      ),
    );
    body.createShape(
      Circle(radius: PhysicsConstants.stoneRadius),
      ShapeDef(
        density: material.density,
        material: SurfaceMaterial(
          friction: PhysicsConstants.stoneFriction,
          restitution: material.restitution,
        ),
        enableContactEvents: true,
        enableHitEvents: true,
      ),
    );
    final stone = Stone._(stones.length, team, material, shape, body);
    body.userData = stone;
    stones.add(stone);
    return stone;
  }

  /// 한 수를 쏜다.
  ///
  /// [angle] 라디안(오른쪽 0, 반시계 방향), [speed] 처음 속도(cm/s),
  /// [hit] 타격점 −1(하)~0(중)~+1(상).
  void shoot(Stone stone, double angle, double speed, double hit) {
    if (stone.out) throw StateError('장외된 돌은 쏠 수 없다');
    final s = speed.clamp(0.0, PhysicsConstants.maxShotSpeed);
    stone._spin = hit.clamp(-1.0, 1.0) * stone.shape.spinEfficiency;
    stone._spinUsed = false;
    stone.body.linearVelocity = Vector2(
      math.cos(angle) * s,
      math.sin(angle) * s,
    );
    _shooter = stone;
    _turnSteps = 0;
    _status = TurnStatus.moving;
  }

  /// 1스텝(1/60초) 진행한다. 화면은 이것을 프레임마다 부른다.
  TurnStatus step() {
    if (_status != TurnStatus.moving) return _status;
    final shooter = _shooter!;
    final pre = shooter.velocity;
    world.step(PhysicsConstants.step);
    _turnSteps++;

    if (!shooter._spinUsed) {
      // 굴러가며 회전이 풀린다.
      shooter._spin *= math.exp(
        -PhysicsConstants.step / PhysicsConstants.spinDecaySeconds,
      );
      if (_shooterHit(shooter)) {
        // 첫 충돌 직후: 충돌 직전 진행 방향으로 0.5 × 회전 × 직전 속도.
        final sp = pre.length;
        if (sp > 0 && shooter._spin != 0) {
          final add = pre.normalized()
            ..scale(PhysicsConstants.spinStrength * shooter._spin * sp);
          shooter.body.linearVelocity = shooter.velocity + add;
        }
        shooter._spinUsed = true;
      }
    }

    var moving = false;
    for (final s in stones) {
      if (s.out) continue;
      final p = s.position;
      if (boundary.isOut(p.x, p.y)) {
        s.out = true;
        s.body.linearVelocity = Vector2.zero();
        s.body.isEnabled = false;
        continue;
      }
      if (s.velocity.length > PhysicsConstants.restSpeed) moving = true;
    }

    if (!moving) {
      _status = TurnStatus.rested;
    } else if (_turnSteps >= PhysicsConstants.maxTurnSteps) {
      for (final s in stones) {
        if (!s.out) s.body.linearVelocity = Vector2.zero();
      }
      _status = TurnStatus.timedOut;
    }
    return _status;
  }

  /// 한 수를 멈출 때까지 한 번에 계산한다(서버 판정·AI 미리 보기용).
  TurnResult runTurn() {
    while (step() == TurnStatus.moving) {}
    final result = TurnResult(
      steps: _turnSteps,
      timedOut: _status == TurnStatus.timedOut,
    );
    _status = TurnStatus.idle;
    return result;
  }

  /// 화면이 [step]으로 한 수를 끝낸 뒤 다음 수를 받을 수 있게 한다.
  void endTurn() => _status = TurnStatus.idle;

  bool _shooterHit(Stone shooter) {
    for (final h in world.contactEvents.hit) {
      if (h.shapeA.body == shooter.body || h.shapeB.body == shooter.body) {
        return true;
      }
    }
    return false;
  }

  /// 물리 세계를 정리한다. 다 쓴 판은 반드시 부른다.
  void dispose() => world.destroy();
}
