import 'package:alkkagi_physics/alkkagi_physics.dart';

import 'daily.dart';
import 'profile.dart';

/// 재료 · 일회용 아이템 · 주간·월간·연간 퀘스트.
///
/// 2026-10-14 형 「일일 퀘스트와 주간 월간 년간 퀘스트를 만들어서 다양한 재료와 아이템 획득을 가능하게 해주고
/// 일회용 아이템도 도입해줘」. 가방([Profile.bag])은 이름 → 개수. 값은 모두 [가정] — 해 보며 맞춘다.

/// 재료 5종(퀘스트 보상 · 아이템 만들기에 쓴다).
enum Mat {
  ore('철광석', 0xFF8C8C96),
  herb('영초', 0xFF5FBF6A),
  jade('옥가루', 0xFF7FD6B8),
  silk('천잠사', 0xFFF2EBD8),
  scale('용비늘', 0xFFE0A33A);

  const Mat(this.label, this.color);
  final String label;
  final int color;
  String get key => 'mat:$name';
}

/// 일회용 아이템 3종 — 판(혼자 하기·강호행·투기장)에서 내 차례에 한 번 쓴다.
enum Item {
  /// 다음 한 수는 반드시 회심(내공 1칸 · 박살 연출).
  critCharm('회심 부적', '다음 한 수가 반드시 회심', {Mat.jade: 3, Mat.herb: 2}),

  /// 상대가 한 번 칠 동안 내 돌이 무거워진다(감속 ×2.5) — 잘 안 밀린다.
  guardCharm('철벽 부적', '상대 차례 동안 내 돌이 잘 안 밀림', {Mat.ore: 3, Mat.scale: 1}),

  /// 내공 2칸이 바로 찬다.
  qiPill('내공 단약', '내공 2칸이 바로 참', {Mat.herb: 3, Mat.silk: 1});

  const Item(this.label, this.help, this.recipe);
  final String label;
  final String help;

  /// 만들기에 드는 재료.
  final Map<Mat, int> recipe;
  String get key => 'item:$name';
}

abstract final class Bag {
  static int count(Profile p, String key) => p.bag[key] ?? 0;

  static void add(Profile p, String key, int n) {
    if (n <= 0) return;
    p.bag[key] = count(p, key) + n;
  }

  /// [n] 개 꺼낸다. 모자라면 아무것도 안 하고 false.
  static bool take(Profile p, String key, [int n = 1]) {
    if (count(p, key) < n) return false;
    final left = count(p, key) - n;
    if (left == 0) {
      p.bag.remove(key);
    } else {
      p.bag[key] = left;
    }
    return true;
  }

  static bool canCraft(Profile p, Item i) =>
      i.recipe.entries.every((e) => count(p, e.key.key) >= e.value);

  /// 재료로 아이템 하나 만들기.
  static bool craft(Profile p, Item i) {
    if (!canCraft(p, i)) return false;
    for (final e in i.recipe.entries) {
      take(p, e.key.key, e.value);
    }
    add(p, i.key, 1);
    return true;
  }

  /// 가방 이름 → 화면 이름.
  static String label(String key) {
    for (final m in Mat.values) {
      if (m.key == key) return m.label;
    }
    for (final i in Item.values) {
      if (i.key == key) return i.label;
    }
    if (key.startsWith('frag:')) {
      final m = StoneMaterial.values.byName(key.substring(5));
      return '${m.label} 조각';
    }
    return key;
  }
}

/// 퀘스트 기간.
enum QuestPeriod {
  week('주간'),
  month('월간'),
  year('연간');

  const QuestPeriod(this.label);
  final String label;

  /// [day](yyyymmdd)가 속한 기간 열쇠. 주는 월요일에 시작한다.
  String keyOf(String day) {
    final d = DateTime.tryParse(day) ?? DateTime(2000);
    return switch (this) {
      QuestPeriod.week => () {
        final monday = d.subtract(Duration(days: d.weekday - 1));
        return 'w${monday.year}${monday.month.toString().padLeft(2, '0')}${monday.day.toString().padLeft(2, '0')}';
      }(),
      QuestPeriod.month => 'm${day.substring(0, 6)}',
      QuestPeriod.year => 'y${day.substring(0, 4)}',
    };
  }
}

