/// 재질 13종 · 등급 1~13단 (설계서 v2 §3.5 · 2026-10-14 형 「돌의 종류도 더 다양하게」·
/// 「좋은 재질의 돌일수록 반탄력이 작아야 해 … 종류와 단계를 10여 가지 이상」).
///
/// [density]·[damping]·[restitution] 은 엔진 측정 재현(planck.js)에 쓰는 처음 값이다. 게임 판(`Table.settle`)은
/// [grade] 로 반발([gameRestitution])과 맞았을 때 남는 빠르기([hitKeep])를 정한다 — 좋은 돌일수록 덜 튕기고 덜 밀린다.
enum StoneMaterial {
  cheongok('청옥', grade: 1, density: 1.0, damping: 1.2, restitution: 0.85),
  wood('만년기주', grade: 2, density: 0.5, damping: 0.9, restitution: 0.80),
  hyeoncheol('현철', grade: 3, density: 2.5, damping: 2.0, restitution: 0.75),
  ice('빙백한옥', grade: 6, density: 1.0, damping: 0.15, restitution: 0.95),

  /// 흑요석: 조금 무거운 검은 유리. [가정]
  obsidian('흑요석', grade: 4, density: 1.6, damping: 1.1, restitution: 0.92),

  /// 반석(화강암): 무겁고 빨리 멈춘다 — 버티는 돌. [가정]
  granite('반석', grade: 5, density: 2.2, damping: 2.6, restitution: 0.6),

  /// 금강석: 가볍고 잘 미끄러진다. [가정]
  diamond('금강석', grade: 7, density: 0.8, damping: 0.6, restitution: 0.97),

  /// 자금석: 보랏빛 금 결 — 단단하고 무겁다. [가정]
  jageum('자금석', grade: 8, density: 1.8, damping: 1.4, restitution: 0.7),

  /// 운철: 하늘에서 떨어진 쇠 — 아주 무겁다. [가정]
  uncheol('운철', grade: 9, density: 2.8, damping: 1.6, restitution: 0.65),

  /// 한철: 차가운 쇠 — 무거운데 잘 미끄러진다. [가정]
  hancheol('한철', grade: 10, density: 2.4, damping: 0.8, restitution: 0.6),

  /// 천년온옥: 조각을 모아 완성(기연·퀘스트). 따뜻한 흰 옥. [가정]
  warmJade(
    '천년온옥',
    grade: 11,
    density: 1.4,
    damping: 1.2,
    restitution: 0.55,
    shard: true,
  ),

  /// 용린석: 조각을 모아 완성. 맹주의 용비늘 돌(§16.1). [가정]
  dragonScale(
    '용린석',
    grade: 12,
    density: 2.0,
    damping: 1.0,
    restitution: 0.52,
    shard: true,
  ),

  /// 태극석: 조각을 모아 완성. 음양이 맞물린 돌 — 가장 높은 단. [가정]
  taegeuk(
    '태극석',
    grade: 13,
    density: 1.6,
    damping: 0.9,
    restitution: 0.5,
    shard: true,
  );

  const StoneMaterial(
    this.label, {
    required this.grade,
    required this.density,
    required this.damping,
    required this.restitution,
    this.shard = false,
  });

  final String label;

  /// 등급(1~13단). 높을수록 좋은 돌.
  final int grade;
  final double density;

  /// 감속 값(linear damping). 실제로 쓰는 값은 모양 배수와 감속 하한을 거친다.
  final double damping;
  final double restitution;

  /// 조각을 모아야만 완성하는 돌(만물상에서 팔지 않음).
  final bool shard;

  /// 게임 판의 반발: 1단 0.86 → 13단 0.50(좋은 돌일수록 덜 튕긴다).
  double get gameRestitution => 0.86 - 0.03 * (grade - 1);

  /// 등급만으로 본 버팀: 1단 1 → 13단 0.52(좋은 돌일수록 덜 튕긴다). 쏜 돌이 튕기는 몫에 곱한다.
  double get hitKeep => 1 - 0.04 * (grade - 1);

  /// 게임 판에서 [attacker] 돌이 친 수에 이 돌이 처음 맞는 순간 빠르기에 곱하는 값 — 등급 차이 한 단에 4%
  /// (2026-10-14 형 「내 등급이 올라갈수록 상대는 잘 밀리고 내 돌은 움직임이 작아져야」).
  /// 높은 단이 치면 더 밀리고(최대 ×1.5) 높은 단은 덜 밀린다(최소 ×0.5). 1단이 치면 [hitKeep] 과 같다.
  /// 엔진은 두 돌 반발 가운데 큰 값을 쓰므로, 맞은 돌 쪽에서 따로 곱한다.
  double pushedBy(StoneMaterial attacker) =>
      (1 + 0.04 * (attacker.grade - grade)).clamp(0.5, 1.5);
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
