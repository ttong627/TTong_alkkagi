/// 설계서 v2 §3.1~§3.3 의 고정 값. 바꾸면 설계서 표도 같이 고친다.
abstract final class PhysicsConstants {
  /// 바둑판 한 변(cm). 19줄 × 약 2.2cm.
  static const double board = 42;

  /// 판 중심에서 가장자리까지(cm).
  static const double halfBoard = board / 2;

  /// 돌 반지름(cm).
  static const double stoneRadius = 1.1;

  /// 1스텝 시간(초). 1초에 60스텝.
  static const double step = 1 / 60;

  /// 이 속도(cm/s) 이하면 멈춘 것으로 본다.
  static const double restSpeed = 0.5;

  /// 한 수 최대 시간(초). 넘으면 모든 돌을 그 자리에 멈춘다.
  static const double maxTurnSeconds = 10;

  /// 한 수 최대 스텝 수.
  static const int maxTurnSteps = 600;

  /// 회전 보정 세기: 첫 충돌 직전 속도의 최대 50%.
  static const double spinStrength = 0.5;

  /// 회전이 1/e 로 줄어드는 시간(초).
  static const double spinDecaySeconds = 1.0;

  /// 감속 하한. 이보다 작은 감속은 쓰지 않는다(§3.2).
  static const double minDamping = 0.3;

  /// 쏘는 속도의 상한(cm/s). 탄지 파워 최대치(§2.3).
  static const double maxShotSpeed = 180;

  /// 돌끼리 마찰.
  static const double stoneFriction = 0.1;

  /// 돌이 제자리에서 도는 것을 줄이는 값.
  static const double angularDamping = 2.0;

  /// 중력 가속도(cm/s²). 떠서 날아가거나 튀어 오른 돌이 떨어지는 데 쓴다.
  static const double gravity = 981;

  /// 위·아래 타격점이 이 값을 넘으면 돌이 뜬다(아래 → 떠서 날아감, 위 → 바닥에 눌렸다 튀어 오름).
  /// 그 안쪽은 지금처럼 회전(밀어치기·끌어치기)만 준다.
  static const double liftThreshold = 0.5;

  /// 타격점 ±1 일 때 돌이 들리는 각도(도).
  static const double maxLiftDegrees = 35;

  /// 바닥 반발: 위를 맞아 바닥에 눌린 돌이 튀어 오르는 비율, 떨어진 돌이 다시 튀는 비율.
  static const double floorBounce = 0.4;

  /// 떨어질 때마다 남는 옆 빠르기 비율(바닥에 닿으며 잃는다).
  static const double landingKeep = 0.85;

  /// 이보다 느리게 떨어지면 더 튀지 않고 바닥에 붙는다(cm/s).
  static const double settleSpeed = 15;

  /// 돌 바닥이 이 높이(cm)보다 높이 떠 있으면 다른 돌 위를 넘어간다(부딪히지 않는다).
  static const double clearHeight = 0.6;

  /// 쏜 돌이 처음 부딪힌 순간 남는 빠르기 비율(맞은 돌이 받는 힘은 그대로).
  ///
  /// 2026-10-14 형 「반탄력이 너무 커서 내 공격에 내 돌이 죽고 있어」: 반발(청옥 0.85)로 쏜 돌이 옆·뒤로
  /// 튕겨 판 밖으로 나갔다(비껴 맞힐 때 · 무거운 돌을 맞힐 때). 회전으로 더 나가는 몫은 따로 더한다.
  /// `Table.settle` 이 켜진 게임 판에서만. [가정 — 실기기로 맞춘다]
  static const double shooterRecoilKeep = 0.45;
}
