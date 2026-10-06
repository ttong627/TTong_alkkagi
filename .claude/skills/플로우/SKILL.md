---
name: 플로우
description: 구글 Flow(flow.google.com) 영상 제작 — 안토니가 만든 스토리보드를 Flow 작업 패키지로 바꾼다(캐릭터 @이름 · 배경 @이름 · Agent 지침 · 장면 프롬프트 · Storyboard Studio 원고) + 받은 클립이 기준에서 흔들렸는지 검사. "플로우", "구글 플로우", "Flow 패키지", "스토리보드를 플로우로", "캐릭터 일관성", "플로우 클립 검사"로 발동.
---

# /플로우 — 스토리보드 → 구글 Flow

> 비유: 촬영장 **콜시트**. 배우(캐릭터)·세트(배경)·장면별 대본을 한 묶음으로 나눠 주면, 형은 Flow 에서 그대로 찍기만 한다.
> Flow 는 API 가 없는 화면 제품이다 — **생성은 안토니가 로봇으로**(형 09-26 「Flow 작업도 니가 다」·09-27 「봇이 각각의 세션에 붙어서」):
> `python D:\Gemma4\tongtong_studio\flow_batch.py --project <번호> --images <그림> --prompts <프롬프트> --out <받을 곳>` (뉴스 패키지는 `--pkg`)
> — 형이 로그인한 전용 크롬 창에 코드가 붙는다 · 토큰 0 · **월 크레딧만**(구매·충전·업스케일 금지) · 받은 영상은 프롬프트 글로 짝짓기. ⛔크롬 확장으로 누르기.
> 학습 기록 = 메모리 `reference_google_flow_learning` · 옛 SSOT `tongtong_studio/docs/Flow_캐릭터_활용법.md`(08-25)

## 0. Flow 핵심 (2026-09-15 공식 도움말 · 형 계정 실측)

| 기능 | 무엇 | 우리 쓰임 |
|---|---|---|
| **캐릭터** (왼쪽 Characters) | 그림 1~2장 + 이름 + **목소리** + 설명 → 프롬프트에서 `@이름` | 얼굴·옷·목소리 고정 |
| **재료** (Video Ingredients) | 프로젝트 자산을 `@이름` 으로 부른다 | 배경·소품 고정 |
| **Agent 지침** | 프로젝트마다 기준 그림 1장 + 규칙 | 화풍 통일 |
| **Storyboard Studio** (프로젝트 → 도구 · 제작 Google) | 화풍 → Script(원고 자동 분리) → Assets(캐릭터·장소·소품) → Storyboard(장면 그림) | 대본에서 장면 그림까지 |
| Style Writer · Scene/Shot Explorer · Stringout Creator (Google) | 무드보드→화풍 문구 · 장소 다른 각도 · 클립 잇기 | 화풍 문구 · 배경 일관성 · 조립 |
| **도구 34종 전체** → [`도구안내.md`](도구안내.md) | ★쓸 것 12 · 쓸 수도 12 · 안 씀 10 · 레시피(멀티샷·스케치·조립분해) | Grid Architect·Shot Explorer=멀티샷 · Simple Sketch=스케치 · 3D Model Visualizer=조립·분해 |

| 모델 | 재료 쓸 때 길이 | 비고 |
|---|---|---|
| **Gemini Omni Flash 1.1** ← 기본 | 4·6·8·10초 | 시작·끝 프레임 · 영상 편집 · 맞춤 목소리 · **360p 반값 → ULTRA 720p 올리기 0크레딧** |
| Veo 3.1 Fast·Lite | 8초만 | Lite 만 이어 늘리기 |
| Veo 3.1 Quality | 재료 불가 | — |

## 1. 쓰는 순서

```bash
cd /d C:\Users\ttong\.claude\skills\플로우\scripts
```

1. **정본 뼈대** — 스토리보드를 story.json 으로
   - storyboard 스킬 표: `python adapters.py md 스토리보드.md --title 제목 --ratio 9:16 --style 통통그림체3 --out story.json`
   - 민담 보드: `python adapters.py folk _domi_script --out story.json` (하이라이트 = **video/ 에 영상 붙은 컷** 또는 등급 ≥4)
2. **cast · locations 를 채운다**(아래 3절 규칙) — 기계가 누가 누구인지 못 정한다
3. **패키지**: `python flow_story.py story.json` → `~/Downloads/플로우_<제목>_<시각>/`
   - 검사에서 막히면(금지어·대장 누락·길이) **패키지를 만들지 않고** 무엇을 고칠지 찍는다
4. Flow 에서 `00_먼저읽기.md` 대로 — **경로 A(Storyboard Studio)** 또는 **경로 B(캐릭터 @ · Agent 지침)**
5. 받은 클립을 `07_받은클립/S01.mp4 …` 로 두고 `python flow_similarity.py <패키지>`
6. 테스트: `python -m pytest test_flow.py` (19)

패키지 안: 00_먼저읽기 · 01_Agent지침(+화풍기준) · 02_캐릭터/<이름> · 03_배경/<이름> · 04_장면/S01.txt(+첫프레임) ·
05_Agent_일괄요청 · 06_스토리보드표 · 07_받은클립 · 08_스토리보드스튜디오(원고·화풍_커스텀) · story.json

## 2. story.json

