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
