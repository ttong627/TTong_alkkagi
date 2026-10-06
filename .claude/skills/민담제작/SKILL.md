---
name: 민담제작
description: 이야기꾼 통통 민담 새 작품을 주제 하나로 끝까지 — ①주제·원전 확인 → ②대본(8막·약 90분) → ③그림 200장 자리·효과·하이라이트·영상 배치 → ④주제곡 Suno 프롬프트 → ⑤뮤비 화면 구성·그림 생성 → ⑥구글 Flow 패키지 → ⑦Suno 상자 전달 → ⑧곡이 오면 Flow 영상까지 안토니가 직접(flow_batch). 주제만 정하면 묻지 않고 끝까지 돈다(멈춤 = Suno 생성·발행뿐). 그다음 나레이션부터는 /롱폼. "민담제작", "민담 새 작품", "이야기꾼 통통 새 편", "주제 정했어", "이 주제로 만들어", "코덱스 대본 확인하고 이어서"로 발동.
---

# /민담제작 — 주제 하나로 대본부터 Flow 패키지까지

> 형 지시(2026-09-25): 「이걸 하나의 메뉴식으로 묶어서 **주제 선정하면 여기까지는 니가 알아서** 생성하고 작업하도록 하자.
> **매번 똑 같은 내용을 내가 시키게 하지 말고**」
> 비유: 공장 조립 라인. 형은 **주제 한 장**을 올려놓고, 라인 끝에서 **Suno 상자**만 받아 간다. Flow 는 안토니가 한다.
> ★★★형 지시(09-26 「구글 플로우 작업도 니가 다 해줘야 해」 · 09-27 「플로우 작업도 이제는 니가 다 해야 해」):
>   **Flow 상자를 형에게 넘기지 않는다.** 서동 편에서 상자 24개를 넘겼다가 다시 지적받았다.
> 뒤 단계(나레이션·조립·출고·발행) = **/롱폼**(folk_run 9단계). 이 스킬은 그 **앞 단계**를 채운다.

## 0. 시작하면 (30초)

1. 메모리 `tongtong_INDEX.md` 를 읽는다(화풍·그림은 맨 나중·효과·영상 품질 규칙). 작품이 이미 있으면 `project_<작품>.md` 도
2. **작업 폴더를 정한다**
   - 운영 = `D:\Gemma4\tongtong_studio` (작품 파일은 git 밖, 여기에만 산다)
   - ⚠️**워크트리 세션이면 운영 폴더에 못 쓴다**(하네스가 막음) → 워크트리의 `tongtong_studio` 에서 만들고,
     운영에만 있는 모듈은 `PYTHONPATH="D:/Gemma4/tongtong_studio"` 로 **뒤에** 붙여 빌린다(작업 사본 파일이 먼저 쓰인다).
     끝에 `python folk_sync.py <EP> --go --code` 한 줄을 형에게 준다(기본은 보여 주기만 · 덮기 전 백업)
3. 형이 주제를 안 줬으면 **메뉴**를 보여 준다(위젯 가능하면 show_widget 버튼, 아니면 번호):
   - ① 새 작품 — 주제 추천 TOP3(`/수집` 의 `studio_lib.recommend_topic`) 또는 형이 준 주제
   - ② 코덱스·다른 세션이 만든 대본 **검토 후 이어서** (⇒ 1단계 검토표부터)
   - ③ 만든 작품 이어서 — `python folk_run.py _<key>_script` 로 어디인지 보고 /롱폼
   주제가 정해지면 **아래 1~7을 묻지 않고 끝까지** 돈다. 끝에 「이렇게 해석했다」 한 줄.

## 1. 주제·원전 (작품 폴더 `Projects/channel_story/<key>_<YYYYMMDD>/`)

