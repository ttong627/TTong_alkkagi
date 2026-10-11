import 'dart:math' as math;

import 'package:alkkagi_physics/alkkagi_physics.dart';

import 'profile.dart';

/// 기연 (설계서 §5.3): 「1판」(강호행 1회·대전 1회·목인항 30타 묶음·강호유랑 1칸)이 끝날 때마다 뽑는다.
enum Encounter {
  /// 영약(천년설삼): 내공 +100 영구.
  elixir('영약 · 천년설삼', 0.001),

  /// 은둔 고수: 묘수풀이(한 번에 돌 3개 떨어뜨리기)를 하면 희귀 비급.
  hermit('은둔 고수', 0.002),

  /// 기인방: 10분 동안만 열리는 전설 상점.
  legendary('기인방', 0.005);

  const Encounter(this.label, this.chance);
  final String label;

  /// 판당 확률.
  final double chance;
}

/// 기인방 특수효과 5종, 각 20% (설계서 §6.2C). 사기 전에 붙은 효과가 다 보인다.
const legendaryPerks = ['불꽃 궤적', '내공 아낌', '꺾기+1', '첫 충돌 반발+5%', '장외 시 기'];

String perkHelp(String perk) => switch (perk) {
  '불꽃 궤적' => '내 돌 잔상이 불꽃빛',
  '내공 아낌' => '내공을 쓸 때 10% 로 1칸을 돌려받음',
  '꺾기+1' => '어기어석 꺾기 +1회',
  '첫 충돌 반발+5%' => '내 수의 첫 충돌로 맞은 돌 +5%',
  '장외 시 기' => '상대 돌을 떨어뜨릴 때마다 10% 로 내공 +1칸',
  _ => '',
};

/// 기인방 진열품(이름|효과).
List<String> legendaryStock(Profile p, math.Random r) {
  final pool = <String>[
    for (final m in StoneMaterial.values)
      if (!p.materials.contains(m)) '재질:${m.name}',
    for (final s in StoneShape.values)
      if (!p.shapes.contains(s)) '모양:${s.name}',
    '비급',
    '꾸미기:금빛 잔상',
  ]..shuffle(r);
  return [
    for (final item in pool.take(3))
      '$item|${legendaryPerks[r.nextInt(legendaryPerks.length)]}',
  ];
}

/// 기인방 값: 노인이 지금 가진 엽전의 30~50% 를 부른다(최소 50). 깎기 성공 시 −20%.
int legendaryPrice(int coins, math.Random r, {bool haggled = false}) {
  final ask = math.max(50, (coins * (0.3 + r.nextDouble() * 0.2)).round());
  return haggled ? (ask * 0.8).round() : ask;
}

/// 판당 기인방 확률: 0.5% + 환생마다 0.1%p, 최대 0.8% (설계서 §5.3·§10.3).
double legendaryChance(int rebirths) =>
    math.min(0.008, Encounter.legendary.chance + 0.001 * rebirths);

/// 한 판이 끝났다. 기연이 있으면 돌려주고 바로 적용할 것(영약·기인방)은 적용한다.
/// [boost] 는 강호유랑 물음표 칸(5배).
Encounter? rollEncounter(
  Profile p,
  math.Random r, {
  required int now,
  double boost = 1,
}) {
  final u = r.nextDouble();
  final e1 = Encounter.elixir.chance * boost;
  final e2 = e1 + Encounter.hermit.chance * boost;
  final e3 = e2 + legendaryChance(0) * boost;
  final Encounter? e = u < e1
      ? Encounter.elixir
      : u < e2
      ? Encounter.hermit
      : u < e3
      ? Encounter.legendary
      : null;
  switch (e) {
    case Encounter.elixir:
      p.naegong += 100;
      p.codex.add('기연:영약');
    case Encounter.legendary:
      p.legendaryUntil = now + 10 * 60 * 1000;
      p.legendary
        ..clear()
        ..addAll(legendaryStock(p, r));
      p.codex.add('기연:기인방');
    case Encounter.hermit:
      p.codex.add('기연:은둔 고수');
    case null:
      break;
  }
  return e;
}

/// 기인방에서 하나 산다(효과도 함께 얻는다). 산 물건은 진열에서 빠진다.
bool buyLegendary(Profile p, String entry, int price) {
  if (p.coins < price || !p.legendary.contains(entry)) return false;
  p.coins -= price;
  p.legendary.remove(entry);
  final [item, perk] = entry.split('|');
  p.perks.add(perk);
  if (item.startsWith('재질:')) {
    final m = StoneMaterial.values.byName(item.substring(3));
    p.materials.add(m);
    p.codex.add('재질:${m.name}');
  } else if (item.startsWith('모양:')) {
    final s = StoneShape.values.byName(item.substring(3));
    p.shapes.add(s);
    p.codex.add('모양:${s.name}');
  } else if (item == '비급') {
    p.secretArts++;
  } else if (item.startsWith('꾸미기:')) {
    p.trails.add(item.substring(4));
  }
  if (perk == '불꽃 궤적') p.trails.add('불꽃');
  return true;
}

/// 은둔 고수 묘수풀이를 풀었다: 숨은 캐릭터(취선·묵객) 중 없는 것, 다 있으면 비급(모든 능력치 +1).
String hermitReward(Profile p, math.Random r) {
  final missing = [
    Fighter.chwiseon,
    Fighter.mukgaek,
  ].where((h) => !p.heroes.contains(h)).toList();
  if (missing.isNotEmpty) {
    final h = missing[r.nextInt(missing.length)];
    p.heroes.add(h);
    p.codex.add('캐릭터:${h.name}');
    return '은둔 고수가 제자로 받아들였다 — 새 캐릭터 ${h.label}';
  }
  p.secretArts++;
  return '희귀 비급 — 모든 능력치 +1';
}

/// 표시용 이름.
String itemLabel(String item) {
  if (item.startsWith('재질:')) {
    return '재질 ${StoneMaterial.values.byName(item.substring(3)).label}';
  }
  if (item.startsWith('모양:')) {
    return '모양 ${StoneShape.values.byName(item.substring(3)).label}';
  }
  if (item == '비급') return '비급(모든 능력치 +1)';
  if (item.startsWith('꾸미기:')) return '꾸미기 ${item.substring(4)}';
  return item;
}
