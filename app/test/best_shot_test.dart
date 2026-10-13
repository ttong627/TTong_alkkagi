import 'package:alkkagi/screens/game_screen.dart';
import 'package:alkkagi/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _result(int best) => MaterialApp(
  theme: buildTheme(),
  home: ResultOverlay(
    title: '승리!',
    won: true,
    stars: 2,
    coins: 0,
    best: best,
    character: null,
    onDone: () {},
  ),
);

void main() {
  testWidgets('결과 화면: 한 수에 둘 넘게 떨어뜨렸으면 「오늘의 한 수」', (t) async {
    await t.pumpWidget(_result(3));
    await t.pump(const Duration(milliseconds: 1900));
    expect(find.byKey(const Key('best-shot')), findsOneWidget);
    expect(find.text('오늘의 한 수 — 한 번에 3개!'), findsWidgets);
  });

  testWidgets('하나씩만 떨어뜨렸으면 자랑 줄은 없다', (t) async {
    await t.pumpWidget(_result(1));
    await t.pump(const Duration(milliseconds: 1900));
    expect(find.byKey(const Key('best-shot')), findsNothing);
  });
}
