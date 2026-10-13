import 'package:alkkagi/game/fx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('보통 손으로 맞힌 한 방(42~58cm/s)도 「퍽!」·멈칫·번쩍 단계', () {
    // 설계서 §16.16 실측: 손가락 500px/s → 42cm/s · 700px/s → 58cm/s.
    expect(ImpactTier.of(42), ImpactTier.strong);
    expect(ImpactTier.of(58), ImpactTier.strong);
  });

  test('아주 센 충돌은 「쾅!」 · 살짝 닿으면 먼지만', () {
    expect(ImpactTier.of(75), ImpactTier.huge);
    expect(ImpactTier.of(120), ImpactTier.huge);
    expect(ImpactTier.of(20), ImpactTier.mid);
    expect(ImpactTier.of(5), ImpactTier.light);
  });
}
