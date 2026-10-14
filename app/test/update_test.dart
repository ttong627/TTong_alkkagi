import 'package:alkkagi/update/updater.dart';
import 'package:alkkagi/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('version.json 읽기', () {
    test('올바른 내용', () {
      final i = UpdateInfo.parse(
        '{"build":131,"apk":"https://github.com/ttong627/TTong_alkkagi/releases/download/test-latest/tanji-murim-test.apk","sha256":"${'ab' * 32}","size":3000000,"notes":"더 세게"}',
      )!;
      expect(i.build, 131);
      expect(i.sha256, 'ab' * 32);
      expect(i.size, 3000000);
      expect(i.notes, '더 세게');
      expect(i.newerThan(127), isTrue);
      expect(i.newerThan(131), isFalse, reason: '같은 빌드는 다시 깔지 않는다');
      expect(i.newerThan(140), isFalse);
    });
    test('깨진 내용·https 아닌 주소·빌드 번호가 수가 아님 → 무시', () {
      expect(UpdateInfo.parse('<html>404</html>'), isNull);
      expect(UpdateInfo.parse('{"build":5,"apk":"http://x/a.apk"}'), isNull);
      expect(UpdateInfo.parse('{"build":"5","apk":"https://x/a.apk"}'), isNull);
      expect(UpdateInfo.parse('[1,2]'), isNull);
    });
    test('지문·크기가 없거나 우리 릴리스 주소가 아니면 받지 않는다', () {
      const ok =
          'https://github.com/ttong627/TTong_alkkagi/releases/download/t/x.apk';
      final sha = 'ab' * 32;
      expect(UpdateInfo.parse('{"build":5,"apk":"$ok"}'), isNull);
      expect(
        UpdateInfo.parse('{"build":5,"apk":"$ok","sha256":"xyz","size":9}'),
        isNull,
      );
      expect(
        UpdateInfo.parse('{"build":5,"apk":"$ok","sha256":"$sha"}'),
        isNull,
      );
      // 깃허브라도 남의 저장소 릴리스는 받지 않는다(2026-10-14 점검).
      expect(
        UpdateInfo.parse(
          '{"build":5,"apk":"https://github.com/someone/else/releases/download/t/x.apk","sha256":"$sha","size":9}',
        ),
        isNull,
      );
      expect(
        UpdateInfo.parse(
          '{"build":5,"apk":"https://evil.example/x.apk","sha256":"$sha","size":9}',
        ),
        isNull,
      );
      expect(
        UpdateInfo.parse('{"build":5,"apk":"$ok","sha256":"$sha","size":9}'),
        isNotNull,
      );
    });
  });

  testWidgets('시험판이 아니면(개발·스토어 판) 업데이트를 하지 않고 알림 줄도 없다', (tester) async {
    final u = Updater();
    expect(u.enabled, isFalse, reason: '시험할 때 APP_CHANNEL 은 dev');
    await u.run();
    expect(u.stage, UpdateStage.idle);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: UpdateBanner(updater: u)),
      ),
    );
    expect(find.byType(Text), findsNothing);
    u.dispose();
  });

  testWidgets('단계마다 알림 줄 글', (tester) async {
    final u = Updater()
      ..target = const UpdateInfo(build: 131, apk: 'https://x/a.apk')
      ..stage = UpdateStage.downloading
      ..percent = 42;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: UpdateBanner(updater: u)),
      ),
    );
    expect(find.text('새 판(빌드 131) 받는 중 42%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    u.stage = UpdateStage.needsPermission;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: UpdateBanner(updater: u)),
      ),
    );
    expect(find.text('허용하러 가기'), findsOneWidget);
    u.dispose();
  });
}
