import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/screens/more_sheet.dart';

/// 로비 「더보기」(2026-10-19): 기능을 숨기지 않고 모두 보여 주고, 잠긴 것은 여는 법을 알린다.
void main() {
  Future<List<Widget>> show(WidgetTester t, Profile p) async {
    final opened = <Widget>[];
    await t.binding.setSurfaceSize(const Size(420, 1400));
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoreSheet(profile: p, open: opened.add),
        ),
      ),
    );
    await t.pump();
    return opened;
  }

  testWidgets('열한 가지가 다 보이고 처음엔 환생·기인방이 잠겨 있다', (t) async {
    final opened = await show(t, Profile());
    for (final k in [
      'free', 'puzzle', 'shop', 'depot', 'legend', 'codex', 'look', //
      'rebirth', 'odds', 'settings', 'credits',
    ]) {
      expect(find.byKey(Key('more-$k')), findsOneWidget, reason: k);
    }
    await t.tap(find.byKey(const Key('more-rebirth')));
    await t.pumpAndSettle();
    expect(find.textContaining('아직 잠겨 있어요'), findsOneWidget);
    expect(opened, isEmpty);
    await t.tap(find.text('알겠어요'));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('more-codex')));
    expect(opened, hasLength(1));
  });
}
