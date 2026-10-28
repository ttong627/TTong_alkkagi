import 'package:alkkagi_physics/alkkagi_physics.dart';

import '../game/match.dart';
import '../progress/daily.dart' as daily;
import '../progress/profile.dart';
import '../progress/quests.dart';
import 'campaign.dart';
import 'chapters.dart';

/// 강호행 단계별 코스(2026-10-14 형 「단계별 코스에 졸개나 중간 단계를 7~9단계로 구성하고
/// 3, 4단계마다 중간보스 등장, 마지막 단계에서 보스 등장으로 구성해줘」).
///
/// 장마다 10~12단계: 졸개 판들 사이 4단계(12단계 장은 7단계에도)에 중간 보스, 보스 세 단계 앞에 부두목 흑풍,
/// 마지막 단계에 그 장의 보스(2026-10-28 장마다 3단계 더 — 새 단계는 보스 앞에 붙여 예전 단계 id 가 그대로다).
/// 숙적 묵현은 다음 장의 중간 보스로 나온다(3·5·6장) — 예전 판 순서(장 → 숙적 → 다음 장)와 같다.
enum StepKind {
  minion('졸개'),
  mid('중간 보스'),
  boss('보스');

  const StepKind(this.label);
  final String label;
}

/// 코스 한 단계.
class CourseStep {
  const CourseStep.minion(this.stones)
    : kind = StepKind.minion,
      foe = null,
      material = null,
      stageId = null,
      rematchOf = null;
  const CourseStep.mid(this.foe, this.stones, this.material)
    : kind = StepKind.mid,
      stageId = null,
      rematchOf = null;

  /// 장 보스이거나 숙적(이야기 대사가 있는 판 · [campaign] 의 id).
  const CourseStep.stage(this.stageId, {bool mid = false})
    : kind = mid ? StepKind.mid : StepKind.boss,
      foe = null,
      stones = stonesPerTeam,
      material = null,
      rematchOf = null;

  /// 10장 보스 재대결(2026-10-28 형 「10단계는 보스로만 구성」): 앞 장 보스가 그 대전장에서 더 강해져 다시 나온다.
  /// 이야기 판을 다시 치는 것이 아니라 새 단계(진행 id 는 k10s…)다.
  const CourseStep.rematch(this.rematchOf)
    : kind = StepKind.boss,
      foe = null,
      stones = stonesPerTeam,
      material = null,
      stageId = null;

  final StepKind kind;

  /// 중간 보스 이름(이야기 판이면 null — 판의 고수).
  final String? foe;

  /// 상대 돌 수.
  final int stones;

  /// 중간 보스 돌 재질.
  final StoneMaterial? material;

  /// 이야기 판 id(c1 · r1 …).
  final String? stageId;

  /// 재대결하는 이야기 판 id(10장).
  final String? rematchOf;

  /// 재대결 상대 판.
  Stage? get rematch =>
      rematchOf == null ? null : campaign.firstWhere((x) => x.id == rematchOf);
}

/// 장 하나의 코스.
class Course {
  const Course(this.chapter, this.minion, this.steps);
  final int chapter;

  /// 졸개 이름.
  final String minion;
  final List<CourseStep> steps;

  /// 장 보스 판.
  Stage get boss => campaign.firstWhere((s) => s.chapter == chapter);

  /// [i] 번째 단계의 진행 id(이야기 판이면 그 판 id).
  String idOf(int i) => steps[i].stageId ?? 'k${chapter}s${i + 1}';
}

/// 흑풍채 부두목(2026-10-28 형 「스테이지 3라운드 정도 더 · 중간 보스 부두목까지」): 장마다 보스 세 단계 앞
/// 마지막 중간 보스로 나와, 장이 갈수록 좋은 돌·많은 돌로 다시 막아선다. 그림 = 코덱스(tool/art · budumok).
const budumok = '부두목 흑풍';

