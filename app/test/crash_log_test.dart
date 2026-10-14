import 'package:alkkagi/progress/crash_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 2026-10-14 형 「갤럭시 울트라22 … 자꾸 튕기는 증상」: 다음에 켤 때 꺼진 까닭을 보여 주고 복사하게 한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('tanji/diag');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(ch, null);
  });

  test('비정상으로 꺼졌으면 까닭과 최근 앱 안 오류를 한 번만 보여 준다', () async {
    var time = 1000;
    var abnormal = true;
    messenger.setMockMethodCallHandler(
      ch,
      (call) async => {
        'time': time,
        'abnormal': abnormal,
        'text': '알까기 시험판 203 · samsung SM-S908N\n끝난 때 … · 까닭 네이티브 충돌',
      },
    );
    await CrashLog.note('Bad state: 시험 오류', StackTrace.current);
    final r = await CrashLog.pendingReport();
    expect(r, contains('네이티브 충돌'));
    expect(r, contains('SM-S908N'));
    expect(r, contains('시험 오류'));
    expect(await CrashLog.pendingReport(), isNull, reason: '같은 꺼짐은 한 번만');
    expect(await CrashLog.lastReport(), r, reason: '설정에서 다시 본다');
    time = 2000;
    abnormal = false;
    expect(await CrashLog.pendingReport(), isNull, reason: '정상으로 끝난 것은 안 보여 줌');
    time = 3000;
    abnormal = true;
    expect(await CrashLog.pendingReport(), isNotNull, reason: '새로 꺼지면 또');
  });

  test('앱 안 오류는 최근 5개 · 하나에 1,500자까지', () async {
    for (var i = 0; i < 8; i++) {
      await CrashLog.note('오류 $i ${'x' * 3000}', null);
    }
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('diag.dartErrors')!;
    expect(list, hasLength(CrashLog.keep));
    expect(list.first, contains('오류 3'));
    expect(list.every((e) => e.length <= CrashLog.maxLength), isTrue);
  });

  test('같은 오류가 되풀이되면 한 번만 적는다', () async {
    await CrashLog.note('되풀이 오류', null);
    await CrashLog.note('되풀이 오류', null);
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('diag.dartErrors')!;
    expect(list.where((e) => e.contains('되풀이 오류')), hasLength(1));
  });

  test('까닭을 읽지 못해도(채널 없음) 조용히 지나간다', () async {
    expect(await CrashLog.pendingReport(), isNull);
  });
}
