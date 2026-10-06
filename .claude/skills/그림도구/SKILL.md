---
name: 그림도구
description: 그림·디자인 도구 네 개를 한 곳에서 — 통통 그림체로 그림 뽑기(코덱스=ChatGPT 구독·안티그라비티 나노바나나, 둘 다 API 키 없음) · Google Stitch 화면 디자인(MCP) · Claude Design(데스크톱 사이드바). "그림 그려", "통통 그림체", "통통그림체1로", "나노바나나로", "스티치", "클로드 디자인", "그림도구"로 발동.
---

# /그림도구 — 그림·디자인 도구 네 개를 한 곳에서

> 비유: **화구 서랍장**. 붓(코덱스)·먹(안티그라비티)·화면 밑그림판(Stitch)·설계실(Claude Design)이
> 서랍마다 들어 있고, 이 문서는 서랍에 붙인 이름표다.
> ⛔유료 API 키를 쓰는 서랍은 없다 (`~/.claude/rules/no-paid-api-keys.md`).

## 0. 무엇을 어디에 쓰나 (2026-09-15 실측)

| 도구 | 잘하는 것 | 비용 | 상태 |
|---|---|---|---|
| **코덱스** (ChatGPT 구독 내장 그림) | 그림 — **기준 그림 첨부**로 그림체를 붙잡는다 | 구독 안 · 키 없음 | ✅ 로그인됨 |
| **안티그라비티 나노바나나** (gemini-3.1-flash-image) | 그림 — 빠른 초안 | 구독 안 · 3장 뽑는 동안 크레딧 500→500 (변화 없음) | ✅ IDE 에 폴더가 열려 있을 때 |
| **Google Stitch** | 웹·앱 **화면(UI) 디자인** | 구글 랩스 실험 단계 무료·한도 있음 (블로그 기준 · 공식 요금표 미확인) | ⏳ 연결 등록됨 · **키 필요** |
| **Claude Design** | 프로토타입·슬라이드·원페이저·디자인 시스템 | 형 Claude 요금제 한도 안 (Pro·Max·Team·Enterprise 베타) | 데스크톱 사이드바 · Code 연동은 `/design-login` 필요 |

## 1. 그림 — 이름 붙은 그림체로 뽑기

### ★★형의 기본 화풍 네 개 (형 확정 2026-09-15 — 당분간 이 네 개로 작업)

| 번호 | 화풍 | 쓰는 곳 | 문구 정본 | 기준 그림 | 기본 |
|---|---|---|---|---|---|
| **0** | 이야기꾼 통통 — 손으로 그린 극장 애니메이션(화풍 C) · **정본** | 민담 본편 | `tongtong_studio/folk_style.py` (불러옴) | 화풍 C 7장 | codex · 16:9 |
| **1** | 수묵담채 붓그림 | 형이 지정한 작업 | `styles/통통그림체1/style.json` | 원본 창작 3장 | codex · 16:9 |
| **2** | 0번 인물 강화 + 조선 민화 배경 | 형이 지정한 작업 | `styles/통통그림체2/style.json` | 원본 창작 2장 | codex · 16:9 |
| **3** | 3D 애니메이션 · 통통 미니보스 | **퉁퉁 자활이야기 기본** · 미니보스 이모티콘 | `tongtong_studio/_jahwal_char.py` 의 `LOOK` (불러옴) + 장면에 `char(의상)` | 공식 3D 시트 조각 4장 | codex · 9:16 |

