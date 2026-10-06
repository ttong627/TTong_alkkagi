---
name: 모션그래픽
description: 통통 모션 스튜디오 — 구글 Flow(이미지 0크레딧·영상)로 모션 디자인을 만든다. ①복스 종이 콜라주(요소를 따로 그려 층으로 움직임) ②키네틱 타이포(한글 정확) ③캐릭터 애니메이션 ④제품·홍보(연속 스토리보드 먼저) ⑤레퍼런스 영상 분석→촬영 지시서 ⑥민담 본편 모션 카드. 힉스필드 대신 Flow. "모션그래픽", "모션 그래픽", "모션 디자인", "복스 스타일", "종이 콜라주 영상", "키네틱 타이포", "모션그래픽 메뉴 보여줘"로 발동.
---

# /모션그래픽 — 통통 모션 스튜디오 (구글 Flow 기반)

> 형 지시(2026-09-26): 「힉스필드가 아니라 **구글플로우**를 이용해서 모션디자인을 만들어주는 도구를 만들어줘. 통통스튜디오에 부착해줘」
> + 「여기(디자인하는AI·Newtake)에서 나오는 방법도 모션 그래픽 도구에 추가해줘」
> 비유: 인쇄소. 형은 **요청서 한 장**을 넣고, 안토니가 Flow 로 재료를 뽑아 **판을 짜서(HyperFrames)** 영상으로 찍어 낸다.

