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
}
