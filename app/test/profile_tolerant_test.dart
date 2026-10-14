import 'dart:convert';

import 'package:alkkagi/progress/profile.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-10-14 점검: 저장의 칸 하나만 형식이 틀려도 진행 전체를 버리고 새로 시작했다.
void main() {
  test('형식이 틀린 칸은 기본값으로 읽고 나머지 진행은 살린다', () {
    final good = Profile()
      ..tokens = 7
      ..naegong = 321
      ..done.add('c1');
    final j = jsonDecode(good.encode()) as Map<String, Object?>;
    j['coins'] = '많음';
    j['stats'] = [1, 2];
    j['codex'] = 'x';
    j['perks'] = [1, '회전 숙련'];
    j['tutorial'] = 'yes';
    j['trail'] = 3;
    final p = Profile.decode(jsonEncode(j));
    expect(p.tokens, 7);
    expect(p.naegong, 321);
    expect(p.done, contains('c1'));
    expect(p.coins, 0);
    expect(p.perks, {'회전 숙련'});
  });
}
