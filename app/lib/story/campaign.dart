import 'package:alkkagi_physics/alkkagi_physics.dart';

import '../game/match.dart';
import '../progress/profile.dart';
import 'chapters.dart';

/// 강호행 진행 규칙(설계서 §7.3·§16.1·§16.4). 화면과 떨어진 순수한 계산.
abstract final class Campaign {
  /// [i] 번째 판이 막힌 까닭. 열려 있으면 null.
  static String? lockReason(Profile p, int i) {
    final s = campaign[i];
    if (i > 0 && !p.done.contains(campaign[i - 1].id)) {
      return '앞 판(${campaign[i - 1].title})을 먼저 깨세요';
    }
    if (p.stage < s.needStage) {
      final (name, need) = naegongStages[s.needStage - 1];
      return '내공 $name(${need.toInt()}) 이 필요합니다 — 목인항에서 수련하세요';
    }
    return null;
  }

  /// 이 판을 칠 판 설정: 내 돌·무공·능력치와 고수의 돌·버릇.
  static MatchConfig configFor(Profile p, Stage s) => MatchConfig(
    mode: MatchMode.vsAi,
    difficulty: s.difficulty,
    myMaterial: p.material,
    myShape: p.shape,
    arena: s.arena,
    martial: p.school ?? Technique.none,
    opponentMaterial: s.material,
    opponentShape: s.shape,
    opponentMartial: s.martial,
    aiStyle: s.style,
    myStartQi: p.startQi,
    opponentStartQi: s.bossQi,
    powerScale: p.maxSpeed / baseMaxSpeed,
    spinScale: p.spinScale,
    steers: p.steers,
    steerSeconds: p.steerSeconds,
    opponentName: s.boss,
  );

  /// 판이 끝났다. 이겼으면 보상을 주고 무엇을 받았는지 돌려준다.
  static Reward finish(Profile p, Stage s, {required bool won}) {
    p.codex.add('고수:${s.boss}');
    if (!won) return const Reward(won: false);
    final first = !p.done.contains(s.id);
    final coins = s.coins(first: first);
    final silver = first && s.chapter != null ? 5 : 0;
    p.coins += coins;
    p.silver += silver;
    p.done.add(s.id);
    Fighter? hero;
    final h = unlockByStage[s.id];
    if (first && h != null) {
      hero = Fighter.values.firstWhere((x) => x.name == h);
      p.heroes.add(hero);
      p.codex.add('캐릭터:$h');
    }
    return Reward(
      won: true,
      first: first,
      coins: coins,
      silver: silver,
      hero: hero,
      awaken: s.id == 'c1' && p.school == null,
    );
  }
}

/// 한 판의 보상.
class Reward {
  const Reward({
    required this.won,
    this.first = false,
    this.coins = 0,
    this.silver = 0,
    this.hero,
    this.awaken = false,
  });
  final bool won;
  final bool first;
  final int coins;
  final int silver;
  final Fighter? hero;

  /// 1장을 처음 깨 문파를 고를 때다.
  final bool awaken;
}
