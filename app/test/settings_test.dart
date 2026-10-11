import 'package:alkkagi/game/flick.dart';
import 'package:alkkagi/progress/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('손맛 보정: 세기 기준 1,500화소/초 × (1 ± 30%)', () {
    final s = Settings.instance;
    s.feel = 0.3;
    expect(s.tuning.fullPxPerSec, closeTo(1950, 1e-9));
    s.feel = -0.3;
    expect(s.tuning.fullPxPerSec, closeTo(1050, 1e-9));
    s.feel = 0;
    expect(identical(s.tuning, StrikeTuning.standard), isTrue);
    // 같은 손 빠르기(1,000화소/초)라도 보정이 + 면 덜 세다.
    expect(
      strikePower(1000, const StrikeTuning(fullPxPerSec: 1950)),
      lessThan(strikePower(1000)),
    );
  });

  test('위아래 타격점을 끄면 넓이를 판단에 쓰지 않는다', () {
    final s = Settings.instance..hitArea = false;
    for (var i = 0; i < 100; i++) {
      s.touchProfile.add(10 + i % 7);
    }
    expect(s.touchProfile.range, isNull);
    expect(s.touchProfile.hitFor(20), isNull);
    s.hitArea = true;
    expect(identical(s.touchProfile, TouchProfile.shared), isTrue);
  });

  test('저장 모양 되읽기 · 깨진 값은 범위 안으로', () {
    final s = Settings.instance;
    s.apply({
      'sfx': 0.3,
      'music': 2,
      'vibration': false,
      'feel': -1,
      'hitArea': false,
      'leftHanded': true,
    });
    expect(s.sfx, 0.3);
    expect(s.music, 1);
    expect(s.vibration, isFalse);
    expect(s.feel, Settings.feelMin);
    expect(s.leftHanded, isTrue);
    final j = s.toJson();
    s.apply({});
    expect(s.vibration, isTrue);
    s.apply(j);
    expect(s.hitArea, isFalse);
    s.apply({});
  });

  test('평소 넓이 기록을 되살리고 지운다', () {
    final p = TouchProfile(keep: 5);
    p.restore([1, 2, 3, 4, 5, 6, 7, double.nan, -1]);
    expect(p.areas, [3, 4, 5, 6, 7]);
    p.clear();
    expect(p.count, 0);
  });
}
