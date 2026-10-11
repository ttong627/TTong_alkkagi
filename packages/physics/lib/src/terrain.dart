/// 대전장 지형·날씨 (설계서 §9.3·§9.4·§10.2). 앱과 서버가 같은 규칙으로 계산한다.
library;

/// 천기(天氣) — 맵 날씨.
enum Weather {
  clear('맑음', ''),

  /// 야우: 감속 −50%, 내 돌 둘레 10cm 만 보이고 표적은 실루엣(보이는 것은 화면이 그린다).
  nightRain('야우(밤비)', '감속 −50% · 내 돌 둘레만 보임'),

  /// 광풍: 5초마다 바람 방향이 바뀌며 움직이는 돌에 옆 힘.
  gale('광풍', '5초마다 바람 방향이 바뀜'),

  /// 혹한: 부딪힐 때마다 돌이 무거워져(빠르기 −10%) 세 번째 충돌에서 그 수에는 멈춤.
  frost('혹한', '부딪힐수록 무거워지고 세 번째에 멈춤');

  const Weather(this.label, this.help);
  final String label;
  final String help;
}

/// 판 위 지물·장애물.
enum FeatureKind {
  /// 나뭇가지(쿠비 산채): 가로놓인 막대. 반발 0.3.
  branch('나뭇가지'),

  /// 조약돌: 작은 고정 돌. 반발 0.5.
  pebble('조약돌'),

  /// 청죽: 부딪히면 반발 1.5배로 튕겨 냄(새총).
  bamboo('청죽'),

  /// 경종: 맞히면 반경 8cm 안의 상대 돌을 바깥으로 밀어냄.
  gong('경종'),

  /// 블랙홀(환생 세계): 둘레 6cm 의 돌을 빨아들이고 한가운데에 닿으면 장외.
  blackHole('블랙홀'),

  /// 지뢰석(환생 세계): 맞힌 돌은 폭발로 장외, 둘레 5cm 돌은 튕겨 나감. 한 번 터지면 사라짐.
  mine('지뢰석');

  const FeatureKind(this.label);
  final String label;
}

/// 판 위 지물 하나. [angle] 은 나뭇가지 방향(라디안).
class Feature {
  const Feature(this.kind, this.x, this.y, {this.angle = 0});
  final FeatureKind kind;
  final double x;
  final double y;
  final double angle;

  /// 크기(cm): 나뭇가지는 반 길이, 나머지는 반지름.
  double get size => switch (kind) {
    FeatureKind.branch => 3,
    FeatureKind.pebble => 0.45,
    FeatureKind.bamboo => 0.8,
    FeatureKind.gong => 1.5,
    FeatureKind.blackHole => 1.2,
    FeatureKind.mine => 1.1,
  };
}

/// 지형 수치.
abstract final class TerrainConstants {
  static const double branchHalfThickness = 0.2;
  static const double bambooRestitution = 1.5;
  static const double gongRadius = 8;
  static const double gongPush = 20;
  static const double holePull = 80;
  static const double holeRadius = 6;
  static const double holeSwallow = 0.8;
  static const double mineRadius = 5;
  static const double minePush = 60;

  /// 광풍: 바람 가속(cm/s²)과 방향이 바뀌는 간격(스텝).
  static const double galeAccel = 12;
  static const int galeSteps = 300;

  /// 혹한: 충돌마다 빠르기 배수, 몇 번째 충돌에 멈추나.
  static const double frostSlow = 0.9;
  static const int frostStopAt = 3;
}

/// 지형이 일으킨 일(연출용).
enum TerrainFx { gong, swallow, mine, frostStop, bamboo }

class TerrainEvent {
  const TerrainEvent(this.fx, this.x, this.y);
  final TerrainFx fx;
  final double x;
  final double y;
}