**관리 규칙**
- 번호·이름은 형이 정한다. 새 화풍은 5번부터, 기존 번호의 뜻을 바꾸지 않는다
- 0·3은 **정본 파일이 따로 있다** — 문구를 `style.json` 에 복사하지 않는다(두 벌이 되면 어긋난다). 정본을 고치면 전부 따라온다
- 1·2의 기준 그림은 **우리가 뽑은 원본 창작**만 둔다. 3은 **공식 시트 조각만**(AI 로 뽑은 캐릭터 그림을 기준으로 다시 쓰면 딴사람이 된다)
- 기준 그림을 바꾸면 `python style_check.py <기준 그림…>` 으로 다시 재서 `ranges` 를 고치고,
  `python -m pytest test_style_check.py test_tt_draw.py` 가 통과해야 끝이다(네 개가 다 갖춰졌는지 테스트가 잠근다)
- 숫자는 보조 문이다. 0·2 사이는 color 간격이 좁고, 0의 두 극단(게임CG·납작한 셀)은 숫자로 못 가른다 → **눈으로 본다**

```bash
cd /d C:\Users\ttong\.claude\skills\그림도구\scripts && python tt_draw.py "장면 설명" --style 통통그림체1
```

- 엔진은 `style.json` 의 `engine_default` (통통그림체1 = **codex**). 빠른 초안은 `--engine agy`
- 결과는 `~/Downloads/그림도구_<시각>/` — 작업마다 새 폴더
- 「변형 없이」를 지키는 **세 겹**
  1. 문구 — `styles/<이름>/style.json` 의 `prompt` **한 곳**에서만 붙인다
  2. 기준 그림 — `styles/<이름>/refs/` 를 코덱스에 첨부한다 (안티그라비티는 첨부 불가)
  3. 숫자 — `style_check.py` 가 paper·sat·ink·color 를 재서 벗어나면 다시 뽑는다
- ★숫자를 통과해도 **한 장씩 눈으로** 본다 — 글자·도장·손가락·얼굴은 숫자로 못 잡는다
- 장면 설명은 영문이 안정적이다. 사람 수·물건 수는 **숫자로 못박는다**(모델은 못 센다)
- 코덱스는 순서대로 한 장씩 뽑는다 — 쿼터도 아끼고 결과 파일도 헷갈리지 않는다

### ⛔통통그림체1 을 쓰지 않는 곳
- **민담 본편** — 본편 화풍 정본은 `tongtong_studio/folk_style.py`(극장 애니메이션 화풍 C).
  `folk_audit.py` B3 가 `ink wash`·`hanji` 를 위반으로 잡는다. 섞으면 한 작품이 두 작품처럼 보인다
- **외부 웹툰·불법 사이트 그림을 기준 그림으로 넣지 않는다** — 기준은 우리가 뽑은 원본만

### 새 그림체를 추가할 때
1. `styles/<이름>/style.json` — `prompt`(긍정문으로 · 금지어를 늘어놓으면 그 색·모양을 부른다) · `refs` · `ranges`
2. 원본 창작 시안 3~4장 → **형이 고른 것만** `refs/` 에
3. `python style_check.py refs/*` 로 잰 숫자에 여유를 두어 `ranges` 를 정한다. 대조군(다른 화풍 그림)이 **걸리는지** 같이 본다

## 2. Google Stitch — 화면 디자인

✅**연결됨 (2026-09-15 · `claude mcp get stitch` = ✔ Connected)** — 사용자 설정 `stitch` = **로컬 중계기**
`python scripts/stitch_mcp_proxy.py` (stdio). 키는 환경변수 `STITCH_API_KEY` 에서만 읽는다 — **설정 파일에 키가 없다**.

★왜 중계기인가 — Stitch 주소에 바로 붙이면 「Connected · tools fetch failed」
(`can't resolve reference #/$defs/ScreenInstance`). 키 문제가 아니라 **Stitch 도구 설명서의 `$ref` 참조를
Claude Code 가 못 푼다.** 중계기가 tools/list 응답만 참조를 펼쳐 넘긴다(도구 15개 · 남은 `$ref` 0 실측).
⛔Stitch 화면이 주는 `claude mcp add stitch --transport http --header …` 로 되돌리지 말 것 — 같은 실패 + 키가 설정 파일에 남는다.
「MCP 키」는 따로 없다 — MCP 설정 명령 안의 키 = API 키와 같은 값.

