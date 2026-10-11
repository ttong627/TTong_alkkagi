// 트릭샷 판 만들기(설계서 §16.15 · 형 지시 2026-10-11 「묘수·트릭샷 판 대량 확장」).
//
// 정해진 씨앗으로 판(내 돌·표적·백성 돌·지물)을 뽑고, 가상 시험으로
//  ① 손으로 칠 수 있는 수(처음 속도 30~120cm/s · 가운데 타격)로 풀리는지,
//  ② 너무 쉽지 않은지(첫 수 후보 가운데 바로 끝나는 비율이 낮은지),
//  ③ 백성 돌을 건드리지 않고 풀 수 있는지
// 확인한 것만 남긴다. 결과:
//  - lib/story/trickshots.dart      판 60개(손으로 고치지 말 것 — 다시 만들면 덮어씀)
//  - test/trickshot_solutions.dart   찾은 풀이(test/trickshot_test.dart 가 매번 다시 확인)
//
// 실행: flutter test tool/trickshot_gen.dart   (몇 분 걸림)
import 'dart:io';
import 'dart:math' as math;

import 'package:alkkagi/game/arena.dart';
import 'package:alkkagi/game/match.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Shot = ({double angle, double speed});

/// 판 하나의 뼈대.
class Spec {
  Spec({
    required this.tier,
    required this.index,
    required this.arena,
    required this.shots,
    required this.targets,
    this.civilians = 0,
    this.pebbles = 0,
    this.branches = 0,
    this.bamboos = 0,
    this.gongs = 0,
    this.mines = 0,
    this.maxEasy = 0.12,
  });
  final int tier;
  final int index;
  final Arena arena;
  final int shots;
  final int targets;
  final int civilians;
  final int pebbles;
  final int branches;
  final int bamboos;
  final int gongs;
  final int mines;

  /// 첫 수 후보 가운데 바로 다 끝나는 비율의 상한(넘으면 너무 쉬움).
  final double maxEasy;

  int get id => 1000 + tier * 10 + index;
}

const tierNames = ['첫걸음', '기름진 원탁', '장터 골목', '청죽 숲길', '경종과 지뢰', '빙판 결전'];

List<Spec> specs() {
  final out = <Spec>[];
  for (var k = 0; k < 10; k++) {
    out.add(
      Spec(
        tier: 0,
        index: k,
        arena: Arena.dustyYard,
        shots: k < 6 ? 1 : 2,
        targets: 1 + k ~/ 3,
        // 첫 묶음은 손에 익히는 판 — 쉬운 편이어도 된다.
        maxEasy: k < 3 ? 0.35 : (k < 6 ? 0.2 : 0.12),
      ),
    );
  }
  for (var k = 0; k < 10; k++) {
    out.add(
      Spec(
        tier: 1,
        index: k,
        arena: Arena.oilyTable,
        shots: k < 4 ? 1 : 2,
        targets: 2 + k ~/ 4,
        civilians: k >= 5 ? 1 + (k - 5) ~/ 3 : 0,
      ),
    );
  }
  for (var k = 0; k < 10; k++) {
    out.add(
      Spec(
        tier: 2,
        index: k,
        arena: Arena.turtleMarket,
        shots: k < 3 ? 1 : 2,
        targets: 2 + k ~/ 3,
        pebbles: 2 + k ~/ 3,
        branches: k >= 4 ? 1 + (k - 4) ~/ 3 : 0,
        civilians: k >= 7 ? 1 : 0,
      ),
    );
  }
  for (var k = 0; k < 10; k++) {
    out.add(
      Spec(
        tier: 3,
        index: k,
        arena: Arena.kubiForest,
        shots: k < 5 ? 1 : 2,
        targets: 1 + k ~/ 3,
        bamboos: 1 + k ~/ 4,
        branches: 1 + k ~/ 5,
        maxEasy: 0.08,
      ),
    );
  }
  for (var k = 0; k < 10; k++) {
    out.add(
      Spec(
        tier: 4,
        index: k,
        arena: Arena.logicMarble,
        shots: k < 5 ? 1 : 2,
        targets: 3 + k ~/ 3,
        gongs: k.isEven ? 1 : 0,
        mines: k.isOdd ? 1 : (k >= 6 ? 1 : 0),
        civilians: k >= 8 ? 1 : 0,
      ),
    );
  }
  for (var k = 0; k < 10; k++) {
    out.add(
      Spec(
        tier: 5,
        index: k,
        arena: Arena.murimIce,
        shots: k < 4 ? 2 : 3,
        targets: 3 + k ~/ 3,
        civilians: 1 + k ~/ 4,
        pebbles: k >= 3 ? 1 : 0,
        bamboos: k >= 6 ? 1 : 0,
        maxEasy: 0.06,
      ),
    );
  }
  return out;
}

