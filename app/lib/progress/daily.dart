import 'dart:math' as math;

import 'profile.dart';

/// 요즘 게임의 「매일 들어올 이유」(설계서 §16.9): 출석 보상 · 일일 임무 · 업적 · 판마다 별.
///
/// 오프라인판이라 날짜는 기기 시간([today])으로 센다. 온라인판에서는 서버 시간으로 옮긴다.

/// 보상 한 묶음.
class Reward {
  const Reward({this.coins = 0, this.silver = 0, this.tokens = 0, this.tp = 0});
  final int coins;
  final int silver;
  final int tokens;
  final int tp;

  void giveTo(Profile p) {
    p.coins += coins;
    p.silver += silver;
    p.tokens += tokens;
    p.trainingPoints += tp;
  }

  /// [(아이콘 이름, 수)] — 화면에 그림으로 보여 준다.
  List<(String, int)> get items => [
    if (coins > 0) ('coin', coins),
    if (silver > 0) ('silver', silver),
    if (tokens > 0) ('token', tokens),
    if (tp > 0) ('tp', tp),
  ];
}

// ───────────────────────── 출석 ─────────────────────────

/// 7일 출석 보상(빠진 날이 있어도 끊기지 않고 다음 칸으로 — 부담 없이).
/// 2026-10-11 경제 점검: 엽전·은자는 4~6일이면 쓸 곳이 없어져 7칸째가 맥빠졌다 → 성장 재화 쪽으로.
const attendanceRewards = [
  Reward(coins: 100),
  Reward(tp: 20),
  Reward(coins: 200),
  Reward(tp: 30),
  Reward(coins: 300),
  Reward(tokens: 2),
  Reward(tokens: 2, tp: 50),
];

abstract final class Attendance {
  /// 오늘 받을 수 있나. 날짜는 앞으로만 넘어간다(기기 시계를 되돌려 다시 받는 것 막기).
  /// 시계가 잘못 앞서 갔던 날은 잊는다([saneDay]).
  static bool canClaim(Profile p, String day) =>
      day.compareTo(saneDay(p.attendDay, day)) > 0;

  /// 오늘 받을 칸(0~6).
  static int nextIndex(Profile p) => p.attendCount % attendanceRewards.length;

  /// 받기. 이미 받았으면 null.
  static Reward? claim(Profile p, String day) {
    if (!canClaim(p, day)) return null;
    final r = attendanceRewards[nextIndex(p)];
    r.giveTo(p);
    p.attendDay = day;
    p.attendCount++;
    return r;
  }
}

// ───────────────────────── 일일 임무 ─────────────────────────

/// 임무가 세는 일.
enum Deed {
  win('판 이기기'),
  play('판 하기'),
  knock('상대 돌 떨어뜨리기'),
  critical('회심 일격'),
  train('목인항 치기'),
  inner('내공 타격');

  const Deed(this.label);
  final String label;
}

class Mission {
  const Mission(this.deed, this.goal, this.reward);
  final Deed deed;
  final int goal;
  final Reward reward;
}

/// 임무 묶음 9가지. 날짜를 씨앗으로 서로 다른 일 셋을 뽑는다(예전엔 묶음이 둘뿐이었다 — 2026-10-11).
const missionPool = [
  Mission(Deed.win, 1, Reward(tp: 15, coins: 50)),
  Mission(Deed.win, 3, Reward(tp: 30)),
  Mission(Deed.play, 3, Reward(tp: 15, coins: 50)),
  Mission(Deed.knock, 6, Reward(tp: 15, coins: 50)),
  Mission(Deed.knock, 15, Reward(tp: 30)),
  Mission(Deed.critical, 2, Reward(tp: 15)),
  Mission(Deed.critical, 5, Reward(tokens: 1)),
  Mission(Deed.train, 30, Reward(tp: 15)),
  Mission(Deed.inner, 2, Reward(tp: 15, coins: 50)),
];

