import 'package:flutter/foundation.dart';

/// 에뮬레이터 실제 시험(.github/workflows/flick-e2e.yml)용 판인가.
///
/// `--dart-define=E2E_FLICK=true` 로 빌드하면 켜자마자 연습 판을 열고 내 돌 하나를 골라
/// 가까이 보기 화면을 띄우며, 돌 자리와 쳐 낸 결과를 기록(logcat)에 남긴다. 보통 판에는 없다.
const bool e2eFlick = bool.fromEnvironment('E2E_FLICK');

/// 시험 판에서만 기록을 남긴다.
void e2eLog(String message) {
  if (e2eFlick) debugPrint('[E2E] $message');
}