/// 뽑은 판.
class Layout {
  Layout(this.me, this.targets, this.civilians, this.features);
  final Placement me;
  final List<Placement> targets;
  final List<Placement> civilians;
  final List<Feature> features;
}

double r2(double v) => (v * 100).roundToDouble() / 100;

Layout? draw(Spec s, math.Random rand) {
  final b = s.arena.boundary;
  final taken = <(double, double, double)>[]; // x, y, 반지름
  bool free(double x, double y, double r, double edge) {
    if (b.edgeDistance(x, y) < edge) return false;
    for (final (tx, ty, tr) in taken) {
      final d = math.sqrt((x - tx) * (x - tx) + (y - ty) * (y - ty));
      if (d < r + tr + 0.35) return false;
    }
    return true;
  }

  (double, double)? spot(
    double x0,
    double x1,
    double y0,
    double y1,
    double r,
    double edge,
  ) {
    for (var i = 0; i < 200; i++) {
      final x = r2(x0 + rand.nextDouble() * (x1 - x0));
      final y = r2(y0 + rand.nextDouble() * (y1 - y0));
      if (free(x, y, r, edge)) {
        taken.add((x, y, r));
        return (x, y);
      }
    }
    return null;
  }

  const sr = PhysicsConstants.stoneRadius;
  final me = spot(-8, 8, 9, 15, sr, 4);
  if (me == null) return null;
  // 표적: 무리(가운데 하나 둘레) 또는 흩어짐.
  final targets = <Placement>[];
  final cluster = rand.nextDouble() < 0.6;
  final (cx, cy) = (-12 + rand.nextDouble() * 24, -16 + rand.nextDouble() * 14);
  for (var i = 0; i < s.targets; i++) {
    final p = cluster
        ? spot(cx - 5, cx + 5, cy - 4, cy + 4, sr, 1.6)
        : spot(-18, 18, -19, 4, sr, 1.6);
    if (p == null) return null;
    targets.add(Placement(p.$1, p.$2));
  }
  final civ = <Placement>[];
  for (var i = 0; i < s.civilians; i++) {
    final p = spot(-16, 16, -17, 6, sr, 2.5);
    if (p == null) return null;
    civ.add(Placement(p.$1, p.$2, team: 2));
  }
  final feats = <Feature>[];
  void add(FeatureKind k, int n, double y0, double y1) {
    for (var i = 0; i < n; i++) {
      final f = Feature(k, 0, 0);
      final p = spot(-15, 15, y0, y1, f.size + 0.3, 2.5);
      if (p == null) continue;
      feats.add(
        Feature(
          k,
          p.$1,
          p.$2,
          angle: k == FeatureKind.branch ? r2(rand.nextDouble() * math.pi) : 0,
        ),
      );
    }
  }

  add(FeatureKind.pebble, s.pebbles, -14, 7);
  add(FeatureKind.branch, s.branches, -10, 6);
  add(FeatureKind.bamboo, s.bamboos, -16, 8);
  add(FeatureKind.gong, s.gongs, cy - 3, cy + 3);
  add(FeatureKind.mine, s.mines, cy - 4, cy + 4);
  return Layout(Placement(me.$1, me.$2, team: 0), targets, civ, feats);
}

/// 한 판의 지금 상태(내 돌 위치·남은 표적·백성 돌).
class State {
  State(this.me, this.targets, this.civilians);
  final Placement me;
  final List<Placement> targets;
  final List<Placement> civilians;
}

/// 앱의 [Match] 와 같은 순서(지물 → 백성 돌 → 내 돌 → 표적)로 판을 만들고 한 번 친다.
/// (떨어진 표적 수, 백성 돌을 떨어뜨렸나, 내 돌이 남았나, 다음 상태).
(int, bool, bool, State) trial(
  Spec s,
  List<Feature> feats,
  State st,
  Shot shot,
) {
  final t = Table(floorFactor: s.arena.floorFactor, boundary: s.arena.boundary);
  for (final f in feats) {
    t.addFeature(f);
  }
  for (final c in st.civilians) {
    t.addStone(c.x, c.y, team: 2);
  }
  final me = t.addStone(st.me.x, st.me.y);
  final ts = [for (final p in st.targets) t.addStone(p.x, p.y, team: 1)];
  t.shoot(me, shot.angle, shot.speed, 0);
  t.runTurn();
  final knocked = ts.where((x) => x.out).length;
  final civLost = t.stones.any((x) => x.team == 2 && x.out);
  final next = State(
    Placement(me.position.x, me.position.y, team: 0),
    [
      for (final x in ts)
        if (!x.out) Placement(x.position.x, x.position.y),
    ],
    [
      for (final x in t.stones)
        if (x.team == 2 && !x.out)
          Placement(x.position.x, x.position.y, team: 2),
    ],
  );
  final mine = !me.out;
  t.dispose();
  return (knocked, civLost, mine, next);
}

