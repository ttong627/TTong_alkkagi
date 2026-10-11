import 'package:alkkagi_physics/alkkagi_physics.dart';

/// 문파와 그 무공(설계서 §2.4).
const schools = [
  (Technique.swordQi, '검객'),
  (Technique.stomp, '권사'),
  (Technique.taiji, '도사'),
  (Technique.clone, '살수'),
];

String martialHelp(Technique t) {
  final what = switch (t) {
    Technique.swordQi => '첫 충돌 뒤 1초 동안 내 돌이 덜 멈춰 일직선으로 밀고 나갑니다',
    Technique.stomp => '첫 충돌 자리 둘레 4cm 의 다른 돌도 바깥으로 밀어냅니다',
    Technique.taiji => '부딪히기 전까지 손끝을 쓸어 간 쪽으로 궤적이 휩니다',
    Technique.clone => '한 수에 상대 돌 2개를 맞히면 내 돌이 둘로 나뉩니다(판당 1번)',
    _ => '',
  };
  return '$what · 평타로 한가운데를 알맞은 세기로 맞히면 「회심」, 내공 1칸이 찹니다';
}