/// 셋 다 끝내면 덤.
const missionBonus = Reward(silver: 1);

abstract final class Missions {
  /// [day](yyyymmdd)의 임무 셋: 날짜를 씨앗으로 섞어 서로 다른 일 셋.
  static List<Mission> of(String day) {
    final order = [...missionPool]
      ..shuffle(math.Random(int.tryParse(day) ?? 0));
    final picked = <Mission>[];
    for (final m in order) {
      if (picked.any((x) => x.deed == m.deed)) continue;
      picked.add(m);
      if (picked.length == 3) break;
    }
    return picked;
  }

  /// 시계를 되돌려도 지난날로 가지 않는다(앞으로만 — 2026-10-11).
  /// 시계가 잘못 앞서 갔던 날은 잊는다([saneDay]).
  static String _eff(Profile p, String day) {
    final md = saneDay(p.missionDay, day);
    return day.compareTo(md) < 0 ? md : day;
  }

  /// 화면이 보여 줄 날(받기·세기가 쓰는 날과 같은 날 — 화면과 실제 임무가 달라지지 않게).
  static String effectiveDay(Profile p, String day) => _eff(p, day);

  static void _roll(Profile p, String day) {
    if (day.compareTo(saneDay(p.missionDay, day)) <= 0) return;
    p.missionDay = day;
    p.missionCounts.clear();
    p.missionClaimed.clear();
  }

  /// 한 일을 센다(임무와 업적 둘 다).
  static void record(Profile p, Deed d, String day, [int n = 1]) {
    if (n <= 0) return;
    day = _eff(p, day);
    _roll(p, day);
    p.missionCounts[d] = (p.missionCounts[d] ?? 0) + n;
    p.lifetime[d] = (p.lifetime[d] ?? 0) + n;
  }

  static int progress(Profile p, Mission m, String day) =>
      p.missionDay == _eff(p, day) ? (p.missionCounts[m.deed] ?? 0) : 0;

  static bool done(Profile p, Mission m, String day) =>
      progress(p, m, day) >= m.goal;

  static bool claimed(Profile p, int i, String day) =>
      p.missionDay == _eff(p, day) && p.missionClaimed.contains(i);

  /// [i] 번째 임무 보상 받기.
  static Reward? claim(Profile p, int i, String day) {
    day = _eff(p, day);
    final ms = of(day);
    if (i < 0 || i >= ms.length) return null;
    if (!done(p, ms[i], day) || claimed(p, i, day)) return null;
    _roll(p, day);
    p.missionClaimed.add(i);
    ms[i].reward.giveTo(p);
    return ms[i].reward;
  }

  /// 셋 다 받은 날 덤(한 번).
  static Reward? claimBonus(Profile p, String day) {
    day = _eff(p, day);
    if (p.missionDay != day ||
        p.missionClaimed.length < 3 ||
        p.missionClaimed.contains(99)) {
      return null;
    }
    p.missionClaimed.add(99);
    missionBonus.giveTo(p);
    return missionBonus;
  }

  /// 받을 것이 남았나(빨간 점).
  static bool hasClaimable(Profile p, String day) {
    day = _eff(p, day);
    final ms = of(day);
    for (var i = 0; i < ms.length; i++) {
      if (done(p, ms[i], day) && !claimed(p, i, day)) return true;
    }
    return p.missionDay == day && p.missionClaimed.length == 3;
  }
}

// ───────────────────────── 업적 ─────────────────────────

class Achievement {
  const Achievement(this.id, this.title, this.goal, this.reward, this.count);
  final String id;
  final String title;
  final int goal;
  final Reward reward;
  final int Function(Profile p) count;
}

