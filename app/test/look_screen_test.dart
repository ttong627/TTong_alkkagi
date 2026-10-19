import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/progress/store.dart';
import 'package:alkkagi/screens/look_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 꾸미기(2026-10-19 새로): 내 무협 캐릭터 그림 + 잔상 고르기. 가진 잔상만 고를 수 있다.
void main() {
  testWidgets('가진 잔상만 고르고, 고른 잔상이 판 설정으로 간다', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.runAsync(ProfileStore.load);
    final p = ProfileStore.instance.profile
      ..hero = Fighter.yonga
      ..trails.add('청죽');
    await t.binding.setSurfaceSize(const Size(420, 1400));
    await t.pumpWidget(const MaterialApp(home: LookScreen()));
    await t.pump();

    for (final (name, _) in trailCatalog) {
      expect(find.byKey(Key('trail-$name')), findsOneWidget, reason: name);
    }
    expect(p.trailOrNull, isNull);

    // 못 가진 잔상은 눌러도 그대로.
    await t.tap(find.byKey(const Key('trail-먹물')));
    await t.pump();
    expect(p.trail, '기본');

    await t.tap(find.byKey(const Key('trail-청죽')));
    await t.pump();
    expect(p.trail, '청죽');
    expect(p.trailOrNull, '청죽');
  });
}
