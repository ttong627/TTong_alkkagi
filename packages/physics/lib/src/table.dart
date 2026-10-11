import 'dart:math' as math;

import 'package:forge2d/forge2d.dart';

import 'constants.dart';
import 'materials.dart';
import 'techniques.dart';
import 'terrain.dart';

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

  /// 분신으로 잠깐 생긴 돌인가(한 수가 끝나면 사라진다).
  bool phantom = false;

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
    double floorFactor = 1.0,
    this.boundary = Boundary.square,
    this.weather = Weather.clear,
    this.windSeed = 0,
  }) : _floorFactor = weather == Weather.nightRain
           ? floorFactor * 0.5
           : floorFactor,
       world = World(
         gravity: Vector2.zero(),
         definition: WorldDef(gravity: Vector2.zero(), hitEventThreshold: 0.01),
       );

  /// 감속 하한. 게임은 기본값 0.3 을 쓰고, 시험만 다른 값을 쓴다.
  final double minDamping;

  /// 바닥 감속 배수(대전장마다 다름). 1 이면 재질 × 모양 그대로.
  /// 흙바닥은 크게(잘 멈춤), 기름·얼음 바닥은 작게(잘 미끄러짐) 준다. 야우면 절반.
  double get floorFactor => _floorFactor;
  double _floorFactor;

  /// 바닥 배수를 바꾼다(6장 얼음·불꽃이 바뀌는 바닥). 바닥에 붙은 돌의 감속을 다시 맞춘다.
  set floorFactor(double v) {
    _floorFactor = v;
    for (final s in stones) {
      if (!s.out && !s.airborne) {
        s.body.linearDamping = dampingOf(s.material, s.shape);
      }
    }
  }

  /// 날씨(천기).
  final Weather weather;

  /// 광풍 바람 방향을 정하는 씨앗(같은 씨앗이면 같은 바람 — 판정이 같게).
  final int windSeed;

  /// 판 위 지물.
  final List<Feature> features = [];
  final Map<Feature, Body> _featureBodies = {};

  /// 이번 스텝에 지형이 일으킨 일(연출용).
  final List<TerrainEvent> terrainEvents = [];

  final Map<int, int> _frostHits = {};
  int _windStep = 0;

  /// 지금 바람 방향(라디안). 광풍이 아니면 null.
  double? get windAngle => weather == Weather.gale
      ? ((windSeed * 7919 +
                    (_windStep ~/ TerrainConstants.galeSteps) * 104729) %
                360) *
            math.pi /
            180
      : null;

  /// 판 모양.
  final Boundary boundary;
  final World world;
  final List<Stone> stones = [];

  Stone? _shooter;
  int _turnSteps = 0;
  TurnStatus _status = TurnStatus.idle;

  /// 이번 스텝에 일어난 충돌(연출용). 스텝마다 새로 채운다.
  final List<Impact> impacts = [];

  /// 이번 스텝에 발동한 무공·스킬(연출용). 스텝마다 새로 채운다.
  final List<TechniqueEvent> events = [];

  Technique _technique = Technique.none;
  bool _inner = false;
  double _curl = 0;
  bool _firstHit = false;
  int _swordQiLeft = 0;
  int _absorbLeft = 0;
  Vector2? _absorbAt;
  final Set<int> _enemiesHit = {};
  bool _cloneUsed = false;
  double _impactScale = 1;

  /// 지금 수에서 쏜 돌.
  Stone? get shooter => _shooter;

  /// 지금 수의 무공·스킬.
  Technique get technique => _technique;

  /// 지금 수가 내공 타격인가.
  bool get inner => _inner;

  /// 이번 판에 분신을 썼는가(판당 1회).
  bool get cloneUsed => _cloneUsed;

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

  /// 지물을 놓는다(나뭇가지·조약돌·청죽·경종·블랙홀·지뢰석).
  void addFeature(Feature f) {
    features.add(f);
    final body = world.createBody(
      BodyDef(type: BodyType.static, position: Vector2(f.x, f.y)),
    );
    final geometry = f.kind == FeatureKind.branch
        ? Polygon.box(f.size, TerrainConstants.branchHalfThickness)
        : Circle(radius: f.size);
    if (f.kind == FeatureKind.branch) {
      body.setTransform(Vector2(f.x, f.y), Rot.fromAngle(f.angle));
    }
    final restitution = switch (f.kind) {
      FeatureKind.branch => 0.3,
      FeatureKind.pebble => 0.5,
      FeatureKind.bamboo => TerrainConstants.bambooRestitution,
      FeatureKind.gong => 0.6,
      FeatureKind.blackHole || FeatureKind.mine => 0.2,
    };
    body.createShape(
      geometry,
      ShapeDef(
        material: SurfaceMaterial(friction: 0.2, restitution: restitution),
        enableContactEvents: true,
        enableHitEvents: true,
        // 블랙홀은 부딪히지 않고 빨아들이기만 한다.
        filter: f.kind == FeatureKind.blackHole ? Filter(maskBits: 0) : null,
      ),
    );
    body.userData = f;
    _featureBodies[f] = body;
  }

  /// 한 수를 쏜다.
  ///
  /// [angle] 라디안(오른쪽 0, 반시계 방향), [speed] 처음 속도(cm/s),
  /// [hit] 타격점 −1(하)~0(중)~+1(상).
  ///
  /// [lift] 면 [hit] 이 [PhysicsConstants.liftThreshold] 를 넘을 때 돌이 뜬다([liftOf]).
  /// 끄면(기본) 예전처럼 회전만 준다 — 측정 재현 시험과 AI 가 쓴다.
  ///
  /// [inner] 면 내공 타격: 처음 속도 ×[TechniqueConstants.innerSpeed], 첫 충돌로 맞은 돌이 더 세게
  /// 밀리고, [technique] 무공·스킬이 발동한다. [curl] 은 태극의 휘는 방향·세기(−1~+1).
  void shoot(
    Stone stone,
    double angle,
    double speed,
    double hit, {
    bool lift = false,
    bool inner = false,
    Technique technique = Technique.none,
    double curl = 0,
    double spinScale = 1,
    double impactScale = 1,
    double innerSpeed = TechniqueConstants.innerSpeed,
  }) {
    if (stone.out) throw StateError('장외된 돌은 쏠 수 없다');
    _inner = inner;
    _technique = technique;
    _curl = curl.clamp(-1.0, 1.0);
    _firstHit = false;
    _swordQiLeft = 0;
    _absorbLeft = 0;
    _absorbAt = null;
    _enemiesHit.clear();
    _frostHits.clear();
    _impactScale = impactScale;
    final s = (inner ? speed * innerSpeed : speed).clamp(
      0.0,
      PhysicsConstants.maxShotSpeed,
    );
    final h = hit.clamp(-1.0, 1.0);
    stone._spin = h * stone.shape.spinEfficiency * spinScale;
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

  /// 궁극기 어기어석: 지금 쏜 돌을 [angle] 쪽으로 꺾는다. 빠르기는 그대로(설계서 §3.7).
  void redirect(double angle) {
    final s = _shooter;
    if (s == null || s.out || _status != TurnStatus.moving) return;
    final sp = s.velocity.length;
    s.body.linearVelocity = Vector2(math.cos(angle) * sp, math.sin(angle) * sp);
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
    _beforeStep(shooter);
    terrainEvents.clear();
    _terrainBefore();
    world.step(PhysicsConstants.step);
    _turnSteps++;
    _collectImpacts();
    _terrainAfter();
    for (final s in stones) {
      if (!s.out && s.airborne) _fall(s);
    }
    final shooterImpact = _impactOf(shooter);
    if (shooterImpact != null) _afterShooterHit(shooter, shooterImpact, pre);

    if (!shooter._spinUsed) {
      // 굴러가며 회전이 풀린다.
      shooter._spin *= math.exp(
        -PhysicsConstants.step / PhysicsConstants.spinDecaySeconds,
      );
      if (shooterImpact != null) {
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

    if (_absorbLeft > 0 || _swordQiLeft > 0) moving = true;
    if (!moving) {
      _status = TurnStatus.rested;
      _clearPhantoms();
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
      _clearPhantoms();
    }
    return _status;
  }

  /// 한 스텝 앞: 태극으로 휘고, 흡성탄지로 끌어당긴다.
  void _beforeStep(Stone shooter) {
    impacts.clear();
    events.clear();
    const dt = PhysicsConstants.step;
    if (_inner &&
        _technique == Technique.taiji &&
        !_firstHit &&
        _curl != 0 &&
        !shooter.out) {
      final v = shooter.velocity;
      final sp = v.length;
      if (sp > PhysicsConstants.restSpeed) {
        final side = Vector2(-v.y, v.x)..scale(1 / sp);
        final a = TechniqueConstants.taijiCurl * sp * _curl;
        shooter.body.linearVelocity = v + side * (a * dt);
      }
    }
    final at = _absorbAt;
    if (_absorbLeft > 0 && at != null) {
      _absorbLeft--;
      for (final s in stones) {
        if (s.out || identical(s, shooter)) continue;
        final d = at - s.position;
        final len = d.length;
        // 닿을 만큼 가까우면(돌 지름) 더 끌지 않는다.
        if (len <= PhysicsConstants.stoneRadius * 2 ||
            len > TechniqueConstants.absorbRadius) {
          continue;
        }
        // 그 지점 쪽으로 가는 빠르기를 [TechniqueConstants.absorbPull] 만큼씩 키운다(가까울수록 약하게).
        final want = d..scale(TechniqueConstants.absorbPull * dt / len);
        s.body.linearVelocity = s.velocity * 0.9 + want;
      }
    }
    if (_swordQiLeft > 0) {
      _swordQiLeft--;
      if (_swordQiLeft == 0 && !shooter.airborne && !shooter.out) {
        shooter.body.linearDamping = dampingOf(shooter.material, shooter.shape);
      }
    }
  }

  /// 한 스텝 앞: 광풍·블랙홀.
  void _terrainBefore() {
    const dt = PhysicsConstants.step;
    final wind = windAngle;
    if (wind != null) {
      _windStep++;
      final push = Vector2(math.cos(wind), math.sin(wind))
        ..scale(TerrainConstants.galeAccel * dt);
      for (final s in stones) {
        if (s.out || s.velocity.length <= PhysicsConstants.restSpeed) continue;
        s.body.linearVelocity = s.velocity + push;
      }
    }
    for (final f in features) {
      if (f.kind != FeatureKind.blackHole) continue;
      final c = Vector2(f.x, f.y);
      for (final s in stones) {
        if (s.out || s.airborne) continue;
        final d = c - s.position;
        final len = d.length;
        if (len > TerrainConstants.holeRadius) continue;
        if (len <= TerrainConstants.holeSwallow) {
          s.out = true;
          s.body.linearVelocity = Vector2.zero();
          s.body.isEnabled = false;
          terrainEvents.add(TerrainEvent(TerrainFx.swallow, f.x, f.y));
          continue;
        }
        d.scale(TerrainConstants.holePull * dt / len);
        s.body.linearVelocity = s.velocity + d;
      }
    }
  }

  /// 한 스텝 뒤: 지물에 부딪힌 돌(경종·지뢰석·청죽)과 혹한.
  void _terrainAfter() {
    for (final h in world.contactEvents.hit) {
      final ua = h.shapeA.body.userData, ub = h.shapeB.body.userData;
      final f = ua is Feature ? ua : (ub is Feature ? ub : null);
      final st = ua is Stone ? ua : (ub is Stone ? ub : null);
      if (f == null || st == null) continue;
      switch (f.kind) {
        case FeatureKind.gong:
          for (final s in stones) {
            if (s.out || s.team == st.team) continue;
            final d = s.position - Vector2(f.x, f.y);
            final len = d.length;
            if (len <= 0.01 || len > TerrainConstants.gongRadius) continue;
            d.scale(TerrainConstants.gongPush / len);
            s.body.linearVelocity = s.velocity + d;
          }
          terrainEvents.add(TerrainEvent(TerrainFx.gong, f.x, f.y));
        case FeatureKind.mine:
          final c = Vector2(f.x, f.y);
          st.out = true;
          st.body.linearVelocity = Vector2.zero();
          st.body.isEnabled = false;
          for (final s in stones) {
            if (s.out) continue;
            final d = s.position - c;
            final len = d.length;
            if (len <= 0.01 || len > TerrainConstants.mineRadius) continue;
            d.scale(TerrainConstants.minePush / len);
            s.body.linearVelocity = s.velocity + d;
          }
          _featureBodies.remove(f)?.destroy();
          features.remove(f);
          terrainEvents.add(TerrainEvent(TerrainFx.mine, f.x, f.y));
        case FeatureKind.bamboo:
          terrainEvents.add(
            TerrainEvent(TerrainFx.bamboo, h.point.x, h.point.y),
          );
        case FeatureKind.branch || FeatureKind.pebble || FeatureKind.blackHole:
          break;
      }
    }
    if (weather == Weather.frost) {
      for (final i in impacts) {
        for (final id in [i.a, i.b]) {
          final n = (_frostHits[id] ?? 0) + 1;
          _frostHits[id] = n;
          final s = stones[id];
          if (n >= TerrainConstants.frostStopAt) {
            s.body.linearVelocity = Vector2.zero();
            terrainEvents.add(
              TerrainEvent(TerrainFx.frostStop, s.position.x, s.position.y),
            );
          } else {
            s.body.linearVelocity = s.velocity
              ..scale(TerrainConstants.frostSlow);
          }
        }
      }
    }
  }

  /// 이번 스텝 충돌을 모은다.
  void _collectImpacts() {
    for (final h in world.contactEvents.hit) {
      final a = h.shapeA.body.userData, b = h.shapeB.body.userData;
      if (a is! Stone || b is! Stone) continue;
      impacts.add(Impact(a.id, b.id, h.point.x, h.point.y, h.approachSpeed));
    }
  }

  Impact? _impactOf(Stone s) {
    for (final i in impacts) {
      if (i.a == s.id || i.b == s.id) return i;
    }
    return null;
  }

  /// 쏜 돌이 부딪힌 스텝: 내공 타격·무공·스킬을 발동한다.
  void _afterShooterHit(Stone shooter, Impact hit, Vector2 pre) {
    final otherId = hit.a == shooter.id ? hit.b : hit.a;
    final other = stones[otherId];
    if (other.team != shooter.team) _enemiesHit.add(otherId);
    final point = Vector2(hit.x, hit.y);
    if (!_firstHit) {
      _firstHit = true;
      if (_impactScale != 1) {
        other.body.linearVelocity = other.velocity..scale(_impactScale);
      }
      if (_inner) {
        other.body.linearVelocity = other.velocity
          ..scale(TechniqueConstants.innerImpact);
        events.add(TechniqueEvent(TechniqueFx.innerImpact, hit.x, hit.y));
        switch (_technique) {
          case Technique.swordQi:
            _swordQiLeft = TechniqueConstants.swordQiSteps;
            if (!shooter.airborne) {
              shooter.body.linearDamping =
                  dampingOf(shooter.material, shooter.shape) *
                  TechniqueConstants.swordQiDamping;
            }
            events.add(
              TechniqueEvent(
                TechniqueFx.swordQi,
                hit.x,
                hit.y,
                stoneId: shooter.id,
              ),
            );
          case Technique.stomp:
            for (final s in stones) {
              if (s.out || identical(s, shooter) || identical(s, other)) {
                continue;
              }
              final d = s.position - point;
              final len = d.length;
              if (len <= 0.01 || len > TechniqueConstants.stompRadius) continue;
              d.scale(TechniqueConstants.stompPush / len);
              s.body.linearVelocity = s.velocity + d;
            }
            events.add(TechniqueEvent(TechniqueFx.stomp, hit.x, hit.y));
          case Technique.absorb:
            _absorbLeft = TechniqueConstants.absorbSteps;
            _absorbAt = point;
            events.add(TechniqueEvent(TechniqueFx.absorb, hit.x, hit.y));
          case Technique.none || Technique.taiji || Technique.clone:
            break;
        }
      }
    }
    if (_inner &&
        _technique == Technique.clone &&
        !_cloneUsed &&
        _enemiesHit.length >= 2) {
      _cloneUsed = true;
      final v = shooter.velocity.length > 1 ? shooter.velocity : pre;
      final a =
          math.atan2(v.y, v.x) +
          TechniqueConstants.cloneDegrees * math.pi / 180;
      final sp = v.length * TechniqueConstants.cloneSpeed;
      final side = Vector2(-math.sin(a), math.cos(a))
        ..scale(PhysicsConstants.stoneRadius * 2.1);
      final p = shooter.position + side;
      final twin = addStone(
        p.x,
        p.y,
        material: shooter.material,
        shape: shooter.shape,
        team: shooter.team,
      )..phantom = true;
      twin.body.linearVelocity = Vector2(math.cos(a) * sp, math.sin(a) * sp);
      events.add(TechniqueEvent(TechniqueFx.clone, p.x, p.y, stoneId: twin.id));
    }
  }

  /// 분신으로 생긴 돌은 한 수가 끝나면 사라진다(맨 뒤에만 붙는다).
  void _clearPhantoms() {
    while (stones.isNotEmpty && stones.last.phantom) {
      final s = stones.removeLast();
      s.body.destroy();
    }
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

  /// 물리 세계를 정리한다. 다 쓴 판은 반드시 부른다.
  void dispose() => world.destroy();
}