- 원전을 **직접 읽는다** — 한국민족문화대백과·공유마당 등(`mcp__A2_webread__web_read`, ⛔WebFetch). ★★형 10-05:
  **이야기는 하나**(⛔몰아보기·옴니버스) · 그 이야기의 **여러 판본을 믹스해** 재미있게 구성 · **60분 이상**.
  판본마다 좋은 대목을 골라 한 줄기로 엮고 `주제선정.md` 에 「대목 ↔ 판본」 표를 단다(옛 「한 변이형만」 규칙은 폐기 · 지어내기 금지는 그대로)
- `주제선정.md`: 선정 이유 · 후보 비교 · **원전 사건 목록** · 각색 범위(이름·음모·대사 = 창작) · 원전과 다른 점을 **숨기지 않는다**
- `연출기획.md`: 질문과 결말 · 인물표(생김새 고정값) · 막 구성 · 반복 소품 · 미러 화면 · 극적 영상 후보
- 발행 대장으로 **중복 확인**: `python _ledger.py --check`(자활) · 민담은 `UPLOAD_STATUS.md` 에서 제목 검색
- 스튜디오 DB 채택 표시(선택): `UPDATE sources SET used=1 WHERE id=?`

## 2. 대본 — `대본.md` + `작품.json`

형식(변환기 `folk_md.py` 가 읽는다):
```
## 1막. 제목
### S01. 장면 제목
해설 [낮고 느리게]: 나레이션 문장. 여러 문장 가능.
돌쇠 [속삭임]: 대사.
해설 [낮게]: 지금까지 이야기꾼 통통이었습니다. [여운 6초]
```
`작품.json` = `key · ep · title("제목 | 민담") · series · thumb_title · narrator("해설") · roles{대본 이름: 배역} · act_mood{막: 평온/긴장/공포/슬픔/보상/응징}`

**지킬 것** (전부 실제 사고에서 왔다)
- 분량: **약 22,000~23,500자 ≈ 90분**(낭독 속도 SSOT `folk_voice.CPS`=4.7 + 쉼). 한 이야기로 채운다(⛔여러 편 모으기·같은 말 되풀이로 늘리기)
- ⛔말줄임표 `...`/`…` — TTS 가 소리를 지어낸다 · ⛔대사 안 대괄호(`[여운 N초]` 만 예외)
- ⛔현대 호칭·물건(「돌쇠 씨」·의자 등) — 조선 산골에 맞게(여보·서방님 · 앉을 자리)
- **절정의 위치 관계를 한 문장으로** 먼저 적는다(누가 어디 서고 무엇이 누구를 향하나) → 대본·그림이 그것을 따른다
  (호랑이 편: 「몰이꾼 줄 — 그 뒤에 포수 — 옆에 빈 돌밭」이 없어서 「총구 뒤에 몰린 사람들」이 모순이었다)
- 새 배역은 `folk_voice.py` **ALIAS** 에 목소리 연결(없으면 기본값 목소리로 겹친다 — F6)
- 결정적 존재(호랑이·산신 등)는 **아껴서** 등장 · 콜드오픈은 결말 직전에서 멈추고 흔적만
- 관통 문장 3~5개를 정해 둔다 — 주제곡 가사·쇼츠가 여기서 나온다

## 3. 그림 200장 자리 · 효과 · 하이라이트 · 영상 배치 — `장면.json`

