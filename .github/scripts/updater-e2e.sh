#!/usr/bin/env bash
# 에뮬레이터 안에서: 빌드 1 설치 → 켜기 → 사람 손 없이 빌드 2 로 바뀌는지 본다.
# 사용: updater-e2e.sh <v1.apk> <빌드 2 의 versionCode>
set -u
PKG=TTong.alkkagi
V1="$1"; WANT="$2"
code() { adb shell dumpsys package "$PKG" | sed -nE 's/.*versionCode=([0-9]+).*/\1/p' | head -1; }

adb install -r "$V1"
echo "설치된 판: $(code)"
# 처음 한 번 형이 켜는 「이 출처 허용」을 여기서는 명령으로 켠다.
adb shell appops set "$PKG" REQUEST_INSTALL_PACKAGES allow
adb logcat -c
adb shell am start -n "$PKG/.MainActivity"

for i in $(seq 1 90); do
  sleep 2
  NOW=$(code)
  if [ "$NOW" = "$WANT" ]; then
    echo "통과: 손대지 않고 versionCode $NOW 로 업데이트됨 ($((i * 2))초)"
    adb logcat -d | grep -iE "PackageInstaller|tanji|flutter" | tail -20
    exit 0
  fi
done
echo "실패: 3분 안에 업데이트되지 않음(지금 versionCode $(code), 바라는 값 $WANT)"
adb logcat -d | grep -iE "PackageInstaller|InstallResult|tanji|flutter|AndroidRuntime" | tail -80
exit 1
