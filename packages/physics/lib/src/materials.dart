/// 재질 4종 (설계서 v2 §3.5).
enum StoneMaterial {
  cheongok('청옥', density: 1.0, damping: 1.2, restitution: 0.85),
  wood('만년기주', density: 0.5, damping: 0.9, restitution: 0.80),
  hyeoncheol('현철', density: 2.5, damping: 2.0, restitution: 0.75),
  ice('빙백한옥', density: 1.0, damping: 0.15, restitution: 0.95);

  const StoneMaterial(
    this.label, {
    required this.density,
    required this.damping,
    required this.restitution,
  });

  final String label;
  final double density;

  /// 감속 값(linear damping). 실제로 쓰는 값은 모양 배수와 감속 하한을 거친다.
  final double damping;
  final double restitution;
}

/// 모양 3종 (설계서 v2 §3.6).
///
/// 위에서 본 반지름은 모두 [PhysicsConstants.stoneRadius](1.1cm)이고 높이·부피가 다르다.
/// 부피 = 납작한 돌은 원기둥, 둥근 돌은 모서리를 깎은 원기둥(원기둥의 80%), 구형 돌은 공.
enum StoneShape {
  flat(
    '납작한 돌',
    dampingMultiplier: 1.3,
    spinEfficiency: 0.4,
    height: 0.5,
    volume: 1.90,
  ),
  round(
    '둥근 돌',
    dampingMultiplier: 1.0,
    spinEfficiency: 0.7,
    height: 0.8,
    volume: 2.43,
  ),
  sphere(
    '구형 돌',
    dampingMultiplier: 0.7,
    spinEfficiency: 1.0,
    height: 2.2,
    volume: 5.58,
  );

  const StoneShape(
    this.label, {
    required this.dampingMultiplier,
    required this.spinEfficiency,
    required this.height,
    required this.volume,
  });

  final String label;
  final double dampingMultiplier;
  final double spinEfficiency;

  /// 높이(cm).
  final double height;

  /// 부피(cm³). 반지름 1.1cm 기준: 원기둥 π·1.1²·0.5 = 1.90, π·1.1²·0.8 × 0.8 = 2.43,
  /// 공 4/3·π·1.1³ = 5.58.
  final double volume;
}

/// 돌 무게(상대값 = 재질 밀도 × 모양 부피). 둥근 청옥 돌 = 2.43.
double stoneMass(StoneMaterial material, StoneShape shape) =>
    material.density * shape.volume;
