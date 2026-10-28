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
    this.weather = Weather.clear,
    this.features = const [],
    this.civilians = const [],
    this.shiftingFloor = false,
    this.quips = const [],
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

  /// 장 번호(1~10) — 숙적전이면 null.
  final int? chapter;

  /// 숙적전 번호(1~3) — 장이면 null.
  final int? rival;

  /// 보스가 쓰는 무공(내공 타격 때).
  final Technique martial;

  /// 보스 판 시작 내공 칸.
  final int bossQi;

  /// 천기(날씨, 설계서 §9.3).
  final Weather weather;

  /// 판 위 지물·장애물(설계서 §9.1·§9.4).
  final List<Feature> features;

  /// 백성 돌(3장): 떨어뜨리면 하나에 엽전 [civilianPenalty] 을 뺀다.
  final List<Placement> civilians;

  /// 6장: 수마다 빙판(×0.6)과 불꽃(×1.3) 바닥이 바뀐다.
  final bool shiftingFloor;

  /// 판 중 고수 한마디 6줄(설계서 §16.7): [0·1] 내가 회심을 터뜨렸을 때, [2·3] 내가 한 수에
  /// 2개 넘게 떨어뜨렸을 때(일타쌍피), [4·5] 고수가 내 돌을 2개 넘게 떨어뜨렸을 때.
  final List<String> quips;

  final List<Line> intro;
  final List<Line> outro;

  /// 대사 화면에 나오는 이름(「숨은 자객」→「자객」, 「무림맹주」→「맹주」).
  String get speaker => switch (boss) {
    '숨은 자객' => '자객',
    '무림맹주' => '맹주',
    _ => boss,
  };

  /// 이겼을 때 엽전(설계서 §16.4): 장 60 + 장×20, 숙적 100. 처음이면 ×2, 다시 깨면 절반
  /// (2026-10-11 경제 점검: 1장 되풀이로 엽전을 끝없이 모으던 것).
  /// 2026-10-28 형 「돈이 너무 안 모여 재미가 덜해 · 너무 많이는 말고」: 값은 10배로 올렸는데 보상은 그대로였다 → 2배.
  int coins({required bool first}) {
    final base = rival != null ? 100 : 60 + (chapter ?? 0) * 20;
    return first ? base * 2 : base ~/ 2;
  }
}

/// 3장 백성 돌 하나를 떨어뜨렸을 때 빼는 엽전(정한 값 — 설계서 §9.1 은 「감점」만 적었다).
const int civilianPenalty = 10;

/// 서장 대사(처음 강호행을 열 때 한 번).
const List<Line> prologue = [
  ('해설', '산골 흙먼지 마을. 너는 촌장에게서 알까기를 배우며 자랐다.'),
  ('해설', '하산하는 날 아침, 공터 흙 속에서 문양이 새겨진 검은 돌 하나가 손에 잡힌다.'),
  ('촌장', '기명석(棋銘石)이로구나. 손끝에 대 보거라… 떨리느냐?'),
  ('촌장', '탄지는 손가락이 아니라 마음으로 튕기는 것이다. 그 돌이 너를 고른 모양이다.'),
  ('묵현', '오랜만입니다, 사부. 그 돌, 제가 가져가야겠습니다.'),
  ('촌장', '묵현! 파문당한 놈이 어딜…! 얘야, 떠나기 전에 마지막으로 한 판 두자. 네 손끝을 믿어라.'),
];

