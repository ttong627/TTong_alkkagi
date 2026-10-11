import '../game/arena.dart';
import '../game/match.dart';

/// 묘수풀이는 모두 거북 장터 돌바닥(바닥 배수 1.0 · 네모 판)에서 한다.
const puzzleArena = Arena.turtleMarket;

/// 묘수풀이 (설계서 §8.1 목인항 퍼즐 · §5.3 은둔 고수). 내 돌은 layout 첫 번째(편 0).
class Puzzle {
  const Puzzle({
    required this.id,
    required this.title,
    required this.help,
    required this.shots,
    required this.layout,
    this.reward = 20,
  });
  final int id;
  final String title;
  final String help;

  /// 칠 수 있는 수.
  final int shots;
  final List<Placement> layout;

  /// 처음 풀면 수련 포인트.
  final int reward;
}

/// 목인항 묘수풀이. 가상 시험(test/puzzle_test.dart)으로 모두 풀 수 있음을 확인했다.
const puzzles = [
  Puzzle(
    id: 1,
    title: '일타쌍피',
    help: '한 번에 표적 두 개를 판 밖으로',
    shots: 1,
    layout: [
      Placement(0, 6, team: 0),
      Placement(-1.15, -17),
      Placement(1.15, -17),
    ],
  ),
  Puzzle(
    id: 2,
    title: '옆구리 치기',
    help: '두 번 쳐서 양쪽 끝 표적을 모두',
    shots: 2,
    layout: [Placement(0, 8, team: 0), Placement(-17, -3), Placement(17, -3)],
  ),
  Puzzle(
    id: 3,
    title: '삼재(三才)',
    help: '두 번 쳐서 표적 셋을 모두',
    shots: 2,
    layout: [
      Placement(0, 10, team: 0),
      Placement(0, -16),
      Placement(-1.15, -18),
      Placement(15, 0),
    ],
  ),
  Puzzle(
    id: 4,
    title: '오행(五行)',
    help: '두 번 쳐서 표적 다섯을 모두',
    shots: 2,
    reward: 40,
    layout: [
      Placement(0, 12, team: 0),
      Placement(0, -15),
      Placement(-1.15, -17),
      Placement(1.15, -17),
      Placement(-2.3, -19),
      Placement(2.3, -19),
    ],
  ),
];

/// 은둔 고수의 묘수풀이: 한 번에 돌 3개 떨어뜨리기 (설계서 §5.3).
const hermitPuzzle = Puzzle(
  id: 100,
  title: '은둔 고수의 시험',
  help: '한 번에 돌 셋을 모두 떨어뜨려라',
  shots: 1,
  reward: 0,
  layout: [
    Placement(0, 4, team: 0),
    Placement(0, -15),
    Placement(-1.15, -17),
    Placement(1.15, -17),
  ],
);
