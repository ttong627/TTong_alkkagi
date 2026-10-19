/// 대전장 지형·날씨 (설계서 §9.3·§9.4·§10.2). 앱과 서버가 같은 규칙으로 계산한다.
library;

import 'dart:math' as math;

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
  mine('지뢰석'),

  /// 담장(판 가장자리 바깥 · 2026-10-20 형 「경기장 바깥의 벽이나 담에 맞아서 다시 들어와서 공격」):
  /// 판 가장자리를 따라 선 벽 한 토막. 반발 0.75 — 맞은 돌이 판 안으로 되튀어 들어온다.
  fence('담장'),

  /// 바위: 판 가운데 띠의 큰 고정 돌(대전장 기본 장애물 · 2026-10-20). 반발 0.6.
  rock('바위'),

  /// 회전 기둥(2026-10-20 형 「다각형 기둥 … 회전한다던지 장소를 움직이면서 돌을 다시 쳐 내는데 여러 가지
  /// 랜덤 요소와 방향 강도를 다르게」): 돌이 움직이는 동안 돌고(·오가며) 맞은 돌을 엇나간 방향·세기로 쳐 낸다.
  pillar('회전 기둥');

  const FeatureKind(this.label);
  final String label;
}

/// 판 위 지물 하나. [angle] 은 나뭇가지 방향(라디안).
class Feature {
  const Feature(
    this.kind,
    this.x,
    this.y, {
    this.angle = 0,
    this.sides = 6,
    this.spin = 0,
    this.swing = 0,
    this.swingAngle = 0,
    this.swingRate = 0,
  });
  final FeatureKind kind;
  final double x;
  final double y;
  final double angle;

  /// 회전 기둥: 모서리 수(3~8) · 도는 빠르기(라디안/초) · 오가는 폭(cm)·방향(라디안)·빠르기(라디안/초).
  final int sides;
  final double spin;
  final double swing;
  final double swingAngle;
  final double swingRate;

  /// 회전 기둥의 [t] 초 때 자리와 각도(그 밖의 지물은 늘 제자리).
  (double, double, double) poseAt(double t) {
    if (kind != FeatureKind.pillar) return (x, y, angle);
    final d = swing * math.sin(swingRate * t);
    return (
      x + math.cos(swingAngle) * d,
      y + math.sin(swingAngle) * d,
      angle + spin * t,
    );
  }

  /// 크기(cm): 나뭇가지는 반 길이, 나머지는 반지름.
  double get size => switch (kind) {
    FeatureKind.branch => 3,
    FeatureKind.pebble => 0.45,
    FeatureKind.bamboo => 0.8,
    FeatureKind.gong => 1.5,
    FeatureKind.blackHole => 1.2,
    FeatureKind.mine => 1.1,
    FeatureKind.fence => TerrainConstants.fenceHalfLength,
    FeatureKind.rock => 1.5,
    FeatureKind.pillar => 1.7,
  };
}

/// 지형 수치.
abstract final class TerrainConstants {
  static const double branchHalfThickness = 0.2;
  static const double fenceHalfLength = 3;
  static const double fenceHalfThickness = 0.35;
  static const double fenceRestitution = 0.75;

  /// 회전 기둥에 맞은 돌: 방향이 ±[pillarKickAngle] 라디안 안에서, 세기가 [pillarKickMin]~[pillarKickMax] 배로 엇나간다.
  static const double pillarKickAngle = 0.6;
  static const double pillarKickMin = 0.85;
  static const double pillarKickMax = 1.4;
  static const double pillarRestitution = 0.7;
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
enum TerrainFx { gong, swallow, mine, frostStop, bamboo, fence, pillar }

class TerrainEvent {
  const TerrainEvent(this.fx, this.x, this.y);
  final TerrainFx fx;
  final double x;
  final double y;
}
