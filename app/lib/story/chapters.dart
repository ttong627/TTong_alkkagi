import 'package:alkkagi_physics/alkkagi_physics.dart';

import '../game/arena.dart';
import '../game/match.dart';

/// 대사 한 줄.
typedef Line = (String who, String text);

/// 강호행 한 판(장 또는 숙적전).
class Stage {
  const Stage({
    required this.id,
    required this.title,
    required this.arena,
    required this.boss,
    required this.material,
    required this.shape,
    required this.difficulty,
    required this.style,
    required this.needStage,
    required this.intro,
    required this.outro,
    this.chapter,
    this.rival,
    this.martial = Technique.none,
    this.bossQi = 0,
  });

  final String id;
  final String title;
  final Arena arena;
  final String boss;
  final StoneMaterial material;
  final StoneShape shape;
  final Difficulty difficulty;
  final AiStyle style;

  /// 들어가는 데 필요한 내공 단계(설계서 §16.2).
  final int needStage;

  /// 장 번호(1~6) — 숙적전이면 null.
  final int? chapter;

  /// 숙적전 번호(1~3) — 장이면 null.
  final int? rival;

  /// 보스가 쓰는 무공(내공 타격 때).
  final Technique martial;

  /// 보스 판 시작 내공 칸.
  final int bossQi;

  final List<Line> intro;
  final List<Line> outro;

  /// 이겼을 때 엽전(설계서 §16.4): 장 30 + 장×10, 숙적 50. 처음이면 ×2.
  int coins({required bool first}) {
    final base = rival != null ? 50 : 30 + (chapter ?? 0) * 10;
    return first ? base * 2 : base;
  }
}

/// 서장 대사(처음 강호행을 열 때 한 번).
const List<Line> prologue = [
  ('해설', '산골 흙먼지 마을. 너는 촌장에게서 알까기를 배우며 자랐다.'),
  ('해설', '하산하는 날 아침, 공터 흙 속에서 문양이 새겨진 검은 돌 하나가 손에 잡힌다.'),
  ('촌장', '기명석(棋銘石)이로구나. 손끝에 대 보거라… 떨리느냐?'),
  ('촌장', '탄지는 손가락이 아니라 마음으로 튕기는 것이다. 그 돌이 너를 고른 모양이다.'),
  ('묵현', '오랜만입니다, 사부. 그 돌, 제가 가져가야겠습니다.'),
  ('촌장', '묵현! 파문당한 놈이 어딜…! 얘야, 떠나기 전에 마지막으로 한 판 두자. 네 손끝을 믿어라.'),
];

