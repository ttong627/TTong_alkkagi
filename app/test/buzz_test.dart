import 'package:alkkagi/progress/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('가장 약한 부딪힘도 손에 느껴지는 진동(20ms 이상 · 세기 110 이상)', () async {
    Buzz.log.clear();
    Buzz.impact(0.05);
    expect(Buzz.log, isNotEmpty);
    final (ms, amp) = Buzz.log.last;
    expect(ms, greaterThanOrEqualTo(20));
    expect(amp, greaterThanOrEqualTo(110));
  });

  test('센 부딪힘은 더 길고 세다(최대 세기 255)', () async {
    Buzz.log.clear();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    Buzz.impact(1);
    final (ms, amp) = Buzz.log.last;
    expect(ms, 70);
    expect(amp, 255);
  });

  test('진동 세기 「강」은 더 세게 · 「약」은 약하게(최대 255)', () async {
    addTearDown(() => Settings.instance.vibeLevel = 1);
    int ampAt(double level) {
      Settings.instance.vibeLevel = level;
      Buzz.log.clear();
      Buzz.tick();
      return Buzz.log.last.$2;
    }

    expect(ampAt(1), 120);
    expect(ampAt(1.4), 168);
    expect(ampAt(0.6), 72);
    Settings.instance.vibeLevel = 1.4;
    Buzz.log.clear();
    Buzz.heavy();
    expect(Buzz.log.last.$2, 255, reason: '255 를 넘지 않는다');
  });

  test('진동을 끄면 아무것도 내지 않는다', () async {
    Settings.instance.vibration = false;
    addTearDown(() => Settings.instance.vibration = true);
    Buzz.log.clear();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    Buzz.impact(1);
    Buzz.tick();
    expect(Buzz.log, isEmpty);
  });
}
