/// 영수(펫) — 2026-10-20 형 「펫 시스템도 도입해서 펫이 함께 돌을 날리고 돌을 보호하고 방어 하는 시스템도 …
/// 펫의 종류와 능력치에 따라서 돌을 한번에 여러개 움직일 수 있도록」.
///
/// 한 마리를 데리고 다닌다. 레벨(1~[maxLevel])은 엽전 먹이로 오르고, 능력이 레벨을 따라 커진다.
enum PetKind {
  squirrel('다람쥐 날쌘돌', '함께 튕기기 — 내가 칠 때 확률로 내 돌 하나를 상대 쪽으로 같이 튕긴다', price: 0),
  turtle('거북 금강', '수호 — 상대가 칠 때 내 돌이 덜 밀린다', price: 4000),
  crane('학 청학', '겨눔 — 방향 보정 폭이 넓어진다', price: 6000),
  tiger('호랑이 백호', '합공 — 판마다 정해진 번, 돌 둘을 한꺼번에 쏜다', price: 15000),
  dragon('용 금룡', '용의 합공 — 판마다 한 번, 돌 셋(+)을 한꺼번에 쏘고 정면이면 박살', price: 40000);

  const PetKind(this.label, this.role, {required this.price});
  final String label;
  final String role;

  /// 데려오는 값(엽전). 날쌘돌은 처음부터.
  final int price;

  static const int maxLevel = 10;

  /// [level] 에서 다음 레벨로 먹이 값(엽전).
  static int feedCost(int level) => 300 * level;

  /// 그림 이름(icons/pet_이름.webp).
  String get art => 'pet_$name';

  /// 날쌘돌: 내가 칠 때 함께 튕길 확률(레벨 1 = 25% → 10 = 52%).
  static double assistChance(int level) => 0.22 + 0.03 * level;

  /// 날쌘돌: 함께 튕기는 돌의 빠르기(cm/s).
  static double assistSpeed(int level) => 55.0 + 5 * level;

  /// 금강: 상대 수에 내 돌이 밀리는 배수(레벨 1 = 0.88 → 10 = 0.6).
  static double guard(int level) => (0.91 - 0.031 * level).clamp(0.6, 1.0);

  /// 청학: 방향 보정 폭(라디안 · 기본 0.07 = 약 4도 → 레벨 10 약 11도).
  static double aim(int level) => 0.07 + 0.012 * level;

  /// 백호·금룡: 판마다 합공 횟수.
  int volleys(int level) => switch (this) {
    PetKind.tiger => level >= 7 ? 3 : (level >= 4 ? 2 : 1),
    PetKind.dragon => level >= 8 ? 2 : 1,
    _ => 0,
  };

  /// 백호·금룡: 합공 때 함께 나가는 돌 수(쏜 돌 빼고).
  int volleyWing(int level) => switch (this) {
    PetKind.tiger => 1,
    PetKind.dragon => level >= 5 ? 3 : 2,
    _ => 0,
  };

  /// 지금 레벨의 능력 한 줄(화면용).
  String detail(int level) => switch (this) {
    PetKind.squirrel =>
      '함께 튕길 확률 ${(assistChance(level) * 100).round()}% · 빠르기 ${assistSpeed(level).round()}',
    PetKind.turtle => '상대 수에 내 돌 밀림 ×${guard(level).toStringAsFixed(2)}',
    PetKind.crane =>
      '방향 보정 ${(aim(level) * 180 / 3.14159).toStringAsFixed(1)}도',
    PetKind.tiger => '합공 판마다 ${volleys(level)}번 · 돌 2개',
    PetKind.dragon =>
      '용의 합공 판마다 ${volleys(level)}번 · 돌 ${volleyWing(level) + 1}개 · 정면 박살',
  };
}