```bash
cd /d <tongtong_studio>
python folk_md.py <EP> --sheet 200     # 시간으로 먼저 나눈 작업표.md + 장면_뼈대.json(인용 q)
```
- 그림 수 = **분량(초) ÷ 약 27.5초**(90분 → 200장). 한 장 20~45초 · 오뉘 22초 · ⛔도미 44초는 형 지적
- 작업표를 **막 단위로 읽으며** 장면마다 채운다: `{q, ko, en, shot, sound, video?, move?}`
  - `q` = 뼈대 그대로(그 자리 첫 대사 머리말) — 그림은 **인용으로** 걸린다(⛔줄 번호 손으로 적기)
  - `ko` 화면(한국어) · `shot` 구도·카메라 · `sound` 소리 — **장면마다 쓴다**(⛔막마다 한 값 복사: 숲에 문고리 소리)
  - `en` 영문 한 문단 — 인물은 **대문자 이름**(DOLSOE 등)만, 생김새는 `cast` 한 곳에만. 계절·시간·빛을 꼭 적는다
  - 사람을 그린다 — 무인 그림은 5장 이하 · ★미러 짝수
  - 영상 자리 `video`: `op` 콜드오픈 3 · `hl` 하이라이트(약 2.5분에 1개, **영상 사이 최장 6분 이하**, 본편의 6~8%) · `ed` 마지막 1
    - `move` = **사람 동작 하나 + 카메라 하나**(영어) · ⛔결말의 칼(총성·죽음 순간)은 영상으로 만들지 않는다
    - 영상 자리 영문·move 에 ⛔`blood wound injured bandage child boy girl cry scream touch embrace hug grab gently softly breathing motionless frozen`
- 머리에 `era` · `cast`(SETTING + CAST 인물별 생김새 + STYLE + "SCENE: ") · `reveal{이름: {words, from_quote}}`
- ★★**인물 설정표 `refs`** (형 09-27 「주인공들은 인물이 고정될 수 있도록 캐릭터를 코덱스로 · 이쁘게 멋지게 · 악당도 마찬가지로」)
  - 머리에 `refs{설정표이름: 영문 인물 한 문단}` — 주인공은 **차림새가 바뀔 때마다 한 장**(서동: 상투·스님 변장·깎은머리·왕),
    주요 인물·**악당**도. 문장은 **어른으로 못 박는다**(handsome/beautiful · adult proportions · 나이) — 「princess·small mouth·cozy」만
    쓰면 아이 동화책 얼굴이 된다(09-27 안티그라비티 실측). 악당은 「striking and cool villain」
  - 그림마다 `refs: [붙일 설정표]` — 이름 없이 「두 손·그를 등지고」로만 나오는 인물도 넣는다(그 장면 en 에 대문자 이름도 넣는다)
  - `cast` 의 STYLE 에 ⛔`cel shading`(0번 머리말의 NOT cel-shaded 와 부딪친다) → `soft painted shading`
- 만들고 검사:
```bash
python folk_md.py <EP>                  # 제작 파일 + 보드 + 스토리보드.md (효과 칸까지)
python folk_audit.py _<key>_script      # ★위반 0 이어야 넘어간다
```
- **효과 칸을 눈으로 훑는다** — 겨울 전 눈 · 한겨울 아지랑이 · 숲속 촛불 · 물가 비가 없는지(오탐은 `folk_fx.py` 에서 고치고 테스트 추가)
- 카메라 칸은 `folk_layout` 이 `focus·in·l·focus·out·r` 로 돌린다(09-26) — focus 는 그림 속 인물에게 다가갔다 옮기므로
  **사람이 또렷이 서 있는 그림**일수록 산다. ⛔물결(water)은 없앴다. 뒤 단계 규칙 전부 = **/롱폼**

## 4. 주제곡 — `뮤비.json` 의 song_title · style · lyrics

- **Suno v6**: Style 칸 ≤1,000자 · 5부 공식(장르·무드·보컬·악기·BPM) 앞에 중요한 것 · ⛔`[Verse]` 태그는 Lyrics 칸에만
- 형 취향: **90~92 BPM · 장구** · 흥얼거릴 후렴 · 구수하고 따뜻하게 · clean mix · ⛔epic powerful orchestral belting · ⛔65 BPM
- **작품마다 스타일이 달라야 한다** — `folk_suno.USED_STYLES` 와 겹치면 멈춘다(끝나면 이 작품 줄을 거기 더한다)
- 가사는 관통 문장에서 · 뒤에 **8초 여운**(Outro)
- ⚠️원래 순서는 나레이션 → 곡이다. 나레이션 전에 쓰면 Suno 문서에 그렇게 적히고, 나레이션을 들어 보고 **스타일만** 바꾼다

