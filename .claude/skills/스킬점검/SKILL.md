---
name: 스킬점검
description: "설치된 클로드 스킬·명령 전체를 점검하고 고친다 — 딸린 파일이 빠진 빈 껍데기·끊긴 경로·유료 키 사용·python3 멈춤·형 규칙 충돌(승인 대기·자동 발동·WebFetch)·긴 설명을 검사 스크립트로 찾아내고, 정밀 점검은 실제 동작(스크립트 문법·없는 MCP·에이전트·명령·함수·발동어 겹침)까지 본다. 「스킬 점검」「스킬 정밀 점검」「스킬 업그레이드」「스킬 정리」에 쓴다. 남의 스킬을 새로 설치하기 전 보안 검사는 /스킬검증."
---

# 스킬점검 (2026-09-27 만듦 — 이날 전체 업그레이드를 되풀이 가능하게)

## 1. 검사 돌리기

```bash
python C:/Users/ttong/.claude/skills/스킬점검/scripts/check_skills.py --project <지금 저장소>
```
전역 스킬(`~/.claude/skills`)·전역 명령(`~/.claude/commands`)·프로젝트 스킬(`<저장소>/.claude/skills`)을 본다. ❌ 오류가 있으면 종료 코드 1.
⛔`python3` 로 부르지 않는다(스토어 가짜 파일 → 멈춤).

**「정밀 점검」이면 이어서** (겉모양이 아니라 실제로 도는지):
```bash
python C:/Users/ttong/.claude/skills/스킬점검/scripts/deep_check.py --project <지금 저장소>
```
| 칸 | 보는 것 |
|---|---|
| A 스크립트 | 딸린 `scripts/` 의 .py 컴파일·.js `node --check`·.sh `bash -n`(Git Bash — PATH 의 bash 는 WSL 일 수 있다) |
| B MCP | `mcp__서버__` 와 이름으로 적힌 MCP(예: 미설치인 context7·jina-reader)가 실제 설치된 서버인가(`~/.claude.json`·`.mcp.json`+앱 내장) |
| C 에이전트 | `subagent_type`·`` `이름` 에이전트 `` 가 `~/.claude/agents` 에 있는가 |
| D 연결 | 본문의 `` `/이름` `` 이 스킬·명령·내장 명령에 있는가(원문 생태계 명령을 옮긴 문서는 `<!-- 스킬점검:원문명령허용 -->`) |
| E 발동어 | 같은 「발동어」가 여러 스킬 설명에 있는가(잘못 불릴 위험) |
| F 함수 | 통통 스킬의 `sl.xxx(`·`gen_image.xxx(` 등이 `tongtong_studio/*.py` 에 정의돼 있는가 |

검사기를 고쳤으면 **결함을 심은 가짜 스킬로 빨강을 먼저 확인**한다(2026-09-27: 6가지 심어 6가지 검출). 형 규칙·CLAUDE.md 도 없는 도구를 가리킬 수 있다 — B 에서 나온 이름은 `rules/`·`CLAUDE.md` 까지 grep 한다.

## 2. 고치는 순서 (❌ 먼저)

| 결과 | 조치 |
|---|---|
| 딸린 파일 없음(빈 껍데기) | 원래 저장소에서 **빠진 파일만** 받아 채운다(라이선스 확인·내용 검사 후). 받을 곳이 없으면 가리키는 줄을 지우거나 스킬 삭제 |
| 유료 키 문구 | 그 줄 앞에 ⛔형 규칙을 달거나, 구독 경로로 바꾼다(그림=`그림도구`, 글 검토=코덱스·`sherlock_ag.py`) |
| python3 · WebFetch · 승인 대기 · PROACTIVELY | 형 규칙대로 바꾼다(`python` · A2_webread `web_read` · 「계획 한 줄 → 바로 진행」 · 「형이 부를 때만」) |
| 설명 400자 넘음 | 무엇을 하는지 + 발동어만 남겨 한국어로 줄인다(`description` 은 매 대화 실린다) |
| name ≠ 폴더 이름 | 머리말 `name` 을 폴더 이름에 맞춘다 |

## 3. 지우기·합치기 기준

- **형 일과 무관**(다른 제품 개발용 등) · **작동 불가**(필요한 도구·훅·서버가 없음) → 지운다
- **같은 계열 여러 개**(예: 분석 틀 12개, 랜딩 4개) → 스킬 하나 + `references/` 로 합친다(본문은 그대로 옮김)
- 형이 만든 한글 스킬(통통 스튜디오·보건소·명단정제 등)은 **지우지 않는다** — 결함만 고친다
- 지우기 전에 반드시 `~/.claude/backups/skills_upgrade_<날짜>/` 로 백업

## 4. 새 스킬 들이기

1. 깃허브 조사: `gh search repos --topic claude-skills --sort stars`·`--topic agent-skills` + 큐레이션 README(`gh api repos/<o>/<r>/readme`). ⛔WebFetch
2. 거르기: ⛔유료 키 필요 · ⛔비상업/라이선스 없음(원칙만 참고) · ⛔플러그인 통째·훅 대량 · 이미 있는 것과 중복
3. 원문을 **끝까지 읽고** 위험 문구(외부 전송·`curl`·키 요구·지시 덮어쓰기) 검사 → 설명만 한국어로, 맨 위에 「형 규칙」 절 → 출처·라이선스 주석과 LICENSE 파일
4. 매번 제3자 패키지를 버전 고정 없이 받아 실행하는 스킬(`npx -y 패키지@0 …`)은 **본문만 복사**해 로컬로 쓴다

## 5. 끝나면

검사를 다시 돌려 ❌ 0 을 확인하고, `~/.claude/shared-rules/skill-triggers.md`(발동표)와 메모리를 갱신한다.

## 2026-09-27 기록 (다음 점검 때 비교용)

- 전역 스킬 79 → 35 · 명령 48 → 45 · 검사 결과 ❌ 0 · 매 대화 실리는 설명 약 10,300자(명령 20개의 깨졌던·없던 설명이 살아나 늘었다 — 전에는 목록에 「Task」 같은 제목만 떴다)
- 흔한 결함 1위: `argument-hint: [..] [..]` 대괄호 → YAML 목록으로 읽혀 머리말 전체가 무시됨 → 값은 따옴표로
- 정밀 점검(같은 날 2차): 스크립트 71개 문법 통과 · 통통 함수 호출 41개(모듈 12) 전부 정의 있음 · 고친 것 = context7·jina-reader MCP(미설치)를 1순위로 적은 `rules/interaction.md`·CLAUDE.md·as-source-driven → `A2_webread web_read` / 없는 명령 `/verify`·`/build-and-fix` / `/작업` 설명의 「검사해」 겹침 → 결과 ❌0·⚠️0
- 빈 껍데기였던 것: design·brand·banner-design·slides(삭제) / ui-ux-pro-max·design-system·ui-styling·graphify(원본에서 채움)
- 새로 들임: systematic-debugging(superpowers) · firebase-security-rules-auditor(Firebase 공식) · 한국어윤문(k-skill) · 사업분석(pm 12종 합침) · 랜딩페이지(Supanova 4종 합침)
- 다음 후보(아직 안 넣음): kordoc(HWP→마크다운·신구대조표, MIT, npm 설치 필요) · google/skills cloud-run-basics · screenwriting-skills(민담 대본 작법)
