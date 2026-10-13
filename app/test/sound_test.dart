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
      for (final m in StoneMaterial.values) Sound.hitSound(m),
      for (final t in Technique.values)
        if (t != Technique.none) 'tech_${t.name}',
      for (final a in Arena.values) 'bgm_${a.name}',
      'bgm_lobby',
      'bgm_boss',
    };
    for (final n in want) {
      final f = File('assets/sounds/$n.ogg');
      expect(f.existsSync(), isTrue, reason: n);
      expect(f.lengthSync(), greaterThan(1000), reason: n);
    }
  });

  // 안드로이드 SoundPool 은 풀어 놓은 소리 하나를 1MB 까지만 담는다(넘으면 잘림 · 공식 문서).
  // 44.1kHz 16비트로 스테레오 약 5.9초, 모노 약 11.8초. 효과음·짧은 곡이 그 안에 있는지 지킨다(2026-10-11 점검).
  test('효과음은 SoundPool 한도(풀었을 때 1MB) 안 — 길이·채널을 OGG 머리에서 읽어 잰다', () {
    for (final n in Sound.effects) {
      final b = File('assets/sounds/$n.ogg').readAsBytesSync();
      final (ch, rate, samples) = _oggInfo(b);
      final decoded = samples * ch * 2;
      expect(
        decoded,
        lessThan(1000 * 1000),
        reason:
            '$n: ${ch}ch ${(samples / rate).toStringAsFixed(2)}초 → $decoded 바이트',
      );
    }
  });

  test('준비 전에는 소리를 내지 않아도 오류 없이 지나간다', () {
    Sound.play('critical');
    Sound.hit(StoneMaterial.ice, 50);
    Sound.slide(1);
    Sound.music(Arena.oilyTable);
    Sound.lobby();
    Sound.track(null);
  });
}

/// OGG Vorbis: 첫 머리에서 채널·표본 빠르기, 마지막 쪽의 granule 에서 전체 표본 수.
(int, int, int) _oggInfo(List<int> b) {
  int u32(int o) => b[o] | b[o + 1] << 8 | b[o + 2] << 16 | b[o + 3] << 24;
  // 첫 쪽 머리(27바이트 + 마디 표) 뒤 「\x01vorbis」 머리: 버전(4) 다음 채널(1) · 빠르기(4).
  final segs = b[26];
  final id = 27 + segs;
  expect(String.fromCharCodes(b.sublist(id + 1, id + 7)), 'vorbis');
  final ch = b[id + 11];
  final rate = u32(id + 12);
  // 마지막 「OggS」 쪽의 granule(6번째 바이트부터 8바이트) = 끝 표본 번호.
  var last = -1;
  for (var i = b.length - 4; i >= 0; i--) {
    if (b[i] == 0x4f &&
        b[i + 1] == 0x67 &&
        b[i + 2] == 0x67 &&
        b[i + 3] == 0x53) {
      last = i;
      break;
    }
  }
  final samples = u32(last + 6) + (u32(last + 10) << 32);
  return (ch, rate, samples);
}