## 5. 뮤비 화면 구성 · 그림 — `뮤비.json` 의 cast · places · slots

- `slots` 20개(12~24): `{lyric(가사 안에 있는 줄), place, cast[], ko, en, action, camera, light, mood}`
  - 전부 **사람이 나오고 움직인다** · ⛔결말 스포일러(죽음·총성) — MV 는 본편보다 **먼저** 나간다
  - `mood` = 보상·응징·슬픔·공포·평온·긴장 (없으면 자리 순서로 조명이 정해져 봄 장터도 슬픔이 된다)
- `cast` 인물마다 `flow_name`(띄어쓰기 없이) · `en_name`(영문 대문자 이름 — 동작 문장 안에서 `@flow_name` 으로 바뀐다) · `info`(한국어) · `en`(기준 그림, 단색 배경 전신) · `policy_note`(adult man 등)
  · ★`ref` = 그 인물의 **장면.json 설정표 이름** — MV 그림에도 설정표를 붙인다(09-27 시어머니 편에서 MV 만 빠져 있었다).
    차림새가 바뀌는 자리(봄 옷·변장)는 그 자리에 `refs: [설정표…]` 로 바꾼다. 없는 이름이면 folk_mvplan 이 멈춘다
- `action`·`camera` 는 Flow **경고 낱말도 금지**(pull·fade 등 — folk_mvplan 이 멈춘다). 「pull back」 대신 「dolly back」
- 그림을 볼 때 특히: **설명에 없는 무기**(도끼·칼)·**이빨 드러낸 맹수**·배경의 **아이** — Flow 에서 막히거나 이야기가 달라진다.
  그 번호만 설명을 못 박고 `--only mv04,mv14` 로 다시(옛 그림은 `_v1` 로 이름만 바꿔 보관)
- `places` 장소마다 **배경 한 문단**(같은 장소는 늘 같은 문단 · 글자 없음)
```bash
python folk_mvplan.py <EP>              # _<key>_mvplan.py + Suno 문서 + flow/뮤비_가로·세로.json
python folk_gen.py <key> refs           # ★인물 설정표(왼쪽 얼굴 크게 + 오른쪽 전신) → Downloads/<작품>_설정표 — 제일 먼저
python folk_gen.py <key> cast           # 인물 기준 그림(코덱스) → Downloads/<작품>_캐릭터
python folk_gen.py <key> mv             # 뮤비 첫 장면 20장(코덱스) → Downloads/<작품>_MV
```
- ★★**그림은 전부 코덱스, 구글 Flow 는 동영상만**(형 09-27 「코덱스로 이미지를 다 뽑자 · 동영상만 구글 플로우 쓰고」).
  본편(`main`)·영상용(`video`)은 그 장면 인물의 설정표를 `-i` 로 붙여 한 장씩 그린다. ⛔안티그라비티·Flow 이미지 모드·제미나이로 그림
- 설정표는 **예쁘고 멋진지 먼저 형에게 한 장으로 보여 준다**(얼굴이 200장에 복사된다)
- 코덱스 모델은 `folk_gen` 이 `gpt-5.6-sol` 로 박는다(ChatGPT 계정에서 gpt-6 계열은 400). ⛔**장수 한도 없음**(형 10-05 「한도 없단까 왜 자꾸 니가 한도를 설정하는거야?」) — 몇 장이든 한 번에 돌린다. 실제 UsageLimit 오류가 찍혔을 때만 멈추고 보고
- 오래 걸리면 백그라운드로 돌리고 무엇을 기다리는지 말한다
- 받은 그림은 **한 장씩 눈으로 본다**(Read) — 딴사람·글자·손 왜곡·계절 어긋남 → 그 번호만 `--only` 로 다시