## 0. 먼저 (30초)
1. 메모리 `reference_motion_skills_survey_0926.md`(HyperFrames 설치·함정) · `project_antigravity_free_image_api.md`(Flow 이미지 0크레딧) 를 읽는다
2. 코드 = `D:\Gemma4\tongtong_studio\motion_studio\` (mg_prompt · mg_key · mg_collage) · 렌더 = HyperFrames `D:\Tools\hyperframes`(0.8.77 고정)
3. 받을 폴더는 **작업마다 새로**: `Downloads\모션스튜디오_<주제>_<MMDD>\`
4. 형이 종류를 안 정했으면 아래 메뉴를 번호로 보여 준다(위젯 가능하면 show_widget 버튼)

## 1. 메뉴
| # | 무엇 | 출처 방법 | Flow 비용 |
|---|---|---|---|
| ① | **복스 종이 콜라주** — 요소를 따로 그려(초록 배경·찢은 종이 가장자리·주인공만 강조색) 층·카메라·종이 애니메이션으로 | 원카AI(Vox) | 이미지 **0** |
| ② | **키네틱 타이포** — 글자 자체가 움직이는 영상. 한글은 HyperFrames 로 정확히(영상 모델은 한글을 틀린다) | 디자인하는AI ① | 0 (배경 영상을 쓰면 15/10초) |
| ③ | **캐릭터 애니메이션** — 촬영 지시서 + 캐릭터 기준 그림을 **생성 때 다시** 붙인다 | 디자인하는AI | 영상 15/10초 |
| ④ | **제품·홍보** — 먼저 **연속 스토리보드 한 장**(3×3·5×5)으로 흐름 확인 → 제품 그림 참조로 영상 | 디자인하는AI | 스토리보드 0 · 영상 15/10초 |
| ⑤ | **레퍼런스 영상 분석** — 마음에 드는 영상 → 샷·모션·색·글꼴을 뽑아 촬영 지시서로 | 디자인하는AI ② | 0 |
| ⑥ | **민담 본편 모션 카드** — 제목 4초·막 5초 투명 카드 `folk_cards.py` → 조립기가 겹침 | (이미 있음) | 0 |

## 2. 요청서 → Flow 글 (`mg_prompt.py`)
요청서 `brief.json` (예시 `motion_studio/examples/tiger_intro/brief.json`):
`name · kind(collage|kinetic|character|product) · sec(4~10) · aspect · topic · style{look, palette[], accent} · shots[{t0,t1,what,camera}] · layers[{id, prompt, full?, poses[]?}] · sound · guardrails[]`
```bash
cd /d D:\Gemma4\tongtong_studio\motion_studio && python mg_prompt.py "<폴더>\brief.json"
```
- 나오는 것: **영상 촬영 지시서**(길이·스타일·초 단위 샷·카메라 공통 규칙·소리·가드레일·글자 없음) · **스토리보드 한 장** · **층 그림**(포즈마다 한 장)
- /플로우 문지기(BLOCK·WARN)를 **만들 때** 돌린다 — BLOCK 이면 멈춘다
- 긴 영상은 샷을 10초 이하 조각으로 나눈다(Flow 영상 4~10초)

## 3. Flow 에서 뽑기 — 안토니가 형 Chrome 으로 (`mcp__claude-in-chrome__*`)
- **새 프로젝트**(flow.google.com → New project). 뒤 단계에서 헷갈리지 않게 작업마다 새로
- 설정(입력창 오른쪽 칩): **이미지 · 나노바나나 Pro · x1 = 0크레딧**(09-26 실측, Pro·2·2 Lite 전부 0) · 배경 층 16:9 · 인물 1:1
- 같은 인물의 **두 번째 자세**는 입력창 「+」(프롬프트 상자에 소재 추가)로 **첫 그림을 참고로 붙인다** → 같은 호랑이
- 투명 배경은 못 낸다 → 요소는 **완전한 초록(#00FF00) 바탕**으로 그리게 했다. 흰 바탕으로 나오면 「The whole background … filling every empty area」로 다시
- **받기**: 탭이 뒤에 있으면 칸 메뉴(⋮)가 안 열린다(마우스 올리기가 안 먹음). 페이지 안에서 **칸 제목으로 그림을 찾아 정한 이름으로** 받는다:
  `find` 로 칸 제목 확인 → `javascript_tool` 에서 제목이 든 조상 칸의 `<img>` 를 `fetch → blob → <a download="mg_bg.jpg">` (주소는 밖으로 내보내지 않는다 · 결과엔 이름·크기만)
  ⚠️이렇게 받는 것은 화면 표시판(1K: 16:9=1376×768, 1:1=1024×1024). 더 크게는 칸 메뉴 → 다운로드 → 2K/4K
- 영상(③④)은 설정을 **동영상 · Omni 1.1 Flash · 720p · 10초 · x1 = 15크레딧**. 참조 그림은 「소재」로 붙이고, 시작 그림이 있으면 「프레임」 모드. ⛔크레딧 구매·업그레이드 누르지 않는다

## 4. 콜라주 합성 (①)
```bash
python mg_key.py "<폴더>\keyin" --out "<폴더>\cut"      # 초록 → 투명(모델·내려받기 없음) · 남은 비율 0.05~0.97 밖이면 ⛔
python mg_collage.py "<폴더>\scene.json"                  # → <폴더>\<name>.mp4
```
`scene.json` (예시 `motion_studio/examples/tiger_intro/scene.json`): `sec · camera{zoom[a,b], pan[a,b]} · layers[{id, src|frames[], full?, x, y, w, depth(0 먼 배경~1 앞), in(등장 초), fps(자세 번갈기), flip}] · title{text, sub, at}`
- depth 로 원근(디오라마) · frames 여러 장 = 종이 애니메이션(옛 종이 인형처럼 동작을 몇 장으로 나눠 번갈기) · 자세 그림은 **아래 가운데**로 맞춘다
- 제목은 **한글 그대로**(명조) 종이 띠 위에 떠오른다 · 종이 결(노이즈) 한 겹
- 눈검사: 8시점 격자 + 끝 장면 원본 크기 — 초록 번짐·발 튐·제목 가림·인물 방향

## 5. 레퍼런스 분석 (⑤)
- 형이 준 **파일**이면 `ffmpeg -i ref.mp4 -vf "select='gt(scene,0.3)',showinfo" -vsync vfr frames/%03d.png` 로 장면이 바뀌는 곳만 뽑아 **한 장씩 Read**
- 링크면 Chrome 에서 열어 재생 위치별로 캡처(⛔내려받기는 형 허락 먼저) · 유튜브 자막은 「스크립트 표시」 패널에서 읽는다
- 뽑은 것을 요청서의 `style·shots` 로 옮긴다 — 색(hex)·글꼴 계열·샷 길이·전환 방식·카메라

## 6. 지킬 것
- 형 모션 원칙: fade + 12~24px 떠오르기 0.42초 · 요소 간격 0.34초 · ⛔날아들기·회전·바운스·타자기
- ⛔유료 API 키(Gemini·Higgsfield·Replicate 등) — HyperFrames 는 `GEMINI_API_KEY` 를 자식 환경에서 지우고 돈다
- ⛔영상 모델에 한글 글자를 그리게 하지 않는다 → 글자는 HyperFrames 로 겹친다
- Flow 영상은 크레딧 — 뽑기 전 **개수×15** 를 말하고 시작. 이미지는 0
- 받은 그림·영상은 **이름으로 짝짓는다**(순서·닮음으로 짝지으면 틀린다)

## 참고
| 파일 | 하는 일 |
|---|---|
| `motion_studio/mg_prompt.py` | 요청서 → 촬영 지시서·스토리보드·층 그림 글 + Flow 문지기 |
| `motion_studio/mg_key.py` | 초록 배경 → 투명 PNG(번짐 제거·요소 크기로 자르기) |
| `motion_studio/mg_collage.py` | 층·원근·카메라·종이 애니메이션·한글 제목 → mp4(HyperFrames) |
| `folk_cards.py` · `motion_cards/` | 민담 본편 제목·막 카드 |
| `tests/test_motion_studio.py` · `test_folk_cards.py` | 10개 |

첫 결과: 「호랑이가 제 목숨으로 갚은 은혜」 8초 복스 콜라주 인트로(09-26) — `Downloads\모션스튜디오_호랑이인트로_0926\tiger_intro.mp4`