List<Shot> candidates(
  State st,
  List<Feature> feats, {
  double step = 0.5,
  double speedStep = 10,
}) {
  final me = st.me;
  final aims = <(double, double)>[
    for (final p in st.targets) (p.x, p.y),
    for (final f in feats)
      if (f.kind != FeatureKind.pebble && f.kind != FeatureKind.branch)
        (f.x, f.y),
  ];
  final out = <Shot>[];
  for (final (x, y) in aims) {
    final base = math.atan2(y - me.y, x - me.x);
    for (var d = -10.0; d <= 10.0; d += step) {
      for (var sp = 30.0; sp <= 120; sp += speedStep) {
        out.add((angle: base + d * math.pi / 180, speed: sp));
      }
    }
  }
  return out;
}

/// 깊이 우선(많이 떨어뜨리는 수부터, 단계마다 [beam] 갈래).
List<Shot>? solve(Spec s, List<Feature> feats, State st, int left) {
  final scored = <(int, Shot, State)>[];
  for (final c in candidates(st, feats, step: left == s.shots ? 0.5 : 1)) {
    final (k, civ, mine, next) = trial(s, feats, st, c);
    if (civ) continue;
    if (k >= st.targets.length) return [c];
    if (left > 1 && mine && k > 0) scored.add((k, c, next));
  }
  if (left <= 1) return null;
  scored.sort((a, b) => b.$1.compareTo(a.$1));
  final beam = left >= 3 ? 6 : 12;
  for (final (_, c, next) in scored.take(beam)) {
    final rest = solve(s, feats, next, left - 1);
    if (rest != null) return [c, ...rest];
  }
  return null;
}

/// 첫 수 후보 가운데 한 번에 다 끝나는(백성 돌 무사) 비율.
double easiness(Spec s, Layout l) {
  final st = State(l.me, l.targets, l.civilians);
  // 거친 표본(2° · 15cm/s)으로 어림한다 — 판을 많이 버리므로 빨라야 한다.
  final cs = candidates(st, l.features, step: 2, speedStep: 15);
  var win = 0;
  for (final c in cs) {
    final (k, civ, _, _) = trial(s, l.features, st, c);
    if (!civ && k >= l.targets.length) win++;
  }
  return cs.isEmpty ? 1 : win / cs.length;
}

String placement(Placement p) => p.team == 0
    ? 'Placement(${p.x}, ${p.y}, team: 0)'
    : (p.team == 2
          ? 'Placement(${p.x}, ${p.y}, team: 2)'
          : 'Placement(${p.x}, ${p.y})');

String feature(Feature f) =>
    'Feature(FeatureKind.${f.kind.name}, ${f.x}, ${f.y}${f.kind == FeatureKind.branch ? ', angle: ${f.angle}' : ''})';

String helpOf(Spec s, Layout l) {
  final bits = <String>['표적 ${l.targets.length}', '${s.shots}수'];
  if (l.civilians.isNotEmpty) bits.add('백성 돌 조심');
  final kinds = {for (final f in l.features) f.kind};
  if (kinds.contains(FeatureKind.bamboo)) bits.add('청죽으로 튕겨');
  if (kinds.contains(FeatureKind.gong)) bits.add('경종을 울려');
  if (kinds.contains(FeatureKind.mine)) bits.add('지뢰석을 터뜨려');
  return bits.join(' · ');
}

int secondsOf(Spec s, Layout l) => 12 + 10 * s.shots + 2 * l.targets.length;

/// 찾은 풀이를 앱과 똑같은 [Match] 한 판으로 처음부터 다시 쳐서 이기는지(백성 돌 무사) 본다.
bool replays(Spec s, Layout l, List<Shot> sol) {
  final m = Match(
    MatchConfig(
      mode: MatchMode.practice,
      arena: s.arena,
      layout: [l.me, ...l.targets],
      civilians: l.civilians,
      features: l.features,
      shotLimit: s.shots,
    ),
  );
  for (final x in sol) {
    if (m.isOver) break;
    final me = m.table.stones.firstWhere((t) => t.team == 0);
    m.shoot(me, x.angle, x.speed, 0);
    var guard = 0;
    while (m.isMoving && guard++ < 5000) {
      m.step();
    }
  }
  final ok = m.winner == 0 && m.civiliansLost == 0;
  m.dispose();
  return ok;
}

