import 'package:flutter/foundation.dart';

/// 에뮬레이터 실제 시험(.github/workflows/flick-e2e.yml)용 판인가.
///
/// `--dart-define=E2E_FLICK=true` 로 빌드하면 켜자마자 연습 판을 열고 내 돌 하나를 골라
/// 가까이 보기 화면을 띄우며, 돌 자리와 쳐 낸 결과를 기록(logcat)에 남긴다. 보통 판에는 없다.
const bool e2eFlick = bool.fromEnvironment('E2E_FLICK');

/// 자동 업데이트 실제 시험(.github/workflows/updater-e2e.yml)용 판인가. 보통은 입문을 마친 뒤에만
/// 업데이트를 확인하는데(입문 중 설치로 앱이 닫히지 않게), 시험 판은 새로 깐 채 켜자마자 확인한다.
const bool e2eUpdater = bool.fromEnvironment('E2E_UPDATER');

/// 시험 판에서만 기록을 남긴다.
void e2eLog(String message) {
  if (e2eFlick) debugPrint('[E2E] $message');
}

/// 연출 확인용: 켜자마자 내 돌 하나를 [e2eDemoMode] 방식으로 세게 쳐 본다(내공 가득).
/// `--dart-define=E2E_DEMO=inner` 처럼 방식 이름(plain·inner·absorb·ultimate)을 준다.
const String e2eDemoMode = String.fromEnvironment('E2E_DEMO');
