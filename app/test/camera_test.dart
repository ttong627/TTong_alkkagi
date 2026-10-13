import 'package:alkkagi/game/camera.dart';
import 'package:flutter/widgets.dart' show MatrixUtils;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const origin = Offset(200, 300);
  const scale = 7.0;

  test('기울이고 당겨도 화면 자리 → 판 자리가 정확히 되돌아온다(돌 고르기·어기어석)', () {
    final c = BattleCamera()
      ..zoom = 1.45
      ..tilt = 0.4
      ..roll = 0.02
      ..focus = const Offset(6, -4);
    final m = c.matrix(origin, scale);
    for (final p in const [
      Offset(0, 0),
      Offset(10, 12),
      Offset(-20, 18),
      Offset(15, -22),
    ]) {
      final before = origin + p * scale;
      final shown = MatrixUtils.transformPoint(m, before);
      final back = BattleCamera.unproject(m, shown);
      expect((back - before).distance, lessThan(1e-6), reason: '$p');
    }
  });

  test('쏘면 당기고 눕히며, 다 멈추면 처음 모습으로 돌아온다', () {
    final c = BattleCamera()..onShot(const Offset(5, 10));
    for (var i = 0; i < 10; i++) {
      c.update(1 / 60, const [(Offset(5, 8), 100.0)]);
    }
    expect(c.zoom, greaterThan(1.05));
    expect(c.tilt, greaterThan(0.05));
    for (var i = 0; i < 60 * 4; i++) {
      c.update(1 / 60, const []);
    }
    expect(c.settled, isTrue);
  });

  test('돌이 판 끝까지 퍼지면 당기지 않는다 · 가운데는 판 밖을 많이 보이지 않게 묶인다', () {
    final c = BattleCamera();
    for (var i = 0; i < 240; i++) {
      c.update(1 / 60, const [(Offset(-22, 0), 50.0), (Offset(22, 0), 50.0)]);
    }
    expect(c.zoom, closeTo(1, 0.05));
    final d = BattleCamera();
    for (var i = 0; i < 240; i++) {
      d.update(1 / 60, const [(Offset(24, 24), 60.0)]);
    }
    final lim = BattleCamera.halfView - BattleCamera.halfView / d.zoom;
    expect(d.focus.dx, lessThanOrEqualTo(lim + 1e-6));
  });

  test('끄면 늘 처음 모습', () {
    final c = BattleCamera()..enabled = false;
    c.onShot(const Offset(5, 5), big: true);
    c.update(1 / 60, const [(Offset(5, 5), 120.0)]);
    expect(c.settled, isTrue);
    expect(c.letterbox, 0);
  });
}
