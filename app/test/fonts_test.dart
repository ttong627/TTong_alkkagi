import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 앱 글자가 글꼴에 모두 있는지(없으면 □ 로 나온다). 새 기호·한자를 쓰면
/// `tool/make_fallback_font.py` 로 보충 글꼴을 다시 만든다.
///
/// 글꼴 파일의 cmap(글자표)을 직접 읽는다(외부 도구 없이).
Set<int> _cmap(String path) {
  final b = File(path).readAsBytesSync();
  int u16(int o) => (b[o] << 8) | b[o + 1];
  int u32(int o) =>
      (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
  final n = u16(4);
  var cmap = -1;
  for (var i = 0; i < n; i++) {
    final rec = 12 + i * 16;
    if (String.fromCharCodes(b.sublist(rec, rec + 4)) == 'cmap') {
      cmap = u32(rec + 8);
    }
  }
  final out = <int>{};
  final tables = u16(cmap + 2);
  for (var i = 0; i < tables; i++) {
    final off = cmap + u32(cmap + 4 + i * 8 + 4);
    final format = u16(off);
    if (format == 4) {
      final seg = u16(off + 6) ~/ 2;
      for (var s = 0; s < seg; s++) {
        final end = u16(off + 14 + s * 2);
        final start = u16(off + 16 + seg * 2 + s * 2);
        for (var c = start; c <= end && c != 0xFFFF; c++) {
          out.add(c);
        }
      }
    } else if (format == 12) {
      final groups = u32(off + 12);
      for (var g = 0; g < groups; g++) {
        final o = off + 16 + g * 12;
        for (var c = u32(o); c <= u32(o + 4); c++) {
          out.add(c);
        }
      }
    }
  }
  return out;
}

void main() {
  test('앱 문자열의 글자가 본문·제목 글꼴 또는 보충 글꼴에 모두 있다', () {
    final body = _cmap('assets/fonts/DoHyeon-Regular.ttf');
    final title = _cmap('assets/fonts/BlackHanSans-Regular.ttf');
    final fb = _cmap('assets/fonts/NotoSansKR-Fallback.ttf');
    final lit = RegExp(r"'([^'\\\n]*(?:\\.[^'\\\n]*)*)'");
    final missing = <String>{};
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      for (final m in lit.allMatches(f.readAsStringSync())) {
        for (final r in m.group(1)!.runes) {
          if (r <= 32) continue;
          final inBoth = body.contains(r) && title.contains(r);
          if (!inBoth && !fb.contains(r)) missing.add(String.fromCharCode(r));
        }
      }
    }
    expect(missing, isEmpty, reason: '글꼴에 없는 글자: ${missing.join()}');
  });
}
