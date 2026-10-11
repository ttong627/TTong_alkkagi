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
  double _z = 0;
  double _vz = 0;
  bool _ghost = false;

  /// 바닥에서 뜬 높이(cm). 0 이면 바닥에 있다.
  double get z => _z;

  /// 위아래 빠르기(cm/s). 위로 +.
  double get vz => _vz;

  /// 공중에 떠 있는가(떠서 날아가거나 튀어 오른 중).
  bool get airborne => _z > 0 || _vz > 0;

  /// 무게(상대값 = 재질 밀도 × 모양 부피).
  double get mass => stoneMass(material, shape);

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
/// 위에서 내려다본 2D + 높이. 바닥 마찰은 감속 값으로, 상·중·하 타격은 회전 보정으로 만든다
/// (설계서 v2 §3.2·§3.3). 타격점이 위·아래 끝에 가까우면 돌이 뜬다: 아래를 맞으면 떠서 날아가고,
/// 위를 맞으면 바닥에 눌렸다 튀어 오른다. 뜬 돌은 중력으로 떨어지고, 높이 떠 있는 동안은
/// 다른 돌 위를 넘어가며 바닥 마찰을 받지 않는다.
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
        // 무게 = 재질 밀도 × 모양 부피. 둥근 돌을 기준(1배)으로 잡아 예전 측정값과 같게 둔다.
        density: material.density * shape.volume / StoneShape.round.volume,
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
  ///
  /// [lift] 면 [hit] 이 [PhysicsConstants.liftThreshold] 를 넘을 때 돌이 뜬다([liftOf]).
  /// 끄면(기본) 예전처럼 회전만 준다 — 측정 재현 시험과 AI 가 쓴다.
  void shoot(
    Stone stone,
    double angle,
    double speed,
    double hit, {
    bool lift = false,
  }) {
    if (stone.out) throw StateError('장외된 돌은 쏠 수 없다');
    final s = speed.clamp(0.0, PhysicsConstants.maxShotSpeed);
    final h = hit.clamp(-1.0, 1.0);
    stone._spin = h * stone.shape.spinEfficiency;
    stone._spinUsed = false;
    final (along, up) = lift ? liftOf(s, h) : (s, 0.0);
    stone.body.linearVelocity = Vector2(
      math.cos(angle) * along,
      math.sin(angle) * along,
    );
    stone._z = 0;
    stone._vz = up;
    _shooter = stone;
    _turnSteps = 0;
    _status = TurnStatus.moving;
  }

  /// 처음 빠르기 [speed] · 타격점 [hit] → (옆 빠르기, 위로 빠르기) cm/s.
  ///
  /// 문턱([PhysicsConstants.liftThreshold]) 안쪽은 뜨지 않는다. 넘으면 넘은 만큼 들리는 각도가
  /// 커져 ±1 에서 [PhysicsConstants.maxLiftDegrees]. 아래(−)를 맞으면 그 각도로 떠서 날아가고,
  /// 위(+)를 맞으면 같은 각도로 바닥에 눌렸다가 [PhysicsConstants.floorBounce] 만큼 튀어 오른다.
  static (double along, double up) liftOf(double speed, double hit) {
    final over =
        ((hit.abs() - PhysicsConstants.liftThreshold) /
                (1 - PhysicsConstants.liftThreshold))
            .clamp(0.0, 1.0);
    if (over == 0) return (speed, 0);
    final a = over * PhysicsConstants.maxLiftDegrees * math.pi / 180;
    final along = speed * math.cos(a);
    final up = speed * math.sin(a);
    return hit < 0 ? (along, up) : (along, up * PhysicsConstants.floorBounce);
  }

  /// 1스텝(1/60초) 진행한다. 화면은 이것을 프레임마다 부른다.
  TurnStatus step() {
    if (_status != TurnStatus.moving) return _status;
    final shooter = _shooter!;
    final pre = shooter.velocity;
    for (final s in stones) {
      if (!s.out && s.airborne) {
        _setGhost(s, s._z > PhysicsConstants.clearHeight);
      }
    }
    world.step(PhysicsConstants.step);
    _turnSteps++;
    for (final s in stones) {
      if (!s.out && s.airborne) _fall(s);
    }

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
      if (s.airborne) {
        // 떠 있는 동안은 판 밖 위를 지나가도 아직 떨어지지 않았다.
        moving = true;
        continue;
      }
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
        if (s.out) continue;
        s.body.linearVelocity = Vector2.zero();
        if (s.airborne) {
          s._z = 0;
          s._vz = 0;
          _setGhost(s, null);
          _land(s);
        }
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

  /// 떠 있는 돌은 바닥 마찰을 받지 않고, [PhysicsConstants.clearHeight] 보다 높으면
  /// 다른 돌과 부딪히지 않는다(위로 넘어간다). [ghost] 가 null 이면 바닥에 붙은 돌로 되돌린다.
  void _setGhost(Stone s, bool? ghost) {
    final g = ghost ?? false;
    if (s._ghost != g) {
      s._ghost = g;
      for (final sh in s.body.shapes) {
        sh.filter = Filter(maskBits: g ? 0 : Filter.allCategories);
      }
    }
    s.body.linearDamping = ghost == null ? dampingOf(s.material, s.shape) : 0;
  }

  /// 중력으로 떨어뜨리고, 바닥에 닿으면 튀거나 붙는다.
  void _fall(Stone s) {
    const dt = PhysicsConstants.step;
    // 한 스텝 동안 고른 가속(정확한 식): z += vz·dt − ½·g·dt², vz −= g·dt.
    s._z += s._vz * dt - 0.5 * PhysicsConstants.gravity * dt * dt;
    s._vz -= PhysicsConstants.gravity * dt;
    if (s._z > 0) return;
    s._z = 0;
    final hitSpeed = -s._vz;
    s.body.linearVelocity = s.velocity..scale(PhysicsConstants.landingKeep);
    final bounce = hitSpeed * PhysicsConstants.floorBounce;
    if (bounce > PhysicsConstants.settleSpeed) {
      s._vz = bounce;
    } else {
      s._vz = 0;
      _setGhost(s, null);
      _land(s);
    }
  }

  /// 바닥에 붙은 순간 판 밖이면 장외.
  void _land(Stone s) {
    final p = s.position;
    if (boundary.isOut(p.x, p.y)) {
      s.out = true;
      s.body.linearVelocity = Vector2.zero();
      s.body.isEnabled = false;
    }
  }

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
