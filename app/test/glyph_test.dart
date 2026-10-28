import 'package:alkkagi/progress/profile.dart';
import 'package:alkkagi/progress/store.dart';
import 'package:alkkagi/screens/campaign_screen.dart';
import 'package:alkkagi/story/chapters.dart';
import 'package:alkkagi/ui/glyph_stone.dart';
import 'package:alkkagi/ui/theme.dart';
import 'package:alkkagi_physics/alkkagi_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _wait(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializePhysics();
  });

  test('기명석 문양 넷: 1·4·5·6장을 깨면 하나씩 깨어난다', () {
    expect(glyphs.map((g) => g.$1), ['c1', 'c4', 'c5', 'c6']);
    expect(glyphOf('c4'), 1);
    expect(glyphOf('r1'), isNull, reason: '숙적전은 문양이 없다');
    expect(GlyphStone.litFrom({'c1', 'c2', 'r1'}), {0});
    expect(GlyphStone.litFrom({'c1', 'c4', 'c5', 'c6'}), {0, 1, 2, 3});
    // 문양이 깨어나는 판의 뒤 대사에 그 문양 이야기가 있다(대사와 화면이 어긋나지 않게).
    for (final (id, _, _) in glyphs) {
      final s = campaign.firstWhere((s) => s.id == id);
      expect(
        s.outro.any((l) => l.$2.contains('문양')),
        isTrue,
        reason: '$id 뒤 대사',
      );
    }
  });

  test('맺음: 촌장과 묵현이 돌아와 이야기를 끝맺는다 · 알까기 신(10장) 뒤', () {
    final who = epilogue.map((l) => l.$1).toSet();
    expect(who, containsAll(['촌장', '묵현']));
    expect(epilogue.last.$2, contains('끝'));
    expect(epilogue.first.$2, contains('알까기 신'));
  });

  testWidgets('강호행 맨 위에 기명석 — 깬 장만큼 문양 수', (t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    ProfileStore.instance.profile = Profile()
      ..tutorialDone = true
      ..seenHints.add('campaign')
      ..done.addAll(['c1', 'c2', 'r1', 'c3', 'c4']);
    await t.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const CampaignScreen()),
    );
    await _wait(t);
    expect(find.byKey(const Key('glyph-row')), findsOneWidget);
    expect(find.text('기명석 · 문양 2/4'), findsOneWidget);
    expect(find.textContaining('다음 문양 — 5장'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await _wait(t);
  });

  testWidgets('문양 각성 장면: 이름이 뜨고 누르면 닫힌다', (t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => showGlyphAwaken(c, index: 2, lit: {0, 1}),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await t.tap(find.text('열기'));
    await _wait(t, 1600);
    // OutlinedText 는 테두리·속 두 겹이라 같은 글이 둘 잡힌다.
    expect(find.text('3번째 문양'), findsWidgets);
    expect(find.text('어기'), findsWidgets);
    await t.tap(find.byKey(const Key('glyph-awaken')));
    await _wait(t);
    expect(find.byKey(const Key('glyph-awaken')), findsNothing);
  });
}