/// 기간 퀘스트 셋(기간마다 같은 셋 — 길게 보는 목표). 2026-10-14: 돌 조각도 준다(형 「이벤트에서 조각」).
const questPool = {
  QuestPeriod.week: [
    Mission(
      Deed.win,
      10,
      Reward(
        coins: 300,
        bag: {'mat:ore': 5, 'mat:herb': 3, 'frag:warmJade': 2},
      ),
    ),
    Mission(Deed.knock, 60, Reward(bag: {'mat:jade': 5, 'item:critCharm': 1})),
    Mission(Deed.critical, 12, Reward(bag: {'mat:silk': 2, 'item:qiPill': 1})),
  ],
  QuestPeriod.month: [
    Mission(
      Deed.win,
      40,
      Reward(
        coins: 1000,
        bag: {'mat:scale': 1, 'item:guardCharm': 2, 'frag:dragonScale': 4},
      ),
    ),
    Mission(
      Deed.knock,
      250,
      Reward(bag: {'mat:scale': 2, 'item:critCharm': 2, 'frag:warmJade': 5}),
    ),
    Mission(
      Deed.train,
      600,
      Reward(tp: 100, bag: {'mat:silk': 6, 'item:qiPill': 3}),
    ),
  ],
  QuestPeriod.year: [
    Mission(
      Deed.win,
      400,
      Reward(
        silver: 50,
        bag: {
          'mat:scale': 10,
          'item:critCharm': 5,
          'item:guardCharm': 5,
          'item:qiPill': 5,
        },
      ),
    ),
    Mission(
      Deed.knock,
      2500,
      Reward(silver: 30, bag: {'mat:scale': 10, 'frag:taegeuk': 15}),
    ),
    Mission(Deed.train, 6000, Reward(tokens: 20, bag: {'mat:silk': 30})),
  ],
};

abstract final class Quests {
  /// 한 일을 기간마다 센다([Missions.record] 가 부른다). 기간이 바뀌면 새로 시작.
  static void record(Profile p, Deed d, String day, int n) {
    for (final q in QuestPeriod.values) {
      _roll(p, q, day);
      final k = '${q.name}:${d.name}';
      p.questCounts[k] = (p.questCounts[k] ?? 0) + n;
    }
  }

  static void _roll(Profile p, QuestPeriod q, String day) {
    final key = q.keyOf(day);
    if (p.questKeys[q.name] == key) return;
    p.questKeys[q.name] = key;
    p.questCounts.removeWhere((k, _) => k.startsWith('${q.name}:'));
    p.questClaimed.removeWhere((k) => k.startsWith('${q.name}:'));
  }

  static bool _current(Profile p, QuestPeriod q, String day) =>
      p.questKeys[q.name] == q.keyOf(day);

  static int progress(Profile p, QuestPeriod q, Mission m, String day) =>
      _current(p, q, day)
      ? (p.questCounts['${q.name}:${m.deed.name}'] ?? 0)
      : 0;

  static bool claimed(Profile p, QuestPeriod q, int i, String day) =>
      _current(p, q, day) && p.questClaimed.contains('${q.name}:$i');

  static Reward? claim(Profile p, QuestPeriod q, int i, String day) {
    final ms = questPool[q]!;
    if (i < 0 || i >= ms.length) return null;
    if (progress(p, q, ms[i], day) < ms[i].goal || claimed(p, q, i, day)) {
      return null;
    }
    p.questClaimed.add('${q.name}:$i');
    ms[i].reward.giveTo(p);
    return ms[i].reward;
  }

  static bool hasClaimable(Profile p, String day) {
    for (final q in QuestPeriod.values) {
      final ms = questPool[q]!;
      for (var i = 0; i < ms.length; i++) {
        if (progress(p, q, ms[i], day) >= ms[i].goal &&
            !claimed(p, q, i, day)) {
          return true;
        }
      }
    }
    return false;
  }
}
