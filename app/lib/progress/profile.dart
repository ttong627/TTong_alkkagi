import 'dart:convert';
import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart';

/// 캐릭터 10종 (설계서 §2.2·§16.3).
enum Fighter {
  seokdu('석두', '근력형 · 탄지 파워 +10%', starter: true),
  yeonbi('연비', '유연형 · 탄지 묘수 +0.1', starter: true),
  cheongmyeong('청명', '집중형 · 어기 +0.3초 · 판 시작 내공 +1칸', starter: true),
  banDal('반달', '통통의 제자 · 맞은 돌 +10%'),
  gurumi('구르미', '쿠비의 제자 · 회전 ×1.15'),
  jeonggak('정각', '로직의 제자 · 회심 폭 0.2'),
  yonga('용아', '맹주의 제자 · 내공 타격 ×1.35'),
  seolhwa('설화', '비무장 시즌 보상(온라인판)'),
  chwiseon('취선', '은둔 고수 · 회심 때 20% 로 내공 +2'),
  mukgaek('묵객', '은둔 고수 · 장외시키면 내공 +1(판당 2번)');

  const Fighter(this.label, this.trait, {this.starter = false});
  final String label;
  final String trait;
  final bool starter;
}

/// 능력치 3종 (설계서 §2.3·§16.4). 0~20 단계.
enum Stat {
  power('탄지 파워', '최대 처음 속도 120 → 180cm/s'),
  finesse('탄지 묘수', '회전 효율 ×1.0 → ×1.3'),
  control('어기 정밀도', '어기어석 느린 화면 1.5 → 3.0초');

  const Stat(this.label, this.help);
  final String label;
  final String help;
}

/// 내공 단계 8단계 (설계서 §16.2).
const naegongStages = [
  ('삼류', 0.0),
  ('이류', 100.0),
  ('일류', 300.0),
  ('절정', 600.0),
  ('초절정', 1000.0),
  ('화경', 1600.0),
  ('현경', 2400.0),
  ('생사경', 3500.0),
];

/// 쌓인 내공 → 단계(1~8).
int stageOf(double naegong) {
  var s = 1;
  for (var i = 0; i < naegongStages.length; i++) {
    if (naegong >= naegongStages[i].$2) s = i + 1;
  }
  return s;
}

/// 목인항 하루 수련 (설계서 §5.2): 처음 30타는 3배(깨달음), 31타부터 0.1배.
abstract final class Training {
  static const int enlightened = 30;
  static const double bonus = 3;
  static const double after = 0.1;

  /// 그날 [hitsBefore] 타를 친 뒤 한 번 더 쳤을 때 얻는 내공.
  static double gain(int hitsBefore) =>
      hitsBefore < enlightened ? bonus : after;

  /// 하루 [hits] 타의 내공 합.
  static double dayTotal(int hits) =>
      math.min(hits, enlightened) * bonus +
      math.max(0, hits - enlightened) * after;
}

/// 만물상 (설계서 §6.2A·§16.4) 가격(엽전).
const materialPrices = {
  StoneMaterial.cheongok: 0,
  StoneMaterial.wood: 300,
  StoneMaterial.hyeoncheol: 600,
  StoneMaterial.ice: 900,
};
const shapePrices = {
  StoneShape.flat: 0,
  StoneShape.round: 200,
  StoneShape.sphere: 500,
};

/// 능력치 단계 n → n+1 비용(수련 포인트).
int statCost(int level) => 10 * (level + 1);
const int maxStatLevel = 20;

/// 기기에 저장하는 진행 상태(오프라인판). 온라인판에서는 서버로 옮긴다(체크리스트 3-11).
class Profile {
  Profile();

  Fighter? hero;

  /// 문파 무공. 1장을 깨면 각성해 정한다(그 전엔 null).
  Technique? school;

  /// 깬 강호행 판(장·숙적전 id).
  final done = <String>{};
  final heroes = <Fighter>{};
  double naegong = 0;
  double trainingPoints = 0;
  String trainingDay = '';
  int trainingHits = 0;
  final stats = {for (final s in Stat.values) s: 0};
  int coins = 0;
  int silver = 0;
  final materials = <StoneMaterial>{StoneMaterial.cheongok};
  final shapes = <StoneShape>{StoneShape.flat};
  StoneMaterial material = StoneMaterial.cheongok;
  StoneShape shape = StoneShape.flat;

  /// 도감: 만난 고수·얻은 것 (설계서 §8.7).
  final codex = <String>{};

  int get stage => stageOf(naegong);
  String get stageName => naegongStages[stage - 1].$1;

  /// 다음 단계까지 남은 내공(마지막 단계면 null).
  double? get toNextStage =>
      stage >= naegongStages.length ? null : naegongStages[stage].$2 - naegong;

  // --- 능력치 값 ---
  /// 능력치 단계 + 도감 세트 보너스(최대 20).
  int level(Stat s) => math.min(maxStatLevel, stats[s]! + codexBonus);

