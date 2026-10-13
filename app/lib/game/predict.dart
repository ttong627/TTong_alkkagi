import 'dart:ui';

import 'package:alkkagi_physics/alkkagi_physics.dart';

import 'match.dart';

/// 예상 궤적(설계서 §7.1): 지금 판 그대로 [stone] 을 쳤을 때 그 돌이 갈 길(판 좌표).
///
/// [assist] 2 = 두 번째 충돌 뒤 반사각까지, 1 = 첫 충돌까지, 0.5 = 첫 충돌까지 길이의 절반, 0 = 없음.
/// 화면에 그리기만 한다(판정에는 안 쓴다). 길이가 최대 3초.
List<Offset> predictPath(
  Match match,
  Stone stone,
  double angle,
  double speed, {
  double? assist,
}) {
  final a = assist ?? match.config.aimAssist;
  if (a <= 0) return const [];
  // 지금 바닥(야우 감속·6장 불꽃 바닥이 들어간 값)과 지물을 그대로. 혹한은 같이 계산하고,
  // 광풍은 바람이 어디로 불지 알려 주지 않는다(바람 없을 때의 길).
  final t = Table(
    floorFactor: match.table.floorFactor,
    boundary: match.config.arena.boundary,
    weather: match.config.weather == Weather.frost
        ? Weather.frost
        : Weather.clear,
    settle: match.table.settle,
    half: match.table.half,
  );
  for (final f in match.table.features) {
    t.addFeature(f);
  }
  Stone? me;
  for (final s in match.table.stones) {
    if (s.out) continue;
    final c = t.addStone(
      s.position.x,
      s.position.y,
      material: s.material,
      shape: s.shape,
      team: s.team,
    );
    if (identical(s, stone)) me = c;
  }
  final path = <Offset>[];
  if (me == null) {
    t.dispose();
    return path;
  }
  path.add(Offset(me.position.x, me.position.y));
  t.shoot(me, angle, speed, 0);
  var hits = 0;
  var after = 0;
  for (var i = 0; i < 180; i++) {
    if (t.step() != TurnStatus.moving) break;
    path.add(Offset(me.position.x, me.position.y));
    if (me.out) break;
    if (t.impacts.any((x) => x.a == me!.id || x.b == me.id)) hits++;
    if (a >= 2) {
      if (hits >= 2 && ++after > 24) break;
    } else if (hits >= 1) {
      break;
    }
  }
  t.dispose();
  if (a > 0 && a < 1 && path.length > 2) {
    return path.sublist(0, (path.length * a).ceil());
  }
  return path;
}
