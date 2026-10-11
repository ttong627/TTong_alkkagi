#!/usr/bin/env bash
# 에뮬레이터 안에서: 시험 판(E2E_FLICK)을 켜고 adb 로 손끝 밀기를 넣어, 돌이 맞아 나가는지 본다.
# 사용: flick-e2e.sh <시험판.apk>
# 확인: ① 안드로이드 손끝 점(TouchFeed)으로 읽었는가(native=true) ② 가운데를 위로 밀면 −90° 근처
#       ③ 오른쪽 가장자리를 밀면 왼쪽으로 꺾임(< −100°) ④ 살살 밀어도 나감
set -u
PKG=TTong.alkkagi
# adb 명령마다 시간 제한을 둔다 — 하나가 멈추면 단계 전체가 45분 시간 초과까지 기다린다(2026-10-11 첫 실행).
a() { timeout "${T:-30}" adb "$@"; }
echo "[단계] 부팅 확인"
for i in $(seq 1 90); do [ "$(a shell getprop sys.boot_completed | tr -d '\r')" = 1 ] && break; sleep 2; done
for i in $(seq 1 60); do a shell pm path android >/dev/null 2>&1 && break; sleep 2; done
echo "[단계] 설치"
ok=0
for i in 1 2 3; do T=180 a install -r "$1" && { ok=1; break; }; echo "설치 다시 ($i)"; sleep 5; done
[ "$ok" = 1 ] || { echo "실패: 설치가 끝나지 않음"; exit 1; }
a logcat -c
echo "[단계] 앱 켜기"
a shell am start -n "$PKG/.MainActivity"

disc() { a logcat -d -s flutter:I | grep -o 'disc cx=[0-9]* cy=[0-9]* r=[0-9]*' | tail -1; }
D=""
for i in $(seq 1 60); do sleep 2; D=$(disc); [ -n "$D" ] && break; done
sleep 3; D=$(disc) # 화면이 커지는 연출(0.38초) 동안 찍힌 자리가 아니라 다 커진 뒤 자리.
if [ -z "$D" ]; then
  echo "실패: 가까이 보기 화면이 뜨지 않음"; a logcat -d | grep -iE "flutter|AndroidRuntime" | tail -60; exit 1
fi
CX=$(echo "$D" | sed -E 's/.*cx=([0-9]+).*/\1/'); CY=$(echo "$D" | sed -E 's/.*cy=([0-9]+).*/\1/'); R=$(echo "$D" | sed -E 's/.*r=([0-9]+).*/\1/')
echo "돌 자리(화소): 가운데 ($CX, $CY), 반지름 $R"
a shell wm size
echo "[단계] 손끝 밀기"

shots() { a logcat -d -s flutter:I | grep -c '\[E2E\] shot'; }
wait_shot() { # $1 = 지금까지 쏜 수 → 하나 늘 때까지(최대 8초) 기다린 뒤 돌이 멈추고 다시 고를 때까지 쉰다.
  for i in $(seq 1 40); do sleep 0.2; [ "$(shots)" -gt "$1" ] && break; done
  sleep 6
}
# 1) 돌 아래 3R 에서 가운데를 지나 위로 6R, 0.25초.
a shell input swipe "$CX" $((CY + 3 * R)) "$CX" $((CY - 3 * R)) 250; wait_shot 0
# 2) 오른쪽 가장자리(0.8R)를 같은 빠르기로.
B=$((R * 8 / 10))
a shell input swipe $((CX + B)) $((CY + 3 * R)) $((CX + B)) $((CY - 3 * R)) 250; wait_shot 1
# 3) 살살: 돌 아래 2R 에서 1.5초 동안 위로.
a shell input swipe "$CX" $((CY + 2 * R)) "$CX" $((CY - R)) 1500; wait_shot 2

LOG=$(a logcat -d -s flutter:I | grep '\[E2E\]')
echo "$LOG"
mapfile -t S < <(echo "$LOG" | grep '\] shot')
fail=0
[ "${#S[@]}" -ge 3 ] || { echo "실패: 쏜 수 ${#S[@]} (3 이어야)"; fail=1; }
ang() { echo "$1" | sed -E 's/.*angle=(-?[0-9.]+).*/\1/'; }
for s in "${S[@]}"; do echo "$s" | grep -q 'native=true' || { echo "실패: 안드로이드 손끝 점으로 읽지 않음: $s"; fail=1; }; done
if [ "${#S[@]}" -ge 3 ]; then
  A1=$(ang "${S[0]}"); A2=$(ang "${S[1]}")
  awk -v a="$A1" 'BEGIN{exit !(a > -95 && a < -85)}' || { echo "실패: 가운데 위로 → $A1°"; fail=1; }
  awk -v a="$A2" 'BEGIN{exit !(a < -100)}' || { echo "실패: 오른쪽 가장자리 → $A2° (−100° 보다 왼쪽이어야)"; fail=1; }
  echo "가운데 → $A1° · 오른쪽 가장자리(0.8R) → $A2° · 살살 → $(ang "${S[2]}")°"
fi
if [ "$fail" = 0 ]; then echo "통과"; else a logcat -d | grep -iE "AndroidRuntime|FATAL" | tail -30; fi
exit "$fail"
