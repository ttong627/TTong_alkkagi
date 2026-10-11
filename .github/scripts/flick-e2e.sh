#!/usr/bin/env bash
# 에뮬레이터 안에서: 시험 판(E2E_FLICK)을 켜고 adb 로 손끝 밀기를 넣어, 돌이 맞아 나가는지 본다.
# 사용: flick-e2e.sh <시험판.apk>
# 확인: ① 안드로이드 손끝 점(TouchFeed)으로 읽었는가(native=true) ② 가운데를 위로 밀면 −90° 근처
#       ③ 오른쪽 가장자리를 밀면 왼쪽으로 꺾임(< −100°) ④ 살살 밀어도 나감
#       ⑤ 돌 0.4R 앞에서 손을 떼는 튕기기도 맞음(flick=true, −90° 근처)
set -u
PKG=TTong.alkkagi
# adb 명령마다 시간 제한을 둔다 — 하나가 멈추면 단계 전체가 45분 시간 초과까지 기다린다(2026-10-11 첫 실행).
a() { timeout "${T:-30}" adb "$@"; }
echo "[단계] 부팅 확인"
for i in $(seq 1 90); do [ "$(a shell getprop sys.boot_completed | tr -d '\r')" = 1 ] && break; sleep 2; done
for i in $(seq 1 60); do a shell pm path android >/dev/null 2>&1 && break; sleep 2; done
# 앱 탓인지 가르기: 앱을 켜기 전 20초 동안 에뮬레이터가 살아 있는지 본다.
echo "[단계] 앱 없이 20초 유지 확인"
for i in $(seq 1 10); do
  sleep 2
  [ "$(timeout 10 adb get-state 2>/dev/null)" = device ] || {
    echo "실패: 앱을 켜기 전에 에뮬레이터가 꺼짐(앱과 무관)"; ls -la /tmp/android-runner/ 2>&1 | tail; exit 1; }
done
echo "앱 없이 20초 살아 있음"
# 몸짓 탐색 대신 3버튼 탐색(없는 이미지면 그냥 지나감).
a shell cmd overlay enable com.android.internal.systemui.navbar.threebutton >/dev/null 2>&1 || true
echo "[단계] 설치"
ok=0
for i in 1 2 3; do T=180 a install -r "$1" && { ok=1; break; }; echo "설치 다시 ($i)"; sleep 5; done
[ "$ok" = 1 ] || { echo "실패: 설치가 끝나지 않음"; exit 1; }
a logcat -c
# 원인 증거: 기기 기록을 끊길 때까지 파일로 받고, 실패하면 호스트 쪽(메모리 부족·에뮬레이터 프로세스)도 찍는다.
LOGF="${RUNNER_TEMP:-/tmp}/logcat.txt"
adb logcat -v time > "$LOGF" 2>&1 &
evidence() {
  echo "----- 기기 기록 마지막 120줄 -----"; tail -120 "$LOGF"
  echo "----- 에뮬레이터 프로세스 -----"; ps aux | grep -E "qemu|emulator" | grep -v grep | head
  echo "----- 호스트 메모리 -----"; free -m
  echo "----- 호스트 커널 기록(메모리 부족·강제 종료) -----"; sudo dmesg 2>/dev/null | grep -iE "oom|killed process|qemu|segfault|trap" | tail -20
  echo "----- 에뮬레이터 충돌 기록 -----"; ls -la /tmp/android-runner/ 2>&1 | tail; find /tmp/android-runner -type f 2>/dev/null | head
  echo "----- 그리기 엔진 -----"; grep -iE "impeller|skia|rendering backend" "$LOGF" | tail -5
  echo "----- 앱 기록(flutter·충돌) -----"; grep -E "flutter|AndroidRuntime|FATAL|TTong.alkkagi|DEBUG  " "$LOGF" | tail -60
}
trap 'st=$?; [ "$st" != 0 ] && evidence; exit $st' EXIT
echo "[단계] 앱 켜기"
# 앱 화면(가까이 보기)이 뜬 지 2초쯤 뒤 에뮬레이터가 꺼졌다(2026-10-11 안드로이드 34·30 기록). 그리기 엔진
# Impeller 를 이 시험에서만 끄고(엔진이 읽는 실행 인자) 옛 Skia 로 그린다. 기록의 「Using the Impeller」 줄로 확인.
a shell am start -n "$PKG/.MainActivity" --ez enable-impeller false
a shell dumpsys meminfo | head -5

disc() { a logcat -d -s flutter:I | grep -o 'disc cx=[0-9]* cy=[0-9]* r=[0-9]*' | tail -1; }
# 에뮬레이터가 끊기면(첫 실행: 앱을 켜고 72초 뒤 「waiting for device」) 바로 실패로 끝낸다.
alive() { [ "$(timeout 10 adb get-state 2>/dev/null)" = device ]; }
D=""
END=$((SECONDS + 150))
while [ "$SECONDS" -lt "$END" ]; do
  sleep 2
  alive || { echo "실패: 에뮬레이터 연결이 끊김"; timeout 10 adb devices; exit 1; }
  D=$(disc); [ -n "$D" ] && break
done
sleep 3; D=$(disc) # 화면이 커지는 연출(0.38초) 동안 찍힌 자리가 아니라 다 커진 뒤 자리.
if [ -z "$D" ]; then
  echo "실패: 가까이 보기 화면이 뜨지 않음"; exit 1
