---
description: 보건소 총괄 비서 아침 리포트 — 16곳의 오류·미작업·미학습 적용을 node 가 결정적으로 판정해 리포트(docs/clinics/_총괄/)와 say.py 보고 한 줄을 남긴다. 작업 스케줄러 yyplus_clinic_manager 가 매일 08:30·09:30 `claude -p "/hc-manager"` 로 부른다. `--dry` 면 파일·보고 없이 화면에만. 대화용 한글 이름 = /보건소총괄. 설계 = wssc-unified/docs/보건소_전담에이전트_설계서.md §2-2·§7
argument-hint: "[--dry]"
allowed-tools: ["Bash"]
---

# /hc-manager — 보건소 총괄 비서 (형 결정 2026-09-13 · 3단계 · 완성 2026-09-15)

**발동**: 스케줄러(`server/clinic-manager-task.ps1`) · 대화에서 `/hc-manager --dry` 또는 `/보건소총괄 --dry`.
**목적**: 16곳 비서의 상태판·청구 게이트(G3)·VM 감사(08:17)·확인요청을 읽어 **오늘 형이 볼 것** 한 장을 만든다.

## 절대 원칙
- **판정은 node 가 한다** — Claude 는 명령 한 줄을 실행하고 결과를 그대로 전한다. 숫자를 고치거나 해석을 덧붙이지 않는다.
- **읽기만** — 운영 데이터·규칙·코드·git 을 건드리지 않는다. 쓰는 것은 node 가 쓰는 `docs/clinics/_총괄/<날짜>.md`·`state.json` 두 파일뿐(`--dry` 면 0).
- **에이전트 호출 금지** — Agent·Task 도구를 쓰지 않는다(비서·코난 소집 금지).
- **PII 없음** — 리포트·보고에는 보건소 이름·축 이름·건수·금액만.

## 실행 (이 순서 그대로 · 명령은 한 번만)
1. `$ARGUMENTS` 에 `--dry` 가 있으면 `node server/clinic-manager.mjs --dry`, 없으면 `node server/clinic-manager.mjs` 를 **그대로 한 줄** 실행한다.
   - 작업 폴더는 이미 `I:\ttong_project\yyplus\wssc-unified` 다(스케줄러가 거기서 부른다 · 대화에서 부를 땐 그 폴더에서).
   - ⛔`cd`·`source`·`&&` 를 붙이지 않는다 — 스케줄러 허용 규칙이 **이 명령 한 줄**만 받는다. 비밀 환경값은 node 가 `~/.wssc-secrets/env.sh` 에서 스스로 읽는다.
2. 끝나면 출력 맨 끝의 `(say.py) …` 줄과 **종료코드**를 한 줄로 전하고 끝낸다.
   - 0 = 정상 · 1 = 🔴 보건소 있음(정상 동작 — 리포트에 담겼다) · 3 = 막힘(node 가 이미 실패본 리포트와 say.py [막힘] 을 남겼다)
3. 명령이 권한 거부되거나 실행되지 않으면 **그 사실만** 한 줄로 남기고 끝낸다(다른 방법으로 우회하지 않는다).