## 6. 구글 Flow 패키지 — `/플로우` 확정 서식(09-20: 길이·초 진행표·배경 문단이 상자 안에)

```bash
cd /d C:\Users\ttong\.claude\skills\플로우\scripts
python flow_story.py "<EP 폴더>\flow\뮤비_가로.json" --out "%USERPROFILE%\Downloads\<작품>_Flow_가로"
python flow_story.py "<EP 폴더>\flow\뮤비_세로.json" --out "%USERPROFILE%\Downloads\<작품>_Flow_세로"
```
- 금지어에 막히면 패키지를 안 만든다 → `뮤비.json` 을 고치고 5단계부터 다시
- 전부 **10초**로 뽑는다(곡에 맞춰 뒤에서 자른다 — 모자라서 늘리는 일이 없게)

## 7. 전달 — Suno 상자만 (형 원칙 09-16 · Flow 는 09-27부터 안토니가 직접)

순서: **Suno** Style 상자 → Lyrics 상자. ⛔Flow 캐릭터·장면 상자는 넘기지 않는다(8-3 에서 안토니가 뽑는다)
- 파일은 SendUserFile 로 **덧붙인다**(스토리보드.md · Suno 문서 · Flow 패키지 00_먼저읽기)
- 워크트리였다면 `folk_sync.py <EP> --go --code` 명령을 **첫 번째 할 일**로 준다
- 마지막 한 줄: 다음 = 곡 받으면 「<작품> 주제곡 받았어」 / 나레이션은 `/롱폼`(folk_run 3단계)

## 8. 곡이 오면 — 뮤비 완성까지 (형 「노래 받았어」 · 호랑이 편 09-25~26)

```bash
python folk_song.py <EP> "<Downloads\<작품>_주제곡\받은곡.mp3>"   # 낱말 전사 → 곡시각.json·theme.wav·본편 92초
```
1. `작품.json` 에 `theme` 칸을 채운다: `{title, file: theme_<key>_92s.wav, sec: 92.0, lyrics: Projects/channel_story/bgm/theme_<key>_lyrics.json, cuts: [본편 컷 10개]}`
   — 컷 수 = **곡 초 ÷ 10 올림 이상**(92초 → 10컷, 한 컷 9.2초). 넘으면 folk_md 가 멈춘다
2. `python folk_md.py <EP>` (THEME_* 다섯 줄) · `python folk_mvplan.py <EP>` (START·SONG_SEC·LYRICS_FULL)
3. **Flow 클립 — 안토니가 묻지 않고 바로 뽑는다**(형 09-26·09-27 지시 · 월 크레딧 안) — 공용 도구 `tongtong_studio/flow_batch.py`
   (Flow 전용 크롬 창 9333 · `python flow_browser.py status` 로 로그인 확인 · ⛔크롬 확장으로 한 칸씩 누르지 않는다 — 느리고 헛누름)
   - 새 프로젝트: 전용 창에 **제 탭**을 열어 「New project」 → 이름(예 `scratchpad/flow_newproj.py` 방식) · 남의 탭 금지
   - 문장: `_Flow_가로|세로/04_장면/mvNN.txt` 의 `@이름 (an adult man)` → **역할명**(the young man …), 끝줄 → 「Keep every face, costume and the painted look exactly as in the start frame.」
     → `Downloads\<작품>_MV영상\_문장_가로|세로\mvNN.txt` · 시작 그림 `…\_시작그림_가로|세로\mvNN.png` · `flow_story.gate` 로 금지어 0 확인
   - `python flow_batch.py --project <번호> --images <시작그림> --prompts <문장> --out <…\가로> --no-speech --dry` → 잔액·설정(동영상·720p·10초·x1) 확인 → `--dry` 빼고 실행
     (동시 6 · 다 된 것부터 점검해 받음 · 짝짓기는 프롬프트 글 일치 · 잔액 500 아래·구매 글자 → 스스로 멈춤 · ⛔크레딧 구매·업그레이드)
   - 10초 한 개 약 15크레딧 → 가로 N + 세로 N · 받은 클립은 **눈으로 몇 개 확인**(시작 그림 닮음·사람이 움직임)