const courses = [
  Course(1, '마을 장난꾼', [
    CourseStep.minion(3),
    CourseStep.minion(4),
    CourseStep.minion(4),
    CourseStep.mid('나무꾼 강쇠', 5, StoneMaterial.wood),
    CourseStep.minion(5),
    CourseStep.minion(5),
    CourseStep.mid(budumok, 5, StoneMaterial.wood),
    CourseStep.minion(5),
    CourseStep.minion(5),
    CourseStep.stage('c1'),
  ]),
  Course(2, '객잔 불한당', [
    CourseStep.minion(4),
    CourseStep.minion(4),
    CourseStep.minion(5),
    CourseStep.mid('주방장 왕솥', 6, StoneMaterial.obsidian),
    CourseStep.minion(5),
    CourseStep.minion(6),
    CourseStep.minion(6),
    CourseStep.mid(budumok, 6, StoneMaterial.obsidian),
    CourseStep.minion(6),
    CourseStep.minion(6),
    CourseStep.stage('c2'),
  ]),
  Course(3, '장터 건달', [
    CourseStep.minion(4),
    CourseStep.minion(5),
    CourseStep.minion(5),
    CourseStep.stage('r1', mid: true),
    CourseStep.minion(5),
    CourseStep.minion(6),
    CourseStep.minion(6),
    CourseStep.mid(budumok, 6, StoneMaterial.obsidian),
    CourseStep.minion(6),
    CourseStep.minion(6),
    CourseStep.stage('c3'),
  ]),
  Course(4, '산채 졸개', [
    CourseStep.minion(5),
    CourseStep.minion(5),
    CourseStep.minion(6),
    CourseStep.mid('부두목 곰발', 6, StoneMaterial.granite),
    CourseStep.minion(6),
    CourseStep.minion(6),
    CourseStep.mid('날쌘 칼잡이', 7, StoneMaterial.diamond),
    CourseStep.minion(7),
    CourseStep.mid(budumok, 7, StoneMaterial.granite),
    CourseStep.minion(7),
    CourseStep.minion(7),
    CourseStep.stage('c4'),
  ]),
  Course(5, '학당 문도', [
    CourseStep.minion(5),
    CourseStep.minion(6),
    CourseStep.minion(6),
    CourseStep.stage('r2', mid: true),
    CourseStep.minion(6),
    CourseStep.minion(7),
    CourseStep.minion(7),
    CourseStep.mid(budumok, 7, StoneMaterial.diamond),
    CourseStep.minion(7),
    CourseStep.minion(7),
    CourseStep.stage('c5'),
  ]),
  Course(6, '맹 무사', [
    CourseStep.minion(6),
    CourseStep.minion(6),
    CourseStep.minion(7),
    CourseStep.mid('친위대장 철갑', 7, StoneMaterial.hyeoncheol),
    CourseStep.minion(7),
    CourseStep.minion(7),
    CourseStep.stage('r3', mid: true),
    CourseStep.minion(8),
    CourseStep.mid(budumok, 8, StoneMaterial.jageum),
    CourseStep.minion(8),
    CourseStep.minion(8),
    CourseStep.stage('c6'),
  ]),
  // 2026-10-28 형 「새로운 이야기도 지금 6개에서 10개로」.
  Course(7, '사막 도적', [
    CourseStep.minion(6),
    CourseStep.minion(6),
    CourseStep.minion(7),
    CourseStep.mid('모래 전갈 사갈', 7, StoneMaterial.diamond),
    CourseStep.minion(7),
    CourseStep.minion(7),
    CourseStep.minion(7),
    CourseStep.mid(budumok, 8, StoneMaterial.jageum),
    CourseStep.minion(8),
    CourseStep.minion(8),
    CourseStep.stage('c7'),
  ]),
  Course(8, '해적 졸개', [
    CourseStep.minion(6),
    CourseStep.minion(7),
    CourseStep.minion(7),
    CourseStep.mid('갑판장 외눈', 7, StoneMaterial.hyeoncheol),
    CourseStep.minion(7),
    CourseStep.minion(8),
    CourseStep.minion(8),
    CourseStep.mid(budumok, 8, StoneMaterial.jageum),
    CourseStep.minion(8),
    CourseStep.minion(8),
    CourseStep.stage('c8'),
  ]),
  Course(9, '불꽃 시종', [
    CourseStep.minion(7),
    CourseStep.minion(7),
    CourseStep.minion(7),
    CourseStep.mid('화동 염귀', 8, StoneMaterial.obsidian),
    CourseStep.minion(8),
    CourseStep.minion(8),
    CourseStep.mid('용암 거인 석괴', 8, StoneMaterial.uncheol),
    CourseStep.minion(8),
    CourseStep.mid(budumok, 8, StoneMaterial.uncheol),
    CourseStep.minion(8),
    CourseStep.minion(8),
    CourseStep.stage('c9'),
  ]),
  // 10장: 보스만 10단계 — 지나온 아홉 장의 보스가 차례로 더 강해져 나오고, 마지막에 알까기 신.
  Course(10, '천상의 환영', [
    CourseStep.rematch('c1'),
    CourseStep.rematch('c2'),
    CourseStep.rematch('c3'),
    CourseStep.rematch('c4'),
    CourseStep.rematch('c5'),
    CourseStep.rematch('c6'),
    CourseStep.rematch('c7'),
    CourseStep.rematch('c8'),
    CourseStep.rematch('c9'),
    CourseStep.stage('c10'),
  ]),
];