```json
{"title": "…", "ratio": "9:16", "model": "Omni Flash 1.1", "style": "통통그림체3",
 "cast": [{"id": "tongtong", "flow_name": "통통이", "refs": ["공식시트 조각 1~2장"],
           "voice": "낮은 성인 남성 바리톤", "info": "…", "policy_note": "an adult man"}],
 "locations": [{"id": "studio", "flow_name": "자활스튜디오", "refs": ["사람 없는 배경 1~3장"]}],
 "shots": [{"id": "S01", "duration": 8, "cast": ["tongtong"], "location": "studio",
            "action": "사람 동작 하나", "camera": "카메라 움직임 하나",
            "dialogue": [{"who": "tongtong", "line": "한국어 대사"}], "start_frame": "선택"}]}
```
- `flow_name` 은 **띄어쓰기 없이** — Flow 에서 그대로 `@이름` 이 된다
- `style` = `/그림도구` 의 통통그림체 0~3 (퉁퉁 자활이야기 기본 = 3 · 민담 본편 = 0)

## 3. 일관성 — 캐릭터 · 배경 · 그림

**캐릭터**
- 기준 그림: 그림체 3 = **공식 3D 시트 조각만**(`00_Assets/character/refs/tt_*`) · 민담 = 그 작품의 확정 그림
- ⛔Storyboard Studio **Autofill 캐릭터는 새로 그린 딴사람** → Assets 탭에서 기준 그림으로 **교체**
- ⛔장면 프롬프트에 **생김새·나이 숫자를 다시 적지 않는다** — 적는 순간 글을 따라 새로 그린다
- 2.5등신 캐릭터는 `policy_note: "an adult man"` (아이로 읽혀 막힌 기록)
- 목소리는 **캐릭터를 만들 때 묶는다** → 모든 컷에서 같은 목소리. 받은 뒤 F0 가 200Hz 넘으면 다시 뽑는다

**배경**
- 기준 그림은 **사람 없는 깨끗한 판**(Flow 공식 권장: 단색·분리된 배경)
- 같은 장소는 **같은 @배경만** 쓴다 · 각도가 필요하면 Scene/Shot Explorer 로 **그 그림에서** 뽑는다

**화풍**
- Agent 지침(경로 B) · 커스텀 화풍(경로 A)에 `/그림도구` 정본 문구가 자동으로 들어간다
- 더 다듬고 싶으면 Flow **Style Writer** 에 통통그림체 기준 그림을 넣는다

**동작**
- 한 컷에 **사람 동작 하나 + 카메라 하나**. `HOLD`(전원 정지)는 기본값이 아니다
- 막히면 **두 번** 순화 → 그래도 막히면 프롬프트 말고 **그림을 바꾼다**

## 4. 금지어 문지기 (`flow_story.gate`) — 전부 실제로 막힌 기록
⛔브랜드명 · 인물 조작 어휘 · 정지 지시 · 성적 표현 · 상처 · **울음·비명·접촉**(부정문도) · tender/gently/softly ·
**child/girl/boy/chibi** · 한국어 울음·포옹 — 있으면 패키지를 안 만든다
⚠️나이 숫자 · 생김새 재서술 · pull/fade · 아이·접촉으로 읽힐 한국어 — 경고만

## 5. 유사도 검사 (`flow_similarity.py`) — 무엇을 믿고 무엇을 안 믿나
실측(도미 Flow 클립 6 ↔ 원본 그림):
| 숫자 | 판정 | 이유 |
|---|---|---|
| bg 배경 색 분포 | ✅ 기준 0.35 | 같은 컷 평균 0.56 / 다른 컷 평균 0.22 |
| hold 클립 앞뒤 | ✅ 기준 0.35 | 카메라가 움직여도 0.44 이상 |
| first 첫 프레임 구조 | 참고만 | 같은 컷·다른 컷이 겹친다 |
| cast 인물 특징점 | 참고만 | 손그림·3D 인물은 특징점이 약하다 |

⇒ **인물 동일성을 숫자로 판정하려면 그림 이해 모델(CLIP 급, 가중치 약 600MB)이 필요** — 다운로드는 형 허락 후.
그 전까지는 흔들린 컷 표시 + **눈으로** 확인한다.

## 6. 크레딧 아끼기
- Omni **360p 로 초안** → 마음에 드는 것만 **720p 올리기(ULTRA 0크레딧)**
- Agent 질문은 무료(하루 한도) · 생성만 크레딧 — 「생성 전 확인」은 켜 둔다
- Flow 첫 화면 안내(09-15): Google AI 요금제에 매일 Flow 크레딧 50 추가

## 7. 하지 않는 것
- ⛔남이 만든 생성 자동 클릭 도구·reCAPTCHA 우회 도구 · ⛔로그인 토큰을 가로채 API 처럼 쓰는 깃허브 도구(`Flow-Agent-Studio` 류) — 우리 로봇(`flow_batch`·`idiom_flowbot`)은 형이 로그인한 창을 화면 그대로 누를 뿐이다
- ⛔검색 링크의 **공유판** Storyboard Studio 에 대본 넣기(「다른 사용자가 만든 앱」 경고 · 링크 가진 사람이 데이터 접근)
- ⛔Gemini Omni **API** 로 영상 뽑기 — 유료 티어 전용(`no-paid-api-keys`). 영상은 Flow 화면 크레딧으로

## 참고
- 공식: [Create videos](https://support.google.com/flow/answer/16353334) · [Agent](https://support.google.com/flow/answer/17093911) · [프로젝트·자산·캐릭터](https://support.google.com/flow/answer/16935308) · [모델별 기능](https://support.google.com/flow/answer/16352836) · [그림](https://support.google.com/flow/answer/16729550)
- 유튜브: 조팀장의 AI 공략집 「상위 1%만 아는 구글 FLOW 스토리보드 무료 활용법」(2026-08-03) — Storyboard Studio 순서
- 깃허브: `mvanhorn/printing-press-library` pp-flow(생성 직전 실제 브라우저로 넘기는 원칙 · 크레딧 예산 · 참조 없는 캐릭터 찾기)
