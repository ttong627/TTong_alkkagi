import 'package:alkkagi_physics/alkkagi_physics.dart';

import '../game/arena.dart';
import '../game/flick.dart';
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
  static MatchConfig configFor(Profile p, Stage s) => playerConfig(
    p,
    arena: s.arena,
    difficulty: s.difficulty,
    opponentMaterial: s.material,
    opponentShape: s.shape,
    opponentMartial: s.martial,
    aiStyle: s.style,
    opponentStartQi: s.bossQi,
    opponentName: s.boss,
    aimAssist: aimAssistFor(s),
  );

  /// 예상 궤적(설계서 §7.1): 1~2장 두 번째 충돌까지, 3~4장 첫 충돌까지, 5~6장 그 절반.
  static double aimAssistFor(Stage s) {
    final ch = s.chapter ?? (s.rival == 1 ? 2 : (s.rival == 2 ? 4 : 5));
    return ch <= 2 ? 2 : (ch <= 4 ? 1 : 0.5);
  }

  /// 내 진행(캐릭터·능력치·내공·기인방 효과)을 담은 대전 설정. 강호행·투기장·강호유랑이 같이 쓴다.
  static MatchConfig playerConfig(
    Profile p, {
    required Arena arena,
    required Difficulty difficulty,
    StoneMaterial opponentMaterial = StoneMaterial.cheongok,
    StoneShape opponentShape = StoneShape.round,
    Technique opponentMartial = Technique.none,
    AiStyle aiStyle = AiStyle.plain,
    int opponentStartQi = 0,
    String? opponentName,
    double aimAssist = 1,
  }) {
    final h = p.hero;
    final perkKnock = p.perks.contains('장외 시 기');
    return MatchConfig(
      mode: MatchMode.vsAi,
      difficulty: difficulty,
      myMaterial: p.material,
      myShape: p.shape,
      arena: arena,
      martial: p.school ?? Technique.none,
      opponentMaterial: opponentMaterial,
      opponentShape: opponentShape,
      opponentMartial: opponentMartial,
      aiStyle: aiStyle,
      myStartQi: p.startQi,
      opponentStartQi: opponentStartQi,
      powerScale: p.maxSpeed / baseMaxSpeed,
      spinScale: p.spinScale,
      steers: p.steersTotal,
      steerSeconds: p.steerSeconds,
      opponentName: opponentName,
      myTrail: p.trail == '기본' ? null : p.trail,
      qiSaver: p.perks.contains('내공 아낌'),
      impactScale:
          (p.perks.contains('첫 충돌 반발+5%') ? 1.05 : 1) *
          (h == Fighter.banDal ? 1.1 : 1),
      innerSpeed: h == Fighter.yonga ? 1.35 : TechniqueConstants.innerSpeed,
      critDoubleChance: h == Fighter.chwiseon ? 0.2 : 0,
      knockoutQiChance: h == Fighter.mukgaek ? 1 : (perkKnock ? 0.1 : 0),
      knockoutQiMax: h == Fighter.mukgaek ? 2 : (perkKnock ? 99 : 0),
      critWidth: h == Fighter.jeonggak ? 0.2 : CriticalRule.maxOffset,
      aimAssist: aimAssist,
    );
  }

  /// 판이 끝났다. 이겼으면 보상을 주고 무엇을 받았는지 돌려준다.
  static Reward finish(Profile p, Stage s, {required bool won}) {
    p.codex.add('고수:${s.boss}');
    if (!won) return const Reward(won: false);
    final first = !p.done.contains(s.id);
    final coins = s.coins(first: first);
    final silver = first && s.chapter != null ? 5 : 0;
    p.coins += coins;
    p.silver += silver;
    // 숙적을 이기면 무림맹 징표.
    if (s.rival != null) p.tokens++;
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
