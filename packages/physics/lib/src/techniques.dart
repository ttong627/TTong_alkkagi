/// 무공·스킬 (설계서 v2 §2.4·§2.6·§3.9). 앱과 서버가 같은 규칙으로 계산한다.
///
/// 문파 무공 4종은 **내공 타격**(내공 1 사용) 때만 발동하고, 스킬(흡성탄지)은 내공 2를 쓴다.
/// 수치는 설계서 초안 값이고, 없는 값은 [가정] 으로 정했다.
enum Technique {
  /// 무공 없이 치기.
  none('없음', cost: 0),

  /// 검객 — 검기: 첫 충돌 뒤 1.0초 동안 내 돌 감속 −40%, 일직선으로 밀고 나감.
  swordQi('검기', cost: 1),

  /// 권사 — 진각: 첫 충돌 지점 반경 4cm 안의 다른 돌을 바깥으로 +15cm/s.
  stomp('진각', cost: 1),

  /// 도사 — 태극: 첫 충돌 전까지 궤적이 휜다(휘는 힘 0.3 × 빠르기).
  taiji('태극', cost: 1),

  /// 살수 — 분신: 한 수에 상대 돌 2개 이상 맞히면 내 돌이 둘로 나뉨(판당 1회, 나뉜 돌 속도 60%).
  clone('분신', cost: 1),

  /// 기명석 스킬 — 흡성탄지: 첫 충돌 순간 반경 6cm 안의 돌을 0.5초 끌어당김.
  absorb('흡성탄지', cost: 2);

  const Technique(this.label, {required this.cost});
  final String label;

  /// 쓰는 내공(칸).
  final int cost;
}

/// 무공·스킬·내공 타격 수치.
abstract final class TechniqueConstants {
  /// 내공 타격: 처음 속도 배수(상한은 [PhysicsConstants.maxShotSpeed]).
  static const double innerSpeed = 1.3;

  /// 내공 타격: 첫 충돌로 맞은 돌의 빠르기 배수. [가정]
  static const double innerImpact = 1.25;

  /// 검기: 감속 배수와 이어지는 스텝 수(1.0초).
  static const double swordQiDamping = 0.6;
  static const int swordQiSteps = 60;

  /// 진각: 반경(cm)과 바깥으로 더하는 빠르기(cm/s).
  static const double stompRadius = 4;
  static const double stompPush = 15;

  /// 태극: 휘는 힘(빠르기 1cm/s 당 옆 가속 cm/s²).
  static const double taijiCurl = 0.3;

  /// 분신: 나뉜 돌 속도 비율과 갈라지는 각도(도). 각도는 [가정].
  static const double cloneSpeed = 0.6;
  static const double cloneDegrees = 25;

  /// 흡성탄지: 반경(cm)·시간(스텝)·끌어당기는 가속(cm/s²). 가속은 [가정].
  static const double absorbRadius = 6;
  static const int absorbSteps = 30;
  static const double absorbPull = 60;
}

/// 한 스텝 안에서 일어난 충돌 하나(연출용).
class Impact {
  const Impact(this.a, this.b, this.x, this.y, this.speed);
  final int a;
  final int b;
  final double x;
  final double y;

  /// 부딪힐 때 다가온 빠르기(cm/s).
  final double speed;
}

/// 무공·스킬이 발동한 순간(연출용).
enum TechniqueFx { innerImpact, swordQi, stomp, clone, absorb }

class TechniqueEvent {
  const TechniqueEvent(this.fx, this.x, this.y, {this.stoneId});
  final TechniqueFx fx;
  final double x;
  final double y;
  final int? stoneId;
}
