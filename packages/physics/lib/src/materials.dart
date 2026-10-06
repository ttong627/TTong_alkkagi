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
enum StoneShape {
  flat('납작한 돌', dampingMultiplier: 1.3, spinEfficiency: 0.4),
  round('둥근 돌', dampingMultiplier: 1.0, spinEfficiency: 0.7),
  sphere('구형 돌', dampingMultiplier: 0.7, spinEfficiency: 1.0);

  const StoneShape(
    this.label, {
    required this.dampingMultiplier,
    required this.spinEfficiency,
  });

  final String label;
  final double dampingMultiplier;
  final double spinEfficiency;
}
