import 'dart:ui';

import 'package:alkkagi_physics/alkkagi_physics.dart';

/// 내공 타격의 금빛.
const innerColor = Color(0xFFFFD34D);

/// 궁극기 어기어석의 붉은 빛.
const ultimateColor = Color(0xFFFF4D6D);

/// 무공·스킬마다 빛깔.
Color techniqueColor(Technique t) => switch (t) {
  Technique.none => innerColor,
  Technique.swordQi => const Color(0xFF7FD4FF),
  Technique.stomp => const Color(0xFFFF8A3D),
  Technique.taiji => const Color(0xFFF2F2F2),
  Technique.clone => const Color(0xFFB07CFF),
  Technique.absorb => const Color(0xFF4DFFB8),
};

/// 꾸미기 잔상 빛깔(보급소·기인방). 모르는 이름이면 null(기본 흰빛).
Color? trailColor(String? name) => switch (name) {
  '불꽃' => const Color(0xFFFF7A2E),
  '금빛 잔상' => innerColor,
  '달맞이' => const Color(0xFFE8F0FF),
  '청죽' => const Color(0xFF5FE08A),
  '먹물' => const Color(0xFF444466),
  _ => null,
};