fi
CX=$(echo "$D" | sed -E 's/.*cx=([0-9]+).*/\1/'); CY=$(echo "$D" | sed -E 's/.*cy=([0-9]+).*/\1/'); R=$(echo "$D" | sed -E 's/.*r=([0-9]+).*/\1/')
echo "돌 자리(화소): 가운데 ($CX, $CY), 반지름 $R"
SIZE=$(a shell wm size | tr -d '\r' | grep -o '[0-9]*x[0-9]*' | tail -1)
H=${SIZE#*x}
echo "화면 $SIZE"
# 손끝은 화면 안에서 시작해야 들어간다(2026-10-11: 화면 높이 640 인데 y=661 에서 시작한 두 번이 통째로 빠짐).
# 아래 가장자리에서 시작하면 안드로이드 14 의 「홈으로」 몸짓이 손끝을 가로챈다(2026-10-11: y=636 → 앱이 뒤로 감).
low() { local y=$((CY + $1 * R)); [ "$y" -gt $((H - 70)) ] && y=$((H - 70)); echo "$y"; }
echo "[단계] 손끝 밀기"

shots() { a logcat -d -s flutter:I | grep -c '\[E2E\] shot'; }
discs() { a logcat -d -s flutter:I | grep -c '\[E2E\] disc'; }
# $1 = 지금까지 쏜 수 → 하나 늘 때까지(최대 8초) 기다린 뒤, 돌이 멈추고 다음 돌의 가까이 보기가 새로 뜰 때까지
# (새 disc 줄 · 최대 30초) 기다린다. 예전엔 6초만 쉬어, 돌이 늦게 멈춘 판(안드로이드 34 · 2026-10-11)에서 다음
# 밀기가 가까이 보기가 뜨기 0.7초 전에 들어가 판 화면을 눌렀다.
# ⚠️ 새로 뜬 직후의 disc 줄은 커지는 연출 도중 자리라(168,427 · 135,367 …) 쓰지 않는다 — 가까이 보기는
# 늘 화면 같은 자리(처음 잰 CX·CY)에 다 커진다. 그 줄로 자리를 옮겼다가 튕기기가 돌 안에서 떼어졌다.
wait_shot() {
  local before; before=$(discs)
  for i in $(seq 1 40); do sleep 0.2; [ "$(shots)" -gt "$1" ] && break; done
  for i in $(seq 1 150); do sleep 0.2; [ "$(discs)" -gt "$before" ] && break; done
  sleep 1.5 # 커지는 연출(0.38초)이 끝난 뒤.
}
# 1) 돌 아래 3R 에서 가운데를 지나 위로 6R, 0.25초.
a shell input swipe "$CX" "$(low 3)" "$CX" $((CY - 3 * R)) 250; wait_shot 0
# 2) 오른쪽 가장자리(0.8R)를 같은 빠르기로.
B=$((R * 8 / 10))
a shell input swipe $((CX + B)) "$(low 3)" $((CX + B)) $((CY - 3 * R)) 250; wait_shot 1
# 3) 살살: 돌 아래 2R 에서 1.5초 동안 위로.
a shell input swipe "$CX" "$(low 2)" "$CX" $((CY - R)) 1500; wait_shot 2
# 4) 검지로 튕기기: 돌 가장자리 0.4R 앞에서 손을 뗀다(25ms 짧게) — 화면에서는 돌에 안 닿음.
#    에뮬레이터 화면이 작아(640) 시작은 아래 가장자리 70화소 위까지만 내려간다.
a shell input swipe "$CX" "$(low 3)" "$CX" $((CY + R + R * 2 / 5)) 25; wait_shot 3

LOG=$(a logcat -d -s flutter:I | grep '\[E2E\]')
echo "$LOG"
mapfile -t S < <(echo "$LOG" | grep '\] shot')
fail=0
[ "${#S[@]}" -ge 4 ] || { echo "실패: 쏜 수 ${#S[@]} (4 여야)"; fail=1; }
ang() { echo "$1" | sed -E 's/.*angle=(-?[0-9.]+).*/\1/'; }
for s in "${S[@]}"; do echo "$s" | grep -q 'native=true' || { echo "실패: 안드로이드 손끝 점으로 읽지 않음: $s"; fail=1; }; done
if [ "${#S[@]}" -ge 3 ]; then
  A1=$(ang "${S[0]}"); A2=$(ang "${S[1]}")
  awk -v a="$A1" 'BEGIN{exit !(a > -95 && a < -85)}' || { echo "실패: 가운데 위로 → $A1°"; fail=1; }
  awk -v a="$A2" 'BEGIN{exit !(a < -100)}' || { echo "실패: 오른쪽 가장자리 → $A2° (−100° 보다 왼쪽이어야)"; fail=1; }
  echo "가운데 → $A1° · 오른쪽 가장자리(0.8R) → $A2° · 살살 → $(ang "${S[2]}")°"
fi
if [ "${#S[@]}" -ge 4 ]; then
  A4=$(ang "${S[3]}")
  echo "${S[3]}" | grep -q 'flick=true' || { echo "실패: 돌 앞에서 튕긴 것이 튕기기로 안 잡힘: ${S[3]}"; fail=1; }
  awk -v a="$A4" 'BEGIN{exit !(a > -95 && a < -85)}' || { echo "실패: 튕기기 → $A4°"; fail=1; }
  echo "돌 앞에서 튕기기 → $A4°"
fi
if [ "$fail" = 0 ]; then echo "통과"; fi
exit "$fail"
