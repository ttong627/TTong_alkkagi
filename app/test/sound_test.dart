import 'dart:io';

import 'package:alkkagi/audio/sound.dart';
import 'package:alkkagi/game/arena.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('부르는 소리 파일이 모두 있다(효과음·재질 충돌·무공·장마다 배경 음악)', () {
    final want = {
      ...Sound.effects,
      'slide',
      for (final m in StoneMaterial.values) 'hit_${m.name}',
      for (final t in Technique.values)
        if (t != Technique.none) 'tech_${t.name}',
      for (final a in Arena.values) 'bgm_${a.name}',
    };
    for (final n in want) {
      final f = File('assets/sounds/$n.wav');
      expect(f.existsSync(), isTrue, reason: n);
      expect(f.lengthSync(), greaterThan(1000), reason: n);
    }
  });

  test('준비 전에는 소리를 내지 않아도 오류 없이 지나간다', () {
    Sound.play('critical');
    Sound.hit(StoneMaterial.ice, 50);
    Sound.slide(1);
    Sound.music(Arena.oilyTable);
  });
}