/// 강호행 순서: 장 1~6 과 숙적전 3번 (설계서 §9.1·§9.2·§16.1).
const List<Stage> campaign = [
  Stage(
    id: 'c1',
    chapter: 1,
    title: '1장 · 하산의 길',
    arena: Arena.dustyYard,
    boss: '촌장',
    material: StoneMaterial.cheongok,
    shape: StoneShape.flat,
    difficulty: Difficulty.easy,
    style: AiStyle.teacher,
    needStage: 1,
    intro: [
      ('촌장', '돌 한가운데를 알맞은 세기로 맞히면 「회심」이 터진다. 그때 내공이 한 칸 찬다.'),
      ('촌장', '내공이 차면 내공 타격으로 더 세게 칠 수 있다. 자, 덤벼 보거라.'),
    ],
    outro: [
      ('촌장', '…허허, 이젠 내가 배워야겠구나.'),
      ('해설', '기명석의 첫 문양이 빛난다. 네 안에 잠든 무공이 깨어난다 — 문파를 고를 때다.'),
      ('촌장', '묵현은 내가 막겠다. 가거라, 통통 객잔으로.'),
    ],
  ),
  Stage(
    id: 'c2',
    chapter: 2,
    title: '2장 · 기름진 난장, 통통 객잔',
    arena: Arena.oilyTable,
    boss: '통통',
    material: StoneMaterial.hyeoncheol,
    shape: StoneShape.round,
    difficulty: Difficulty.normal,
    style: AiStyle.ram,
    needStage: 2,
    intro: [
      ('통통', '어서 오시게! 무림맹 대회 추천서? 있지. 내 원탁에서 날 이기면 주겠네.'),
      ('통통', '바닥에 기름이 좀 튀었네만… 핑계는 안 받네! 하하!'),
      ('해설', '통통의 현철 돌은 무겁다. 정면으로 받지 말고 미끄러운 바닥의 반발을 써라.'),
    ],
    outro: [
      ('통통', '허, 내 현철이 밀리다니! 약속은 약속, 추천서 여기 있네.'),
      ('해설', '그때 객잔 문이 부서지며 검은 그림자가 들이닥친다.'),
    ],
  ),
  Stage(
    id: 'r1',
    rival: 1,
    title: '숙적 · 묵현 (첫 번째)',
    arena: Arena.oilyTable,
    boss: '묵현',
    material: StoneMaterial.cheongok,
    shape: StoneShape.round,
    difficulty: Difficulty.normal,
    style: AiStyle.master,
    martial: Technique.swordQi,
    bossQi: 1,
    needStage: 2,
    intro: [
      ('묵현', '사부가 날 막았지만 오래 못 버틸 거다. 그 돌을 내놔라.'),
      ('묵현', '검기(劍氣) — 사부가 나에게만 가르친 기술이다.'),
    ],
    outro: [('묵현', '…운이 좋았을 뿐이다. 장터에서 다시 보자.')],
  ),
  Stage(
    id: 'c3',
    chapter: 3,
    title: '3장 · 거북 장터 난투',
    arena: Arena.turtleMarket,
    boss: '숨은 자객',
    material: StoneMaterial.cheongok,
    shape: StoneShape.flat,
    difficulty: Difficulty.normal,
    style: AiStyle.assassin,
    needStage: 3,
    intro: [
      ('해설', '북적이는 거북 장터. 사람들 사이에서 차가운 기운이 느껴진다.'),
      ('자객', '묵현 님의 명이다. 판 끝에 선 돌부터 하나씩 떨어뜨려 주지.'),
      ('해설', '자객은 판 가장자리에 가까운 돌만 노린다. 안쪽으로 모아 두어라.'),
    ],
    outro: [('자객', '…이런 실력이라니. 묵현 님께 전해야겠군.')],
  ),
  Stage(
    id: 'c4',
    chapter: 4,
    title: '4장 · 야성의 숲, 쿠비 산채',
    arena: Arena.kubiForest,
    boss: '쿠비',
    material: StoneMaterial.cheongok,
    shape: StoneShape.sphere,
    difficulty: Difficulty.normal,
    style: AiStyle.spinner,
    needStage: 4,
    intro: [
      ('쿠비', '이 숲을 지나려면 통행료를 내라! 없으면 돌로 내든가!'),
      ('쿠비', '내 구형 돌은 끌어치기의 왕이지. 맞고 돌아오는 걸 보면 놀랄걸?'),
    ],
    outro: [
      ('쿠비', '너 같은 놈 처음 본다! 좋아, 오늘부터 형님이라 부르마. 내 제자 놈을 데려가라.'),
      ('해설', '숲을 나서는 길목 — 낯선 기운을 두른 묵현이 기다리고 있다.'),
    ],
  ),
  Stage(
    id: 'r2',
    rival: 2,
    title: '숙적 · 묵현 (두 번째)',
    arena: Arena.kubiForest,
    boss: '묵현',
    material: StoneMaterial.hyeoncheol,
    shape: StoneShape.round,
    difficulty: Difficulty.normal,
    style: AiStyle.master,
    martial: Technique.stomp,
    bossQi: 2,
    needStage: 4,
    intro: [('묵현', '사부의 검기로는 안 됐지. 그래서 권사의 진각을 익혔다.')],
    outro: [('묵현', '왜… 왜 그 돌은 너를 고른 거지?')],
  ),
  Stage(
    id: 'c5',
    chapter: 5,
    title: '5장 · 철벽의 진인, 로직 학당',
    arena: Arena.logicMarble,
    boss: '로직',
    material: StoneMaterial.ice,
    shape: StoneShape.round,
    difficulty: Difficulty.hard,
    style: AiStyle.calculator,
    needStage: 5,
    intro: [
      ('로직', '모든 수는 계산할 수 있습니다. 당신의 다음 수도요.'),
      ('로직', '대리석 위에서는 작은 각도 하나가 승부를 가릅니다.'),
    ],
    outro: [
      ('로직', '계산 밖의 수… 흥미롭군요. 힌트를 드리지요: 선을 그리면, 기가 따릅니다.'),
      ('해설', '기명석의 세 번째 문양이 풀린다. 어기어석 — 날아가는 돌을 마음의 선으로 꺾는 비기.'),
    ],
  ),
  Stage(
    id: 'r3',
    rival: 3,
    title: '숙적 · 묵현 (세 번째)',
    arena: Arena.logicMarble,
    boss: '묵현',
    material: StoneMaterial.hyeoncheol,
    shape: StoneShape.sphere,
    difficulty: Difficulty.hard,
    style: AiStyle.master,
    martial: Technique.clone,
    bossQi: 3,
    needStage: 5,
    intro: [('묵현', '대회 전날 밤이다. 살수의 분신까지 익혔다. 이번엔 끝을 내자.')],
    outro: [
      ('묵현', '…「탄지는 마음으로 튕기는 것」. 사부의 말이 이제야 들리는군.'),
      ('묵현', '가라. 결승의 맹주는 사부의 사형, 용린석의 주인이다.'),
    ],
  ),
  Stage(
    id: 'c6',
    chapter: 6,
    title: '6장 · 천하제일 탄지대회',
    arena: Arena.murimIce,
    boss: '무림맹주',
    material: StoneMaterial.hyeoncheol,
    shape: StoneShape.sphere,
    difficulty: Difficulty.hard,
    style: AiStyle.master,
    martial: Technique.stomp,
    bossQi: 3,
    needStage: 6,
    intro: [
      ('맹주', '사제의 기명석을 가진 아이로구나. 용린석이 너를 기다렸다.'),
      ('맹주', '빙판 위에서는 한 번의 실수가 판 밖이다. 내공을 아끼지 마라.'),
    ],
    outro: [
      ('맹주', '훌륭하다. 이 용린석을 기명석에 끼워라.'),
      ('해설', '네 번째 문양 — 탄지신통이 완성된다. 천하가 네 손끝을 안다.'),
      ('맹주', '탄지는 끝이 없다. 다시 처음부터 걸어 보겠느냐?'),
    ],
  ),
];

/// 장을 깨면 열리는 캐릭터 (설계서 §16.3).
const unlockByStage = {
  'c2': 'banDal',
  'c4': 'gurumi',
  'c5': 'jeonggak',
  'c6': 'yonga',
};
