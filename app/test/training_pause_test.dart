import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/progress/store.dart';
import 'package:alkkagi/screens/training_screen.dart';
import 'package:alkkagi/ui/theme.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 2026-10-14 형 「목인항 수련하다가 중지하면 저장되게 해줘」.
// 다른 목인항 시험과 파일을 나눈다: 앞 시험이 끝날 때 건 저장이 그 시험의 시계와 함께 멈춰 남으면
// 뒤 저장들이 그 뒤에 줄을 서 끝나지 않는다(앱에서는 없는 시험 환경만의 일).
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializePhysics();
  });

  testWidgets('목인항: 중지(일시정지)하면 저장 · 나가기는 진 판이 아님 · 앱을 내려도 저장', (t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    ProfileStore.instance.profile = Profile()
      ..tutorialDone = true
      ..seenHints.add('training')
      ..naegong = 4321;
    // 저장은 시험 시계 안에서 돌아 화면을 그려야 끝난다 → 기다림과 그리기를 번갈아 한 뒤 읽는다.
    Future<double> saved() async {
      for (var i = 0; i < 3; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await t.pump();
      }
      double? v;
      await t.runAsync(() async {
        final prefs = await SharedPreferences.getInstance();
        v = Profile.decode(prefs.getString('profile.v1')!).naegong;
      });
      return v!;
    }

    await t.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const TrainingScreen()),
    );
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.tap(find.byKey(const Key('pause')));
    await t.pump();
    expect(await saved(), 4321);
    expect(find.textContaining('수련 저장됨 · '), findsOneWidget);
    await t.tap(find.byKey(const Key('quit')));
    await t.pump();
    expect(find.textContaining('정말 나가기'), findsWidgets);
    expect(find.textContaining('진 판'), findsNothing);
    // 앱을 내리면(홈 단추·전화 등) 그때도 저장.
    ProfileStore.instance.profile.naegong = 5555;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(await saved(), 5555);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpWidget(const SizedBox());
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  });
}
