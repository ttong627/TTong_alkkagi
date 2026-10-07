/// 앱 판 번호. CI 가 빌드할 때 `--dart-define` 으로 넣는다(빌드 번호 = 안드로이드 versionCode 의 바탕).
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');
const appBuild = String.fromEnvironment('APP_BUILD', defaultValue: '개발');

/// 화면에 보이는 판 표시. 예: v0.1.0 · 빌드 125
const versionLabel = 'v$appVersion · 빌드 $appBuild';