/// 강호행 순서: 장 1~10 과 숙적전 3번 (설계서 §9.1·§9.2·§16.1 · 7~10장 2026-10-28).
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
    quips: [
      '허허, 그게 회심이다! 손끝이 기억하게 두어라.',
      '가운데를 맞혔구나. 마음이 고요했지?',
      '한 번에 둘을? 내가 가르친 적 없는 수다!',
      '이놈, 어느새 나를 앞질렀구나.',
      '서두르지 마라. 돌은 도망가지 않는다.',
      '판 가장자리를 보거라. 거기가 낭떠러지다.',
    ],
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
    quips: [
      '오호! 그 소리, 객잔 종소리보다 맑군!',
      '제법이구먼! 한 그릇 서비스할까?',
      '내 원탁이 텅 비어 가네! 이거 장사 망하겠어!',
      '하하, 기름 바닥을 그렇게 타다니!',
      '쿵! 이게 현철의 맛이지!',
      '정면으로 받으면 다 날아간다니까!',
    ],
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
    weather: Weather.nightRain,
    quips: [
      '…사부의 회심이군. 그 손끝, 마음에 안 든다.',
      '운이 아니라고 말하고 싶은 거냐.',
      '둘을 한꺼번에…! 기명석이 돕는 건가.',
      '…이 정도였나.',
      '밤비 속에선 네 돌만 보이겠지. 나는 다 보인다.',
      '검기는 멈추지 않는다.',
    ],
    intro: [
      ('해설', '객잔 등불이 꺼지고 밤비가 들이친다. 내 돌 둘레만 겨우 보이고, 바닥은 젖어 잘 멈추지 않는다.'),
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
    civilians: [
      Placement(-6, -1, team: 2, shape: StoneShape.flat),
      Placement(0, 2, team: 2, shape: StoneShape.flat),
      Placement(6, -1, team: 2, shape: StoneShape.flat),
      Placement(-3, 4, team: 2, shape: StoneShape.flat),
      Placement(3, -4, team: 2, shape: StoneShape.flat),
    ],
    quips: [
      '(자객이 어둠 속에서 혀를 찬다)',
      '…정확하군. 보고할 것이 늘었다.',
      '백성 사이로 둘이나…! 겁도 없군.',
      '물러설 때를 아는 것도 실력이다.',
      '가장자리에 서 있으면 떨어지는 법이지.',
      '장터는 넓고, 네 돌은 적다.',
    ],
    intro: [
      ('해설', '북적이는 거북 장터. 사람들 사이에서 차가운 기운이 느껴진다.'),
      ('자객', '묵현 님의 명이다. 판 끝에 선 돌부터 하나씩 떨어뜨려 주지.'),
      ('해설', '자객은 판 가장자리에 가까운 돌만 노린다. 안쪽으로 모아 두어라.'),
      ('해설', '판 가운데 납작한 회색 돌은 장터 백성이다. 판 밖으로 떨어뜨리면 하나에 엽전 10 을 물어 준다.'),
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
    features: [
      Feature(FeatureKind.branch, -6, 0, angle: 0.35),
      Feature(FeatureKind.branch, 6, 2, angle: -0.5),
      Feature(FeatureKind.pebble, 0, -3),
      Feature(FeatureKind.pebble, -2, 4),
      Feature(FeatureKind.pebble, 3, -1),
    ],
    quips: [
      '캬! 그 회심, 우리 산채 술맛 같구나!',
      '형님 소리 나오겠는데?',
      '둘이나 날렸다고?! 나뭇가지도 못 막았네!',
      '이러다 통행료를 내가 내겠구먼!',
      '끌어치기 봤냐! 돌아오는 맛이 있지!',
      '숲은 내 편이다! 하하하!',
    ],
    intro: [
      ('쿠비', '이 숲을 지나려면 통행료를 내라! 없으면 돌로 내든가!'),
      ('쿠비', '내 구형 돌은 끌어치기의 왕이지. 맞고 돌아오는 걸 보면 놀랄걸?'),
      ('해설', '숲길에 나뭇가지와 조약돌이 박혀 있다. 맞으면 힘을 잃고 꺾인다 — 돌아 맞히는 수를 노려라.'),
    ],
    outro: [
      ('쿠비', '너 같은 놈 처음 본다! 좋아, 오늘부터 형님이라 부르마. 내 제자 놈을 데려가라.'),
      ('해설', '함께 걷는 이가 생기자 기명석의 두 번째 문양이 따뜻하게 빛난다.'),
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
    weather: Weather.gale,
    quips: [
      '…진각으로도 꺾이지 않는 회심인가.',
      '사부는 왜 너에게만…',
      '둘을…! 바람마저 네 편이냐.',
      '아직 끝나지 않았다.',
      '진각 한 번에 둘이다. 이게 권사의 무게다.',
      '광풍은 공평하지. 공평하게 너를 날린다.',
    ],
    intro: [
      ('해설', '숲 어귀에 광풍이 분다. 바람은 5초마다 방향을 바꾸며 굴러가는 돌을 옆으로 민다.'),
      ('묵현', '사부의 검기로는 안 됐지. 그래서 권사의 진각을 익혔다.'),
    ],
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
    difficulty: Difficulty.skilled,
    style: AiStyle.calculator,
    needStage: 5,
    features: [
      Feature(FeatureKind.bamboo, -7, 0),
      Feature(FeatureKind.bamboo, 7, 0),
      Feature(FeatureKind.gong, 0, 0),
    ],
    quips: [
      '계산 밖의 회심… 기록해 두겠습니다.',
      '오차 0.1 이내. 훌륭합니다.',
      '확률 3% 의 수를 두셨군요.',
      '제 계산이 틀렸습니다. 다시 계산하지요.',
      '예상대로입니다.',
      '청죽의 각도를 읽지 못하셨군요.',
    ],
    intro: [
      ('로직', '모든 수는 계산할 수 있습니다. 당신의 다음 수도요.'),
      ('로직', '대리석 위에서는 작은 각도 하나가 승부를 가릅니다.'),
      ('로직', '양쪽 청죽은 맞은 돌을 1.5배로 튕겨 내고, 가운데 경종을 울리면 둘레 상대 돌이 밀려납니다.'),
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
    difficulty: Difficulty.skilled,
    style: AiStyle.master,
    martial: Technique.clone,
    bossQi: 3,
    needStage: 5,
    weather: Weather.frost,
    quips: [
      '…그 회심, 사부를 닮았군.',
      '얼어붙은 판에서도 손이 떨리지 않는구나.',
      '분신으로도 막을 수 없는가…',
      '이번엔… 끝을 낼 줄 알았는데.',
      '분신은 둘이다. 너는 하나지.',
      '혹한에선 세 번째 충돌이 마지막이다.',
    ],
    intro: [
      ('해설', '혹한의 밤. 부딪힐수록 돌이 얼어붙어 무거워지고, 세 번째 충돌에서는 그 자리에 멈춘다.'),
      ('묵현', '대회 전날 밤이다. 살수의 분신까지 익혔다. 이번엔 끝을 내자.'),
    ],
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
    shiftingFloor: true,
    quips: [
      '좋은 회심이다. 사제가 잘 가르쳤구나.',
      '용린석이 떨고 있다. 너 때문이다.',
      '한 수에 둘이라… 천하제일의 자격이 있다.',
      '허, 이 늙은이를 땀 흘리게 하는구나.',
      '내공은 이렇게 쓰는 것이다.',
      '불꽃 바닥에선 멈추고, 빙판에선 멀어진다. 잊지 마라.',
    ],
    intro: [
      ('맹주', '사제의 기명석을 가진 아이로구나. 용린석이 너를 기다렸다.'),
      ('맹주', '빙판 위에서는 한 번의 실수가 판 밖이다. 내공을 아끼지 마라.'),
      ('해설', '본단 바닥은 한 수마다 빙판과 불꽃 바닥이 번갈아 바뀐다. 불꽃 바닥에서는 돌이 빨리 멈춘다.'),
    ],
    outro: [
      ('맹주', '훌륭하다. 이 용린석을 기명석에 끼워라.'),
      ('해설', '네 번째 문양 — 탄지신통이 완성된다. 천하가 네 손끝을 안다.'),
      ('맹주', '탄지는 끝이 없다. 서쪽 열사의 협곡 너머 하늘 끝에, 알까기의 신이 계신다 하더구나.'),
      ('맹주', '천하제일이 끝이 아니다. 가서 그분께 네 손끝을 보여 드려라.'),
    ],
  ),
  // 2026-10-28 형 「새로운 이야기도 지금 6개에서 10개로 맞춰주고 10단계는 보스로만 구성한 단계로 마지막은
  // 알까기 신이 등장하도록」: 7~9장 새 땅(사막·바다·화산) → 10장 천상 탄신전.
  Stage(
    id: 'c7',
    chapter: 7,
    title: '7장 · 열사의 협곡',
    arena: Arena.sandCanyon,
    boss: '사막왕',
    material: StoneMaterial.granite,
    shape: StoneShape.round,
    difficulty: Difficulty.skilled,
    style: AiStyle.ram,
    martial: Technique.stomp,
    bossQi: 2,
    needStage: 7,
    weather: Weather.gale,
    quips: [
      '모래바람보다 매서운 회심이로군!',
      '협곡이 네 이름을 기억하겠다.',
      '둘이나! 사막의 신기루인가?',
      '내 반석이 모래처럼 흩어지다니…',
      '모래에 발이 묶이면 끝이다!',
      '반석은 꿈쩍도 않는다. 사막처럼!',
    ],
    intro: [
      ('해설', '끝없는 붉은 협곡. 모래폭풍이 5초마다 방향을 바꾸고, 판 양쪽의 유사는 지나가는 돌을 붙잡는다.'),
      ('사막왕', '하늘로 가는 길은 이 협곡뿐이다. 통행료는 네 돌이다!'),
      ('사막왕', '내 반석 돌은 무겁고 멈추지 않는다. 정면으로 받아 보겠느냐?'),
    ],
    outro: [
      ('사막왕', '허허… 모래가 네 편을 들었구나. 좋다, 바다로 가는 길을 열어 주마.'),
      ('해설', '협곡 끝, 검은 돛을 단 거대한 배가 모래 바다 너머 진짜 바다에 떠 있다.'),
    ],
  ),
  Stage(
    id: 'c8',
    chapter: 8,
    title: '8장 · 흑룡 해적선',
    arena: Arena.pirateDeck,
    boss: '해적왕',
    material: StoneMaterial.hyeoncheol,
    shape: StoneShape.sphere,
    difficulty: Difficulty.skilled,
    style: AiStyle.spinner,
    martial: Technique.taiji,
    bossQi: 2,
    needStage: 7,
    weather: Weather.nightRain,
    quips: [
      '크하하! 그 회심, 대포알 같구나!',
      '갑판 청소는 네가 해 주는 거냐?',
      '둘을 한꺼번에 바다로! 해적질 좀 해 봤구나?',
      '내 술통이… 내 배가…!',
      '태극으로 휘어지는 돌, 피할 수 있겠느냐!',
      '파도는 늘 내 편이지!',
    ],
    intro: [
      ('해설', '폭풍우 치는 밤바다. 젖은 갑판은 잘 미끄러지고, 양옆 뱃전은 막혀 돌이 되튀어 들어온다.'),
      ('해적왕', '크하하! 하늘로 가는 뱃삯은 비싸다. 이 갑판에서 날 이기면 태워 주지!'),
      ('해설', '갑판의 술통은 맞으면 더 세게 튕겨 낸다. 돛대는 느리게 돌며 돌을 엇나가게 한다.'),
    ],
    outro: [
      ('해적왕', '바다 사나이는 진 건 진 거다. 화염산 앞바다까지 태워 주마!'),
      ('해설', '수평선 너머, 하늘을 찌르는 화산이 붉게 타오른다.'),
    ],
  ),
  Stage(
    id: 'c9',
    chapter: 9,
    title: '9장 · 화염산',
    arena: Arena.lavaCave,
    boss: '염마녀',
    material: StoneMaterial.jageum,
    shape: StoneShape.round,
    difficulty: Difficulty.hard,
    style: AiStyle.master,
    martial: Technique.swordQi,
    bossQi: 3,
    needStage: 8,
    quips: [
      '호호, 불꽃보다 뜨거운 회심이네.',
      '이 열기 속에서도 손이 떨리지 않다니.',
      '둘이나 용암에…! 제법이구나.',
      '내 불꽃이… 꺼진다고?',
      '용암 구멍 가까이 서지 마. 녹아 버릴 테니.',
      '불길은 멈추지 않아. 검기처럼!',
    ],
    intro: [
      ('해설', '화염산 깊은 용암굴. 판 양쪽의 용암 구멍은 둘레의 돌을 끌어당기고, 한가운데에 닿으면 그대로 장외다.'),
      ('염마녀', '하늘 문은 내 불꽃 뒤에 있어. 열고 싶다면 날 넘어 봐.'),
      ('염마녀', '자금석에 불꽃 검기를 실어 주지. 타지 않게 조심해!'),
    ],
    outro: [
      ('염마녀', '…네 손끝은 불보다 맑구나. 하늘 문을 열어 줄게.'),
      ('해설', '용암이 갈라지며 구름 계단이 하늘로 이어진다. 기명석의 네 문양이 한꺼번에 떨린다.'),
    ],
  ),
  Stage(
    id: 'c10',
    chapter: 10,
    title: '10장 · 천상 탄신전',
    arena: Arena.heavenTemple,
    boss: '알까기 신',
    material: StoneMaterial.taegeuk,
    shape: StoneShape.sphere,
    difficulty: Difficulty.hard,
    style: AiStyle.master,
    martial: Technique.clone,
    bossQi: 3,
    needStage: 8,
    shiftingFloor: true,
    quips: [
      '오오… 그것이 사람의 회심이구나.',
      '천 년 만에 보는 맑은 손끝이다.',
      '한 수에 둘이라. 하늘도 놀라겠구나.',
      '내가… 밀린다는 것인가.',
      '탄지는 마음이다. 마음이 흔들리면 돌도 흔들린다.',
      '구름 위에서는 모든 돌이 가볍다.',
    ],
    intro: [
      ('해설', '구름 바다 위에 떠 있는 탄신전. 바닥은 한 수마다 얼음처럼 미끄러웠다가 불처럼 붙잡는다.'),
      ('알까기 신', '아홉 고수를 다시 넘어 여기까지 왔구나. 기명석의 주인이여.'),
      ('알까기 신', '나는 처음으로 돌을 튕긴 손가락이다. 태극석으로 상대해 주마. 마음을 다해 튕겨라.'),
    ],
    outro: [
      ('알까기 신', '…훌륭하다. 이제 너의 손끝이 하늘의 손끝이다.'),
      ('해설', '태극석이 기명석에 녹아든다. 네 문양이 하나로 이어져 해처럼 환하게 빛난다.'),
      ('알까기 신', '땅으로 돌아가거라. 알까기는 하늘이 아니라 마당에서 두는 것이다.'),
    ],
  ),
];

/// 기명석 문양 넷(설계서 §2.6 · §16.1): (이 판을 처음 깨면 깨어남, 이름, 한 줄).
/// 2026-10-13 형 「스토리·연출·감동 점검」: 대사로만 「문양이 빛난다」 하고 화면에 보이지 않았다.
const glyphs = [
  ('c1', '각성', '네 안에 잠든 무공이 깨어났다'),
  ('c4', '동행', '함께 걷는 이가 생겼다'),
  ('c5', '어기', '마음의 선으로 돌을 꺾는다'),
  ('c6', '신통', '탄지신통이 완성되었다'),
];

/// [stageId] 를 깨면 깨어나는 문양 번호(0~3). 문양이 없는 판이면 null.
int? glyphOf(String stageId) {
  final i = glyphs.indexWhere((g) => g.$1 == stageId);
  return i < 0 ? null : i;
}

/// 맺음(마지막 장 · 10장을 처음 깨면 한 번): 촌장과 묵현의 이야기를 끝맺는다.
/// 1장에서 묵현을 막으러 남은 촌장이 어떻게 됐는지, 마음을 돌린 묵현이 어디로 갔는지 나오지 않았다.
/// 2026-10-28 이야기가 10장으로 늘어 6장 → 10장(알까기 신) 뒤로 옮겼다.
const List<Line> epilogue = [
  ('해설', '알까기 신과의 한 판이 끝나고 석 달. 너는 구름 계단을 내려와 흙먼지 마을로 돌아왔다.'),
  ('해설', '공터 한가운데, 지팡이를 짚은 촌장이 돌판을 닦고 있다.'),
  ('촌장', '…왔느냐. 그날 밤 묵현을 막다 다리를 좀 다쳤지만, 보다시피 멀쩡하다.'),
  ('촌장', '천하제일이라고? 허허, 소문은 여기까지 들렸다. 손끝은 그대로구나.'),
  ('해설', '마을 어귀에서 낯익은 발소리. 묵현이 고개를 숙이고 서 있다.'),
  ('묵현', '사부… 돌을 빼앗으려던 이 손으로, 처음부터 다시 배우고 싶습니다.'),
  ('촌장', '탄지는 마음으로 튕기는 것이다. 이제야 네 마음이 돌아왔구나.'),
  ('묵현', '다음엔 이기려고 두지 않겠다. 즐기려고 두겠다.'),
  ('촌장', '자, 셋이서 한 판 두자. 오늘은 내기도 없고, 문파도 없다.'),
  ('해설', '기명석의 네 문양이 한꺼번에 따뜻하게 빛난다. 탄지무림 — 끝.'),
];

/// 고수의 첫 대사는 내가 고른 캐릭터에 따라 바뀐다(설계서 §16.1). 장마다 앞 대사 맨 앞에 붙는다.
String heroGreeting(String heroLabel, String trait) {
  final kind = trait.split(' · ').first;
  final last = heroLabel.codeUnitAt(heroLabel.length - 1);
  final batchim = last >= 0xAC00 && last <= 0xD7A3 && (last - 0xAC00) % 28 != 0;
  return '「$kind」 $heroLabel${batchim ? '이라' : '라'}… 소문은 들었다. 어디 손끝을 보자.';
}

/// 장을 깨면 열리는 캐릭터 (설계서 §16.3).
const unlockByStage = {
  'c2': 'banDal',
  'c4': 'gurumi',
  'c5': 'jeonggak',
  'c6': 'yonga',
};
