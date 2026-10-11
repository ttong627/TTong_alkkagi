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
}