final achievements = <Achievement>[
  Achievement(
    'win1',
    '첫 승리',
    1,
    const Reward(silver: 1),
    (p) => p.lifetime[Deed.win] ?? 0,
  ),
  Achievement(
    'win20',
    '스무 번 이김',
    20,
    const Reward(silver: 3),
    (p) => p.lifetime[Deed.win] ?? 0,
  ),
  Achievement(
    'knock50',
    '돌 50개 떨어뜨림',
    50,
    const Reward(silver: 2),
    (p) => p.lifetime[Deed.knock] ?? 0,
  ),
  Achievement(
    'knock300',
    '돌 300개 떨어뜨림',
    300,
    const Reward(tokens: 2),
    (p) => p.lifetime[Deed.knock] ?? 0,
  ),
  Achievement(
    'crit30',
    '회심 일격 30번',
    30,
    const Reward(silver: 2),
    (p) => p.lifetime[Deed.critical] ?? 0,
  ),
  Achievement(
    'train1000',
    '목인항 1,000타',
    1000,
    const Reward(tokens: 1),
    (p) => p.totalHits,
  ),
  Achievement(
    'ch1',
    '1장 하산',
    1,
    const Reward(coins: 300),
    (p) => p.done.contains('c1') ? 1 : 0,
  ),
  Achievement(
    'ch3',
    '3장 장터 평정',
    1,
    const Reward(silver: 2),
    (p) => p.done.contains('c3') ? 1 : 0,
  ),
  Achievement(
    'ch6',
    '천하제일',
    1,
    const Reward(tokens: 3),
    (p) => p.done.contains('c6') ? 1 : 0,
  ),
  // 강호행 9판 × 별 3 = 27 이 만점(예전 목표 30 은 이룰 수 없었다 — 2026-10-11).
  Achievement('stars9', '별 9개', 9, const Reward(tp: 30), (p) => p.totalStars),
  Achievement(
    'trick30',
    '트릭샷 별 30',
    30,
    const Reward(silver: 2),
    (p) => p.trickStarTotal,
  ),
  Achievement(
    'trick120',
    '트릭샷 별 120',
    120,
    const Reward(tokens: 3),
    (p) => p.trickStarTotal,
  ),
  Achievement(
    'stars18',
    '별 18개',
    18,
    const Reward(tokens: 1),
    (p) => p.totalStars,
  ),
  Achievement(
    'stars27',
    '별 모두(27개)',
    27,
    const Reward(silver: 3),
    (p) => p.totalStars,
  ),
  Achievement(
    'collect',
    '재질 네 가지 모두',
    4,
    const Reward(silver: 2),
    (p) => p.materials.length,
  ),
  Achievement(
    'arena5',
    '투기장 5연승',
    5,
    const Reward(tokens: 1),
    (p) => p.arenaBest,
  ),
  Achievement(
    'attend7',
    '7일 출석',
    7,
    const Reward(silver: 2),
    (p) => p.attendCount,
  ),
];

abstract final class Achievements {
  static bool ready(Profile p, Achievement a) =>
      !p.achieved.contains(a.id) && a.count(p) >= a.goal;

  static Reward? claim(Profile p, Achievement a) {
    if (!ready(p, a)) return null;
    p.achieved.add(a.id);
    a.reward.giveTo(p);
    return a.reward;
  }

  static bool hasClaimable(Profile p) => achievements.any((a) => ready(p, a));
}

// ───────────────────────── 별 ─────────────────────────

/// 판 하나의 별(설계서 §16.9): 이기면 1 · 내 돌 절반 넘게 남기면 2 · 하나도 안 잃으면 3.
int starsFor({required bool won, required int myLeft, required int myStart}) {
  if (!won || myStart <= 0) return 0;
  if (myLeft >= myStart) return 3;
  if (myLeft * 2 > myStart) return 2;
  return 1;
}

/// 판 [id] 의 별을 더 좋은 쪽으로 남긴다. 새로 얻은 별 수를 돌려준다.
int recordStars(Profile p, String id, int stars) {
  final before = p.stars[id] ?? 0;
  if (stars <= before) return 0;
  p.stars[id] = stars;
  return stars - before;
}
