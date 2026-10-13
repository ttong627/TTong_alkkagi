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
    settleMultiplier: 1.0,
    spinEfficiency: 0.4,
    height: 0.5,
    volume: 1.90,
  ),
  round(
    '둥근 돌',
    dampingMultiplier: 1.0,
    settleMultiplier: 1.6,
    spinEfficiency: 0.7,
    height: 0.8,
    volume: 2.43,
  ),
  sphere(
    '구형 돌',
    dampingMultiplier: 0.7,
    settleMultiplier: 2.6,
    spinEfficiency: 1.0,
    height: 2.2,
    volume: 5.58,
  );

  const StoneShape(
    this.label, {
    required this.dampingMultiplier,
    required this.settleMultiplier,
    required this.spinEfficiency,
    required this.height,
    required this.volume,
  });

  final String label;

  /// 내가 쏜 돌이 첫 충돌 전까지 쓰는 감속 배수(회전 조절로 잘 굴러간다).
  final double dampingMultiplier;

  /// 무게중심 배수: 쏜 돌이 부딪혀 튕긴 뒤, 그리고 맞아서 밀려난 돌은 감속에 이 배수를 더 곱한다.
  ///
  /// 2026-10-14 형 「둥글수록 컨트롤은 어렵지만 … 내가 작동하는 부분은 엄청 잘 움직이지만 튕기는 부분과
  /// 상대가 맞췄을 때는 강한 중력이 발생해서 잘 구르지 않는다는 설정이 있어야 잘 안 죽어」: 예전엔 같은
  /// 빠르기로 밀려나면 구형이 납작한 돌보다 1.3/0.7 ≈ 1.9배 멀리 굴렀다(튕긴 내 돌·센 돌에 맞은 돌이 떨어짐).
  /// 2.6 이면 감속 0.7 × 2.6 = 1.82 로 납작한 돌(1.3)보다 빨리 멈춘다. 둥근 돌 1.6.
  /// 시험: 같은 돌에 맞으면 구형이 예전의 80% 아래 · 납작한 돌보다 덜 간다. [가정 — 실기기로 맞춘다]
  final double settleMultiplier;
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