도구(15): create_project · get_project · delete_project · list_projects · list_screens · get_screen ·
generate_screen_from_text · edit_screens · generate_variants · upload_design_md · create_design_system ·
create_design_system_from_design_md · update_design_system · list_design_systems · apply_design_system
★새 세션(앱 재시작 뒤)부터 `mcp__stitch__*` 로 보인다. 중계기 테스트 = `test_stitch_mcp_proxy.py` (11)

**형이 한 번만 할 일** (로그인·키 발급은 형 계정으로 형이 직접)
1. https://stitch.withgoogle.com 에 형 구글 계정으로 로그인 (2026-09-15 확인: 형 크롬은 이미 로그인됨)
2. 오른쪽 위 프로필 사진 → **Stitch 설정** → 아래로 내려 **API 키** 칸 → **키 만들기** → 뜬 키를 복사
   - 목록에 있는 옛 키(09-15·07-10, 둘 다 「사용 안함」)는 **다시 복사할 수 없다**(삭제 버튼만 있다). 저장해 둔 키가 없으면 새로 만든다
   - ⛔「MCP 설정」 펼치기 화면은 키가 그대로 보인다 — 화면 공유·캡처 금지
3. 키 넣는 창을 연다 — **붙여넣기 칸 + [클립보드에서 붙여넣기] 버튼 + [키 보이기] + [저장]** (형 지적 09-15: 「이상한 문자를 어떻게 입력하냐」 → 글자 안 보이는 콘솔 입력은 쓰지 않는다)

```powershell
powershell -STA -ExecutionPolicy Bypass -File "C:\Users\ttong\.claude\skills\그림도구\scripts\stitch_key_gui.ps1"
```

   (예비: 창 없이 클립보드에서 바로 넣기 = `stitch_key.ps1`)

4. Claude 앱을 **완전히 껐다 켠다**

확인: 새 대화에서 「스티치 프로젝트 목록 보여줘」.
⚠️Claude Code 가 이 헤더를 무시하고 OAuth 를 시도해 실패한다는 보고가 있었다
(anthropics/claude-code 이슈 #41664 → #3273). 이 PC(2.1.215)에서 되는지는 **키를 넣은 뒤 실제로 불러 확인**한다.
공식 스킬 묶음(google-labs-code/stitch-skills: generate-design 등)은 **연결이 확인된 뒤** 설치한다.

## 3. Claude Design

- 쓰는 곳: **Claude 데스크톱 앱 사이드바** 또는 https://claude.ai/design (형 Max 계정 확인 · 작품 5개)
- ✅**Claude Code 연동 완료 (2026-09-15)** — `/design-login` 끝 · `DesignSync list_projects` 응답 확인
  - 목록에는 **「디자인 시스템」 프로젝트만** 나온다(지금 0개). 웹의 일반 작품은 안 나온다
  - 쓰는 법: 「클로드 디자인에 ○○ 디자인 시스템 만들어줘」 → 프로젝트 생성 → 올릴 파일 목록을 형이 확인 → 업로드
  - 로그인이 풀리면: Windows 터미널에서 `claude` → `/design-login` 다시 한 번
- ⚠️그림 생성기가 아니다 — 화면·슬라이드·디자인 시스템용. 한도가 빨리 닳는다는 사용 후기가 많다

## 4. 하지 않는 것

- ⛔유료 API 키 — Gemini 이미지 키, `OPENAI_API_KEY`(코덱스 imagegen 의 CLI 모드가 요구) 둘 다 안 쓴다
- ⛔제3자 Stitch 설치기(비공식 깃허브 저장소) — 구글 공식 주소로만 잇는다
- ⛔키를 대화창·파일·명령줄에 붙여넣지 않는다 — `stitch_key.ps1` 로만 넣는다
