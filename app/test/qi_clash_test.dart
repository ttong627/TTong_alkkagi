import 'package:alkkagi/audio/sound.dart';
import 'package:alkkagi/game/match.dart';
import 'package:alkkagi/screens/qi_clash.dart';
import 'package:alkkagi/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('내공 겨루기: 대치·셋둘하나 뒤에 시작 · 먼저 두드린 것은 세지 않는다', (t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    (int, int)? done;
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: QiClashOverlay(
          opponent: '묵현',
          aiTaps: 20,
          onDone: (a, b) => done = (a, b),
        ),
      ),
    );
    final area = find.byKey(const Key('qi-clash'));
    // 대치 중에 두드림 → 「아직!」, 세지 않음.
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(area);
    await t.pump();
    expect(find.textContaining('아직'), findsWidgets);
    // 셋 · 둘 · 하나.
    await t.pump(const Duration(milliseconds: 1000));
    expect(find.text('셋'), findsWidgets);
    await t.pump(const Duration(milliseconds: 550));
    expect(find.text('둘'), findsWidgets);
    await t.pump(const Duration(milliseconds: 550));
    expect(find.text('하나'), findsWidgets);
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('시작!'), findsWidgets);
    for (var i = 0; i < 25; i++) {
      await t.tap(area);
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pump(Duration(milliseconds: (QiClash.seconds * 1000).round()));
    await t.pump(const Duration(milliseconds: 1200));
    expect(done, isNotNull);
    expect(done!.$1, 25, reason: '시작 뒤에 두드린 것만');
    expect(done!.$2, 20);
  });

  // 2026-10-14 형 「빠르게 클릭 외에 몇 가지 겨루기를 추가해서 너무 지겹고 지루하지 않게」.
  testWidgets('때 맞추기: 막대가 뜨고, 세 번 누르면 시간이 남아도 끝난다', (t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    (int, int)? done;
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: QiClashOverlay(
          opponent: '묵현',
          aiTaps: 2,
          game: ClashGame.timing,
          onDone: (a, b) => done = (a, b),
        ),
      ),
    );
    await t.pump(
      Duration(milliseconds: (QiClashOverlay.readyTotal * 1000 + 700).round()),
    );
    expect(find.byKey(const Key('clash-timing')), findsOneWidget);
    expect(find.textContaining('남은 기회 3번'), findsWidgets);
    final area = find.byKey(const Key('qi-clash'));
    for (var i = 0; i < 3; i++) {
      await t.tap(area);
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.pump(const Duration(milliseconds: 1300));
    expect(done, isNotNull, reason: '세 번 다 쓰면 바로 결과');
    expect(done!.$1, inInclusiveRange(0, 3));
    expect(done!.$2, 2);
  });

  testWidgets('기맥 잇기: 빛나는 점 화면이 뜬다', (t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: QiClashOverlay(
          opponent: '묵현',
          aiTaps: 3,
          game: ClashGame.chain,
          onDone: (_, _) {},
        ),
      ),
    );
    await t.pump(
      Duration(milliseconds: (QiClashOverlay.readyTotal * 1000 + 700).round()),
    );
    expect(find.byKey(const Key('clash-chain')), findsOneWidget);
    expect(find.textContaining('이은 기맥 0 / 5'), findsWidgets);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('내공 겨루기 동안 bgm_clash · 닫히면 원래 곡으로', (t) async {
    Sound.track('bgm_boss');
    addTearDown(() => Sound.track(null));
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: QiClashOverlay(
          opponent: '묵현',
          aiTaps: 20,
          onDone: (_, _) {},
          fast: true,
        ),
      ),
    );
    expect(Sound.current, 'bgm_clash');
    await t.pumpWidget(const SizedBox());
    expect(Sound.current, 'bgm_boss');
  });
}