/// 판 하나의 lib 항목 글.
String entryOf(Spec s, Layout l) {
  final b = StringBuffer()
    ..writeln('  Puzzle(')
    ..writeln('    id: ${s.id},')
    ..writeln("    title: '${tierNames[s.tier]} ${s.index + 1}',")
    ..writeln("    help: '${helpOf(s, l)}',")
    ..writeln('    shots: ${s.shots},')
    ..writeln('    reward: ${10 + 5 * s.tier},')
    ..writeln('    arena: Arena.${s.arena.name},')
    ..writeln('    seconds: ${secondsOf(s, l)},')
    ..writeln(
      '    layout: [${[placement(l.me), ...l.targets.map(placement)].join(', ')}],',
    );
  if (l.civilians.isNotEmpty) {
    b.writeln('    civilians: [${l.civilians.map(placement).join(', ')}],');
  }
  if (l.features.isNotEmpty) {
    b.writeln('    features: [${l.features.map(feature).join(', ')}],');
  }
  b.write('  ),');
  return b.toString();
}

/// 판마다 따로 찾아 build/trick/ 에 적어 둔다(이미 있으면 건너뜀 — 여러 묶음을 나란히 돌릴 수 있다).
///  - TIERS=0,1  그 묶음만 찾는다 · MERGE=1  모아서 lib·test 를 쓴다(둘 다 없으면 찾고 나서 모음).
void main() {
  setUpAll(initializePhysics);
  final env = Platform.environment;
  final tiers = env['TIERS']?.split(',').map(int.parse).toSet();
  final mergeOnly = env['MERGE'] == '1';
  final dir = Directory('build/trick')..createSync(recursive: true);

  test('트릭샷 판 만들기', () {
    final clock = Stopwatch()..start();
    if (!mergeOnly) {
      for (final s in specs()) {
        if (tiers != null && !tiers.contains(s.tier)) continue;
        final entry = File('${dir.path}/${s.id}.entry');
        final solFile = File('${dir.path}/${s.id}.sol');
        if (entry.existsSync() && solFile.existsSync()) continue;
        final rand = math.Random(s.id * 7919);
        var tries = 0;
        while (true) {
          tries++;
          if (tries > 5000) throw StateError('${s.id}: 판을 못 찾음');
          final l = draw(s, rand);
          if (l == null) continue;
          final easy = easiness(s, l);
          if (easy > s.maxEasy) continue;
          if (s.shots == 1 && easy == 0) continue;
          final sol = solve(
            s,
            l.features,
            State(l.me, l.targets, l.civilians),
            s.shots,
          );
          if (sol == null || !replays(s, l, sol)) continue;
          entry.writeAsStringSync(entryOf(s, l));
          solFile.writeAsStringSync(
            '  ${s.id}: [${sol.map((x) => '(${x.angle}, ${x.speed})').join(', ')}],',
          );
          // ignore: avoid_print
          print(
            '${s.id} ${tierNames[s.tier]} ${s.index + 1}: 시도 $tries · 쉬움 ${(easy * 100).toStringAsFixed(1)}% · 풀이 ${sol.length}수 · ${clock.elapsed.inSeconds}초',
          );
          break;
        }
      }
      if (tiers != null) return;
    }
    final lib = StringBuffer()
      ..writeln('// 생성됨: tool/trickshot_gen.dart — 손으로 고치지 말 것(다시 만들면 덮어씀).')
      ..writeln(
        '// 판마다 가상 시험으로 풀리고 너무 쉽지 않음을 확인했다(test/trickshot_test.dart 가 매번 다시 확인).',
      )
      ..writeln("import 'package:alkkagi_physics/alkkagi_physics.dart';")
      ..writeln()
      ..writeln("import '../game/arena.dart';")
      ..writeln("import '../game/match.dart';")
      ..writeln("import 'puzzles.dart';")
      ..writeln()
      ..writeln('/// 트릭샷 묶음 이름(6묶음 × 10판).')
      ..writeln(
        'const trickTierNames = [${tierNames.map((n) => "'$n'").join(', ')}];',
      )
      ..writeln()
      ..writeln('/// 트릭샷 판 60개(id = 1000 + 묶음 × 10 + 번호).')
      ..writeln('const trickshots = <Puzzle>[');
    final sols = StringBuffer()
      ..writeln(
        '// 생성됨: tool/trickshot_gen.dart — 판마다 찾은 풀이(각도 라디안, 처음 속도 cm/s).',
      )
      ..writeln('const trickSolutions = <int, List<(double, double)>>{');
    for (final s in specs()) {
      lib.writeln(File('${dir.path}/${s.id}.entry').readAsStringSync());
      sols.writeln(File('${dir.path}/${s.id}.sol').readAsStringSync());
    }
    lib.writeln('];');
    sols.writeln('};');
    File('lib/story/trickshots.dart').writeAsStringSync(lib.toString());
    File('test/trickshot_solutions.dart').writeAsStringSync(sols.toString());
  }, timeout: const Timeout(Duration(hours: 3)));
}
