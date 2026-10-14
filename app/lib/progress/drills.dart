import 'profile.dart';

/// 목인항 단계별 수련(2026-10-14 형 「목인항 수련 단계별로 해주고 지금처럼 돌로 돌 맞추기만 하는 게 아니라
/// 여러 가지의 기술과 내공을 익힐 수 있도록 단계별 수련을 할 수 있게 해줘」).
///
/// 단계마다 한 가지 기술을 익힌다. 처음 깨면 내공·수련 포인트, 몇 단계는 영구 숙련([Drill.perk])을 준다.
enum DrillCheck {
  /// 더미를 맞힘.
  hit,

  /// 회심으로 맞힘.
  critical,

  /// 돌 아래쪽(타격점 −0.3 아래)을 쳐서 맞힘 — 끌어치기.
  draw,

  /// 돌 위쪽(타격점 +0.3 위)을 쳐서 맞힘 — 밀어치기.
  follow,

  /// 더미를 판 밖으로.
  knockOut,

  /// 손끝을 돌 앞에서 떼어 튕겨 맞힘(검지 튕기기).
  flick,

  /// 한 수에 더미 둘을 맞힘(일타쌍피).
  double,

  /// 내공 타격으로 맞힘.
  inner,

  /// 회심으로 더미를 판 밖으로(박살).
  shatter,

  /// 빗나가지 않고 이어서 맞힘.
  streak,
}

class Drill {
  const Drill(
    this.name,
    this.how,
    this.check,
    this.goal, {
    this.dummies = 1,
    this.edge = false,
    this.fullQi = false,
    this.perk,
  });
  final String name;

  /// 한 줄 설명(무엇을 하면 세는지).
  final String how;
  final DrillCheck check;
  final int goal;

  /// 더미 수(일타쌍피는 둘).
  final int dummies;

  /// 더미를 판 끝 가까이에(장외·박살 수련).
  final bool edge;

  /// 수마다 내공을 채워 준다(내공 타격 수련).
  final bool fullQi;

  /// 처음 깨면 영구로 익히는 숙련(Profile.perks).
  final String? perk;
}

/// 숙련 효과(Profile 이 읽는다).
const perkSpin = '회전 숙련', perkQi = '내공 숙련', perkFocus = '집중 숙련';

String drillPerkHelp(String perk) => switch (perk) {
  perkSpin => '회전 효율 +10%',
  perkQi => '판 시작 내공 +1칸',
  perkFocus => '회심 가운데 폭이 넓어짐',
  _ => '',
};

const drills = [
  Drill('정타', '더미를 맞혀라', DrillCheck.hit, 10),
  Drill('회심', '돌 한가운데를 알맞은 세기로 — 회심으로 맞혀라', DrillCheck.critical, 5),
  Drill(
    '끌어치기',
    '돌 아래쪽을 쳐서 맞혀라 — 맞힌 뒤 내 돌이 돌아온다',
    DrillCheck.draw,
    5,
    perk: perkSpin,
  ),
  Drill('밀어치기', '돌 위쪽을 쳐서 맞혀라 — 맞힌 뒤 내 돌이 따라간다', DrillCheck.follow, 5),
  Drill('장외', '판 끝의 더미를 판 밖으로 날려라', DrillCheck.knockOut, 3, edge: true),
  Drill('검지 튕기기', '돌 앞에서 손끝을 떼어 튕겨 맞혀라', DrillCheck.flick, 5),
  Drill('일타쌍피', '한 수에 더미 둘을 함께 맞혀라', DrillCheck.double, 3, dummies: 2),
  Drill(
    '내공 타격',
    '내공 칸을 써서 내공 타격으로 맞혀라(내공을 채워 준다)',
    DrillCheck.inner,
    3,
    fullQi: true,
    perk: perkQi,
  ),
  Drill('박살', '회심으로 판 끝의 더미를 판 밖으로 — 박살내라', DrillCheck.shatter, 2, edge: true),
  Drill('연속 정타', '빗나가지 말고 이어서 맞혀라', DrillCheck.streak, 10, perk: perkFocus),
];

/// 한 수의 결과(목인항 화면이 경기에서 읽어 넘긴다).
class DrillShot {
  const DrillShot({
    required this.touched,
    this.out = 0,
    this.critical = false,
    this.hit = 0,
    this.flick = false,
    this.inner = false,
  });

  /// 맞힌 더미 수 · 판 밖으로 나간 더미 수.
  final int touched;
  final int out;
  final bool critical;

  /// 타격점(−1 아래 ~ +1 위).
  final double hit;
  final bool flick;
  final bool inner;
}

/// 수련 한 수를 센 결과.
class DrillStep {
  const DrillStep({required this.counted, this.cleared = false, this.reward});
  final bool counted;

  /// 이번 수로 목표에 닿았다.
  final bool cleared;

  /// 처음 깼을 때 받은 것(다시 깨면 null).
  final ({int naegong, int tp, String? perk})? reward;
}

abstract final class Drills {
  /// 이 수가 [d] 수련에서 세어지나.
  static bool counts(Drill d, DrillShot s) => switch (d.check) {
    DrillCheck.hit || DrillCheck.streak => s.touched > 0,
    DrillCheck.critical => s.touched > 0 && s.critical,
    DrillCheck.draw => s.touched > 0 && s.hit < -0.3,
    DrillCheck.follow => s.touched > 0 && s.hit > 0.3,
    DrillCheck.knockOut => s.out > 0,
    DrillCheck.flick => s.touched > 0 && s.flick,
    DrillCheck.double => s.touched >= 2,
    DrillCheck.inner => s.touched > 0 && s.inner,
    DrillCheck.shatter => s.out > 0 && s.critical,
  };

  /// 고를 수 있는 단계(깬 단계 + 다음 한 단계).
  static int open(Profile p) => (p.drillCleared + 1).clamp(1, drills.length);

  /// [i] 단계 수련에 한 수를 센다. 연속 정타는 빗나가면 처음부터.
  static DrillStep record(Profile p, int i, DrillShot s) {
    final d = drills[i];
    if (p.drillIndex != i) {
      p.drillIndex = i;
      p.drillProgress = 0;
    }
    final ok = counts(d, s);
    if (!ok) {
      if (d.check == DrillCheck.streak) p.drillProgress = 0;
      return const DrillStep(counted: false);
    }
    p.drillProgress++;
    if (p.drillProgress < d.goal) return const DrillStep(counted: true);
    p.drillProgress = 0;
    if (i < p.drillCleared) {
      return const DrillStep(counted: true, cleared: true);
    }
    // 처음 깼다: 단계가 오를수록 큰 보상(2026-10-14 형 「육성 속도가 빠르게」 — 15·10 → 30·20 씩).
    p.drillCleared = i + 1;
    final naegong = 30 * (i + 1), tp = 20 * (i + 1);
    p.naegong += naegong;
    p.trainingPoints += tp;
    if (d.perk case final perk?) p.perks.add(perk);
    return DrillStep(
      counted: true,
      cleared: true,
      reward: (naegong: naegong, tp: tp, perk: d.perk),
    );
  }
}