/// 코스 진행 규칙(화면과 떨어진 순수한 계산).
abstract final class CourseRules {
  /// [c] 장의 [i] 단계가 막힌 까닭. 열려 있으면 null.
  ///
  /// 장 보스를 이미 깬 장(코스가 생기기 전 진행)은 모든 단계가 열려 있다.
  static String? lockReason(Profile p, Course c, int i) {
    if (p.done.contains(c.boss.id)) return null;
    final s = c.steps[i];
    // 장에 들어가는 문: 앞 장 보스 · 내공 단계(그 장 보스의 조건).
    if (c.chapter > 1) {
      final prev = courses[c.chapter - 2].boss;
      if (!p.done.contains(prev.id)) {
        return '${prev.title.split(' · ').first} 보스를 먼저';
      }
    }
    if (p.stage < c.boss.needStage) {
      final (name, need) = naegongStages[c.boss.needStage - 1];
      return '내공 $name(${need.toInt()}) 필요';
    }
    if (i > 0 && !p.done.contains(c.idOf(i - 1))) return '$i단계 먼저';
    // 이야기 판은 예전 판 순서(장 → 숙적 → 다음 장)의 문도 그대로 지킨다.
    if (s.stageId != null) {
      return Campaign.lockReason(
        p,
        campaign.indexWhere((x) => x.id == s.stageId),
      );
    }
    return null;
  }

  /// 깬 단계 수.
  static int doneCount(Profile p, Course c) =>
      [for (var i = 0; i < c.steps.length; i++) c.idOf(i)]
          .where(p.done.contains)
          .length;

  /// 재대결 보스의 손 오차 배수(이야기 판 값에 곱함 — 처음보다 강해져 돌아온다) · 더하는 시작 내공.
  static const double rematchError = 0.7;
  static const int rematchQi = 1;

  /// 졸개·중간 보스·재대결 판 설정(이야기 판은 [Campaign.configFor]).
  static MatchConfig configFor(
    Profile p,
    Course c,
    int i, {
    bool easy = false,
  }) {
    final s = c.steps[i];
    if (s.rematch case final st?) {
      final t = Campaign.tune(st, easy: easy);
      return Campaign.configFor(
        p,
        st,
        easy: easy,
        aiErrorScale: t.errorScale * rematchError,
        bossQi: ((t.bossQi ?? st.bossQi) + rematchQi).clamp(0, maxQi),
      );
    }
    final boss = c.boss;
    final mid = s.kind == StepKind.mid;
    // 졸개는 고수보다 손이 서툴다(뒤 장일수록 조금씩 낫다 · 7장부터는 더 줄지 않는다). 쉬움이면 더.
    final err =
        (mid ? 1.6 : 2.4) *
        (easy ? 1.5 : 1) *
        (1 - 0.05 * (c.chapter - 1)).clamp(0.7, 1.0);
    return Campaign.playerConfig(
      p,
      arena: boss.arena,
      difficulty: c.chapter <= 2
          ? Difficulty.easy
          : (c.chapter <= 4 ? Difficulty.normal : Difficulty.skilled),
      opponentMaterial: s.material ?? StoneMaterial.cheongok,
      opponentShape: mid ? StoneShape.round : StoneShape.flat,
      opponentName: s.foe ?? c.minion,
      aimAssist: Campaign.aimAssistFor(boss),
      weather: boss.weather,
      features: boss.features,
      shiftingFloor: boss.shiftingFloor,
      qiClash: mid,
      aiErrorScale: err,
      opponentStones: s.stones,
    );
  }

  /// 졸개·중간 보스·재대결을 이겼다 — 엽전(처음 ×2) · 처음이면 재료(중간 보스·재대결은 재료 2 + 아이템 1).
  static daily.Reward finish(Profile p, Course c, int i, {required bool won}) {
    final s = c.steps[i];
    final id = c.idOf(i);
    if (!won) return const daily.Reward();
    final first = !p.done.contains(id);
    final rematch = s.rematchOf != null;
    final mid = s.kind == StepKind.mid || rematch;
    // 2026-10-28 형 「돈이 너무 안 모여」: 2배(값은 10배로 올렸는데 보상은 그대로였다).
    final base = rematch
        ? 100 + 20 * c.chapter
        : (mid ? 80 + 20 * c.chapter : 30 + 10 * c.chapter);
    final coins = first ? base * 2 : base ~/ 2;
    const mats = [Mat.ore, Mat.herb, Mat.jade, Mat.silk];
    final m = mats[(c.chapter + i) % mats.length];
    final r = daily.Reward(
      coins: coins,
      bag: !first
          ? const {}
          : mid
          ? {
              m.key: 2,
              if (c.chapter >= 4) Mat.scale.key: 1,
              // 돌 조각(2026-10-14 형 「조각을 모아서 완성하는 돌」).
              shardKey(StoneMaterial.warmJade): 2,
              (i.isEven ? Item.critCharm : Item.qiPill).key: 1,
            }
          : {m.key: 1},
    );
    r.giveTo(p);
    p.done.add(id);
    return r;
  }
}