4. `python folk_mvclips.py <key>` → `python folk_mv.py <key> go` — 워터마크는 **재서 있을 때만** 자른다(09-26부터 Flow 클립엔 없음)
5. 완성본 눈검사: 가사 자막·후렴 금색·엔딩 카드(세로 눈밭 대비)·끝 10초 소리 · ⛔발행은 형 확인
6. **썸네일(형 09-27 「궁금증을 유발해서 클릭」)**: `_<key>_thumbplan.py` 에 세 판(얼굴 큰 장면 · 질문이 남는 한 마디) →
   `python folk_thumbmv.py <key>` 로 비교 → `python folk_thumbmv.py <key> <판>` = 가로·세로 썸네일을 영상 옆에 두고 영상 표지로 붙인다(뮤비를 다시 조립하면 표지가 사라지니 다시)
7. ★★**발행할 때는(본편·뮤비·쇼츠 전부)** 메모리 `feedback_publish_thumbnail_first_comment_checklist.md`(발행 체크리스트 SSOT)를 먼저 읽는다 —
   본편 썸네일도 `folk_thumbmain.py`(같은 thumbplan 의 `MAIN`) 세 판 비교 · 첫 댓글 400~800자 5요소 + 고정 · API 403 은 다시 확인 후 바로 ·
   확인 뒤에만 「발행 끝」(형 09-28 「썸네일 신경써서 · 첫 댓글도 안 달고 · 모든 규칙 저장」)

## 하지 않는 것

- ⛔Suno 생성 버튼 대신 누르기 · ⛔Flow **크레딧 구매·충전**(월 크레딧 안에서만 — 뽑기는 안토니가 한다) · ⛔유료 API 키(Gemini 이미지 등) · ⛔발행
- ⛔본편 그림 200장을 이 단계에서 뽑기 — **그림은 나레이션 뒤**(컷 길이가 정해진 다음). 여기서 뽑는 것은 MV·인물 기준 그림뿐
- ⛔`보드_생성.py` 같은 작품 전용 생성기를 새로 짜기 — `folk_md.py`·`folk_mvplan.py` 를 고친다

## 참고 — 이 스킬이 부르는 것

| 도구 | 하는 일 |
|---|---|
| `folk_md.py` | 대본.md·장면.json → `_<key>_p*·script·scenes·video·board.py` + 스토리보드.md · `--sheet N` 작업표 |
| `folk_fx.py` | ②효과(모든 그림 · 한 글자 오탐 막음 · tests/test_folk_fx.py) |
| `folk_audit.py` | 연출 점검 A~I (위반 0) |
| `folk_mvplan.py` | 뮤비.json → `_<key>_mvplan.py`(PLAN·MOVE·MOOD·CAST_REFS) + Suno 문서 + Flow 입력 |
| `folk_gen.py` | 코덱스 그림 전부: `refs`(설정표) · `cast` · `mv` · `video`(op·hl·ed) · `main`(본편) — main·video 는 설정표를 붙인다 |
| `flow_story.py`(/플로우) | Flow 패키지 · 금지어 문지기 |
| `folk_sync.py` | 워크트리 → 운영 폴더 옮기기(백업·대조) |
| `folk_song.py` | 받은 곡 → 곡시각.json(자리 시작·가사 낱말 시각) · theme.wav · 본편 92초 |
| `folk_mvclips.py` · `folk_mv.py` | Flow 클립 반입(워터마크 실측) · 뮤비 가로·세로 조립 |
| `folk_run.py`(/롱폼) | 이후 3~9단계 |

첫 적용: 「호랑이가 제 목숨으로 갚은 은혜」(2026-09-25) — 메모리 `project_minhwa_tiger.md`