  double get maxSpeed =>
      (120 + 3 * level(Stat.power)) * (hero == Fighter.seokdu ? 1.1 : 1);
  double get spinScale =>
      (1 + 0.015 * level(Stat.finesse)) +
      (hero == Fighter.yeonbi ? 0.1 : 0) +
      (hero == Fighter.gurumi ? 0.15 : 0);
  double get steerSeconds =>
      1.5 +
      0.075 * level(Stat.control) +
      (hero == Fighter.cheongmyeong ? 0.3 : 0);

  /// 판 시작 내공 칸: 화경(6단계)부터 1칸, 청명 +1.
  int get startQi =>
      (stage >= 6 ? 1 : 0) + (hero == Fighter.cheongmyeong ? 1 : 0);

  /// 어기어석 꺾기 횟수(설계서 §3.7·§16.2).
  int get steers => stage >= 7 ? 3 : (stage >= 5 ? 2 : 1);

  /// 도감 세트 보너스: 재질 4종을 모두 모으면 능력치 3종 +1, 모양 3종 모두 +1 (설계서 §8.7).
  int get codexBonus =>
      (materials.length == StoneMaterial.values.length ? 1 : 0) +
      (shapes.length == StoneShape.values.length ? 1 : 0);

  // --- 목인항 ---
  /// 오늘([day] = yyyymmdd) 한 타. 얻은 내공을 돌려준다. 날이 바뀌면 처음부터 센다.
  double trainHit(String day) {
    if (trainingDay != day) {
      trainingDay = day;
      trainingHits = 0;
    }
    final g = Training.gain(trainingHits);
    trainingHits++;
    naegong += g;
    trainingPoints += g;
    return g;
  }

  // --- 능력치 올리기 ---
  bool canRaise(Stat s) =>
      stats[s]! < maxStatLevel && trainingPoints >= statCost(stats[s]!);

  bool raise(Stat s) {
    if (!canRaise(s)) return false;
    trainingPoints -= statCost(stats[s]!);
    stats[s] = stats[s]! + 1;
    return true;
  }

  // --- 만물상 ---
  bool buyMaterial(StoneMaterial m) {
    final p = materialPrices[m]!;
    if (materials.contains(m) || coins < p) return false;
    coins -= p;
    materials.add(m);
    codex.add('재질:${m.name}');
    return true;
  }

  bool buyShape(StoneShape s) {
    final p = shapePrices[s]!;
    if (shapes.contains(s) || coins < p) return false;
    coins -= p;
    shapes.add(s);
    codex.add('모양:${s.name}');
    return true;
  }

  // --- 저장 ---
  Map<String, Object?> toJson() => {
    'v': 1,
    'hero': hero?.name,
    'school': school?.name,
    'done': done.toList(),
    'heroes': heroes.map((h) => h.name).toList(),
    'naegong': naegong,
    'tp': trainingPoints,
    'tday': trainingDay,
    'thits': trainingHits,
    'stats': {for (final e in stats.entries) e.key.name: e.value},
    'coins': coins,
    'silver': silver,
    'materials': materials.map((m) => m.name).toList(),
    'shapes': shapes.map((s) => s.name).toList(),
    'material': material.name,
    'shape': shape.name,
    'codex': codex.toList(),
  };

  static T? _byName<T extends Enum>(List<T> values, Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  factory Profile.fromJson(Map<String, Object?> j) {
    final p = Profile();
    p.hero = _byName(Fighter.values, j['hero']);
    p.school = _byName(Technique.values, j['school']);
    p.done.addAll((j['done'] as List? ?? []).cast<String>());
    for (final h in (j['heroes'] as List? ?? [])) {
      final v = _byName(Fighter.values, h);
      if (v != null) p.heroes.add(v);
    }
    p.naegong = (j['naegong'] as num? ?? 0).toDouble();
    p.trainingPoints = (j['tp'] as num? ?? 0).toDouble();
    p.trainingDay = j['tday'] as String? ?? '';
    p.trainingHits = j['thits'] as int? ?? 0;
    final st = j['stats'] as Map? ?? {};
    for (final s in Stat.values) {
      p.stats[s] = (st[s.name] as int? ?? 0).clamp(0, maxStatLevel);
    }
    p.coins = j['coins'] as int? ?? 0;
    p.silver = j['silver'] as int? ?? 0;
    for (final m in (j['materials'] as List? ?? [])) {
      final v = _byName(StoneMaterial.values, m);
      if (v != null) p.materials.add(v);
    }
    for (final m in (j['shapes'] as List? ?? [])) {
      final v = _byName(StoneShape.values, m);
      if (v != null) p.shapes.add(v);
    }
    final mat = _byName(StoneMaterial.values, j['material']);
    if (mat != null && p.materials.contains(mat)) p.material = mat;
    final sh = _byName(StoneShape.values, j['shape']);
    if (sh != null && p.shapes.contains(sh)) p.shape = sh;
    p.codex.addAll((j['codex'] as List? ?? []).cast<String>());
    return p;
  }

  String encode() => jsonEncode(toJson());
  static Profile decode(String s) =>
      Profile.fromJson((jsonDecode(s) as Map).cast<String, Object?>());
}

/// 오늘 날짜(기기 시간, yyyymmdd). 온라인판에서는 서버 시간을 쓴다(설계서 §11.4).
String today([DateTime? now]) {
  final d = now ?? DateTime.now();
  return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}
