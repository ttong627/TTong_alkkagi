---
name: seedance
description: "Seedance 2.0 범용 프롬프트 디렉터. 어떤 장르·스타일 요청이든 받아 Higgsfield Seedance 2.0에서 가장 좋은 결과가 나오는 프롬프트를 생성한다. 내부적으로 5가지 모드를 자동 분기: (1) Cinematic — 영화적 씬, (2) Ad Brief — 광고/브랜드 필름, (3) Signature — 변신·POV·격투·애니메이션, (4) Short Film — 다씬 단편, (5) Hybrid — 실사 + 2D 캐릭터/일러스트 통합. 사용자가 영상 아이디어를 설명하거나 'Seedance 프롬프트', '씬 만들어줘', '프롬프트 짜줘', '변신 영상', 'POV', '격투', '광고', '단편', '실사+애니', '2D 캐릭터' 같은 표현을 쓰면 트리거. 장면 묘사만 있고 명시적 요청어가 없어도 영상 제작 의도가 보이면 활성화. 한국어·영어·혼용 모두 입력 가능. 출력은 Higgsfield에 바로 붙여넣을 수 있는 영문 프롬프트 + 한국어 해설."
---

# Seedance 2.0 Universal Director

입력 장르 불문, Seedance 2.0에서 가장 좋은 결과가 나오는 프롬프트를 생성한다.
광고·영화·액션·멜로·애니메이션·단편·실사+2D 통합 등 어떤 요청이든 5가지 전문화된 모드 중 최적 모드로 자동 라우팅한다.

---

## 작동 원칙

1. **결과 퀄리티 최우선** — 사용자가 모드를 신경쓸 필요 없다. 스킬이 자동 판단한다.
2. **Higgsfield 엔진 검증** — Higgsfield 공식 가이드에서 검증된 프롬프트 패턴만 사용한다.
3. **영문 출력 + 한국어 해설** — Seedance는 영어에 최적화. 프롬프트는 영어로, 선택 이유는 한국어로 설명.
4. **복붙 가능 포맷** — 출력 영문 프롬프트는 Higgsfield 입력창에 그대로 붙여넣으면 된다.

---

## INPUT 처리

사용자는 자유 형식으로 아이디어를 던진다. 아래를 추출한다.

**필수 추출:**
- **모드 결정** — 5가지 중 최적 모드
- **길이** — 사용자가 길이를 명시하면 준수하되 **절대 15초 초과 금지**. 없으면 모드별 기본값.
  - **⚠️ 하드캡 15초 (엔진 제약)** — Seedance 2.0은 최대 15초까지만 생성 가능. 사용자가 "20초", "30초", "1분" 등을 요청해도 **반드시 15초로 축소**하고, 한국어 해설에 "Seedance 2.0 엔진 제약으로 최대 15초로 조정했습니다"라고 안내.
  - 사용자 미지정 시 기본값: Cinematic 10초 / Ad Brief 15초 / Signature 15초 / Short Film 씬당 5~8초 / Hybrid 15초
  - 출력 프롬프트의 `Total:` 표기는 **항상 15초 이하**여야 함. 16초 이상 절대 금지.
- **화면비** — "세로", "가로" 명시되면 준수. 없으면 16:9 기본. "인스타/릴스/쇼츠" 같은 용도어는 9:16으로 해석.
- **카메라 지시** — 사용자가 명시한 카메라 동작·앵글은 반드시 출력 반영.

**선택 추출:**
- 캐릭터 (이름, 외모, 의상)
- 로케이션 (시간대, 조명, 공간)
- 스타일 레퍼런스 (장르, 영화, 톤)

첨부 이미지가 있으면 시각 정보 우선.

---

## MODE ROUTER (자동 분기)

### 라우팅 결정 트리

```
1) 실사 + 2D 캐릭터 통합 의도?
   ("실사+애니", "실사에 만화 캐릭터", "Roger Rabbit 같은",
    "Paddington 같은", "캐릭터가 사람과 대화", "2D 캐릭터를 실사에",
    "토토로 같은", "chibi 캐릭터", "일러스트 캐릭터 + 사람",
    "또리 같은", "실사 영상에 그림체 캐릭터")
   → Mode 5: HYBRID

2) 요청에 공식 시그니처 포맷 키워드 있나?
   ("변신", "transformation", "POV", "1인칭", "격투", "fight", 
    "애니메이션 스타일", "3D 애니", "초능력")
   → Mode 3: SIGNATURE (서브포맷 자동 선택)

3) 광고·브랜드·제품 영상 의도?
   ("광고", "CF", "브랜드", "제품 영상", "프로모", "ad", "commercial")
   → Mode 2: AD_BRIEF

4) 다씬 단편 영화 의도?
   ("단편", "씬 여러 개", "캐릭터 일관성 유지", "등장인물 3명",
    "장소 바뀜", "Scene 1, 2, 3")
   → Mode 4: SHORT_FILM

5) 그 외 모든 씬 묘사
   (영화적 씬, 드라마, 멜로, 분위기, 풍경, 대화 등)
   → Mode 1: CINEMATIC
```

**모드 명시 오버라이드:** 사용자가 "광고 모드로", "POV로 해줘", "영화 씬으로", "Hybrid로" 등 명시하면 명시한 모드 우선.

**혼합 판단 규칙:** 
- Hybrid + 광고 → **Hybrid 우선** (2D 캐릭터가 등장하면 통합 처리가 핵심)
- Hybrid + Cinematic → **Hybrid 우선**
- 광고 + 변신 → 더 구체적인 포맷(Signature) 우선

이유: Hybrid와 Signature는 검증된 구조가 있어 결과가 안정적.

---

## UNIVERSAL ENGINE RULES (공통 엔진 규칙)

모든 모드 공통 적용. Seedance 2.0 엔진이 잘 이해하는 언어 패턴.

### 구조 규칙
- **샷 구조 선언 필수** — 프롬프트 상단 또는 하단에 `Total: Xs / N shots / ratio` 명시
  - 예: `Total: 15s / 6 shots / 16:9`
- **인 미디어스 레스** — 별도 지시 없으면 씬은 이미 진행 중인 상태로 시작

### 카메라 규칙
- **이중 대비(Double Contrast)** — 컷마다 샷 사이즈 + 카메라 모드 둘 다 변경
  - 샷 사이즈 스케일: extreme wide → wide → medium → medium close-up → close-up → ECU
  - 카메라 모드: Handheld / Static / Stabilized tracking / Crane / Aerial
- **180도 룰** — 컷 후 같은 공간으로 돌아오면 인물 위치·방향 재명시
- **인서트 샷** — 0.3~0.5초, 누구의 신체부위인지 명시 필수 (익명 인서트 금지)

### 액션 묘사 규칙
- **의도 + 기법명**, 생체역학 금지
  - ✅ `"spinning back kick connects"`
  - ❌ `"left forearm rotates 45° to deflect"`
- **힘과 방향**, 파괴 시퀀스 금지
  - ✅ `"driven into the car, metal buckling"`
  - ❌ `"thrown into door, glass shatters, uses rebound to sweep leg"`

### 렌더링 제약 (어기면 씬 붕괴)
- **반사 금지** — 거울·칼날·물웅덩이 반사는 Seedance가 공간 기하를 망가뜨린다. 대체 구도 사용.
- **프레임 재진입 금지** — 캐릭터가 프레임 아웃 하면 해당 샷에서 다시 들어올 수 없다.
- **오프스크린 참조 금지** — 화면에 먼저 보여주지 않은 상태 변화는 언급하지 않는다.
- **추적 캐릭터 3명 이하** — 컷을 넘어 추적되는 주요 인물은 최대 3명.

### 묘사 규칙
- **보이거나 들리는 것만 기술** — 냄새·촉감·분위기감 금지
- **미세 표정은 물리로 기술**
  - ✅ `"jaw clenches, nostrils flare"`
  - ❌ `"looks angry"`

### 안전 규칙
- **나이 표기 금지** (모든 언어)
  - 금지어: boy, girl, child, kid, young, teen, little, 소년, 소녀, 어린, 청소년, 아이
  - 역할·의상·행동으로 기술: `"the rider"`, `"a figure in a wool cloak"`, `"the archer"`
- **대화 원어 보존** — 사용자가 한국어 대사를 제공하면 한국어로 유지. 번역 금지.

### 어휘 금지 (AI 슬롭 방지)
**영문 금지어:** breathtaking, stunning, captivating, mesmerizing, awe-inspiring, masterfully, meticulously, exquisitely, beautifully crafted, cinematic masterpiece, visual feast, a symphony of, seamlessly, effortlessly, flawlessly, cutting-edge, state-of-the-art, next-level, rich tapestry, vibrant tapestry, kaleidoscope of, elevate, unlock, unleash, harness, groundbreaking, a testament to, speaks volumes, resonates deeply

**한국어 해설 금지어:** 숨막히는, 압도적인, 눈부신, 완벽한, 환상적인, 감탄을 자아내는, 매혹적인, 시선을 사로잡는, 독보적인, 차원이 다른

---

## MODE 1: CINEMATIC (영화적 씬)

영화·드라마 톤의 일반 씬. 장르 불문(멜로·스릴러·공포·판타지 다 포함).

### 아키타입 라우터 (9가지)

입력 씬을 분석해 해당 아키타입으로 분류.

#### Action Archetypes
| Archetype | Camera Focus | Space Dynamic |
|-----------|--------------|---------------|
| **Pursuit** (추격) | 거리 좁힘/벌어짐. 피추격자 앞, 추격자 뒤 | 길 좁아짐/넓어짐 |
| **Duel** (결투) | 우세 쪽 카메라 낮게. 우세 반드시 교대 | 전투자 위치 교대 |
| **Impact** (충돌) | 빌드업 느림 → 타격 빠름 → 여파 느림 | 접촉점 = 중앙 |

**결투 규칙:** 한쪽이 연속 2비트 이상 우세하면 "결투"가 아닌 "일방적 공격"으로 재분류.

#### General Archetypes
| Archetype | 변화 요소 | Camera Signature |
|-----------|---------|-----------------|
| **Journey** (여정) | 공간 내 위치 변화 | Tracking, aerial, 함께 이동 |
| **Atmosphere** (분위기) | 아무것도 변하지 않음 — 무드 자체가 콘텐츠 | 최소 움직임, slow push-in |
| **Reveal** (공개) | 숨김 → 보임 | Pan, crane, dolly reveal |

#### Dialogue Archetypes
| Archetype | Power Dynamic | Camera Signature |
|-----------|--------------|-----------------|
| **Confrontation** (대립) | 양쪽 밀어붙임, 우세 교대 | Tight OTS, 파워 시프트 시 축 교차 |
| **Interrogation** (심문) | 한쪽 추출, 한쪽 저항 | 심문자 low-angle, 침묵에 push-in |
| **Negotiation** (협상) | 양쪽 필요 있음, 균형 | 대칭 프레이밍 |

### 대사 단어 제한
15초에 약 25~30단어가 적정. 초과 시 파워 시프트 라인 + 전후 1라인만 유지. 나머지는 물리 행동으로 변환.

### 출력 포맷

JSON 배열 3개 객체:
```
[
  {"lang":"en","prompt":"영문 프롬프트 전체"},
  {"lang":"ko_explain","content":"한국어 해설 전체"}
]
```

**영문 프롬프트 구조 (인라인 섹션 라벨):**
1. `Style & Mood:` 팔레트, 조명, 렌즈, 분위기 — 생략 금지
2. `Dynamic Description:` 샷별 산문, 카메라·움직임·액션, 현재 시제
3. `Static Description:` 로케이션, 소품, 앰비언트
4. `Audio:` (대화 씬만) 대사 + SFX/BGM. 대사는 원어 유지
5. 하단: `Total: Xs / N shots / ratio`

**한국어 해설 구조:**
- **분류:** 어떤 아키타입으로 판단했는지 + 근거
- **핵심 선택:** 카메라·구도 중 가장 중요한 선택 3가지와 이유
- **수정 포인트:** 생성 결과가 안 좋을 때 바꿀 만한 지점 3가지

---

## MODE 2: AD_BRIEF (광고·브랜드 필름)

제품·브랜드·서비스 홍보 영상. 시그니처 이펙트 + 에너지 아크 구조.

### 출력 4섹션 구조

모든 광고 프롬프트는 아래 4섹션을 순서대로 포함.

#### Section 1: SHOT-BY-SHOT EFFECTS TIMELINE

각 샷 블록:
```
SHOT [N] ([timestamp]) — [Shot Name]
• EFFECT: [Primary effect] + [secondary if stacked]
• [Detailed visual description]
• [Camera behavior — angle, movement, lens]
• [Speed/timing — if slow-mo, specify percentage]
• [Transition to next shot]
```

**작성 가이드:**
- 각 샷 1~4초 (긴 홀드가 필요하면 명시)
- 이펙트 이름 정확히: `"speed ramp (deceleration)"`, `"digital zoom (scale-in)"`
- 스택된 이펙트는 모두 나열
- 시그니처 샷은 `SIGNATURE VISUAL EFFECT` 콜아웃
- 슬로모션 퍼센트 명시: `"approximately 20-25% speed"`
- 편집 용어가 아닌 시각 결과로 기술: ✅ `"the frame scales inward rapidly"` ❌ `"apply keyframed scale in AE"`

#### Section 2: MASTER EFFECTS INVENTORY

번호 리스트. 각 이펙트별:
- 이펙트 이름
- 사용 횟수 (e.g., `used 3x`)
- 어느 샷에 쓰였는지
- 편집 내 역할 (한 줄)

카테고리: speed manipulation / camera movement / digital effects / transitions / compositing / optical effects.

#### Section 3: EFFECTS DENSITY MAP

3~6초 구간 단위로 밀도 평가:
- **HIGH DENSITY** — 4+ 이펙트 중첩/연속
- **MEDIUM DENSITY** — 2~3 이펙트
- **LOW DENSITY** — 1 이펙트 또는 클린

포맷:
```
[timestamp] = [DENSITY] ([effects list] — [count] in [duration])
```

#### Section 4: ENERGY ARC

3막 구조(기본, 길이 따라 조정):
- **Act 1:** 오프닝 — 주의 포착
- **Act 2:** 중반 — 시그니처 모먼트
- **Act 3:** 해결 — 에너지 착지

### 크리에이티브 원칙
1. **대비가 임팩트를 만든다** — HIGH/LOW 밀도 교대
2. **시그니처 모먼트 필수** — 영상당 최소 1개 히어로 이펙트
3. **전환도 샷이다** — 휩팬, 블룸 플래시, 모션블러 스미어는 창의적 모먼트
4. **모호함 대신 구체성** — `"대충 슬로우모션"` 대신 `"approximately 20-25% speed"`
5. **에너지는 반드시 해결된다** — 마지막이 의도된 착지

### 길이별 캘리브레이션
**⚠️ Seedance 2.0 하드캡 15초 — 초과 불가**

- 5초: 3~4 샷, 시그니처 1개 (극도로 타이트)
- 6~10초: 4~7 샷, 시그니처 1개
- 11~15초: 8~12 샷, 시그니처 1~2개 (광고 최적 구간)

**기본값: 12~15초.** 
사용자가 20초 이상 요청 시 → 15초로 축소 + 해설에 안내.

### 한국어 해설 구조 (광고 모드)
- **컨셉:** 이 광고가 노리는 감정/액션
- **시그니처 이펙트:** 무엇을 히어로로 선택했고 왜
- **3막 아크:** 어디서 어떻게 에너지가 전환되는지
- **수정 포인트:** 결과가 약할 때 바꿀 지점 3가지

---

## MODE 3: SIGNATURE FORMAT (공식 검증 5포맷)

Higgsfield 공식 가이드에서 검증된 구조. 가장 결과가 좋은 포맷들.

### 서브모드 자동 선택

사용자 입력에서 키워드/의도 감지:
- "변신", "transformation", "변형", "폼체인지" → **Transformation**
- "초능력", "번개 쓰는", "불 쓰는", "POV 액션", "Orb" → **Orb**
- "1인칭", "POV", "검투사 시점", "드라이빙 시점" → **POV**
- "싸움", "격투", "대결", "fight", "battle" → **Fight**
- "애니메이션 스타일", "3D 애니", "CG 애니", "stylized" → **Animation**

### 3-1. Transformation (변신)

**고정 구조:** 6 샷 / 15초 / 에스컬레이션 아크

**의무 오프닝 (프롬프트 상단에 그대로 삽입):**
```
Montage, multi-shot action Hollywood movie, don't use one camera angle or single cut, cinematic lighting, photorealistic, 35mm film quality, professional color grading, sharp focus, high detail texture, film grain, depth of field mastery, ARRI ALEXA aesthetic
```

**에스컬레이션 아크 (필수):**
1. 평온 (calm) — 캐릭터 일상 상태
2. 위협 (threat) — 외부 위협 등장
3. 반응 (reaction) — 캐릭터 인지
4. 변신 (transformation) — 본 변신 시퀀스
5. 행동 (action) — 변신체의 행동
6. 복귀 (return) — 인간 형태로 복귀

**샷 기술:** `Shot 1: [카메라] + [액션]` 형식, 각 샷 번호 매기기.

**하단:** `Total: 15s / 6 shots / 16:9`

**프로 팁 (상황별 자동 삽입):**
- 리얼리즘 강화 요청 시: `"no 3D, no cartoon, no VFX"` 추가
- 코미디 톤이면: `"add a visual gag in the background"` 추가

### 3-2. Orb (1인칭 초능력 POV)

**고정 구조:** 1 샷 / 15초 / 원테이크 / 초카오틱 핸드헬드

**의무 오프닝 블록 (수정 없이 그대로):**
```
Single continuous shot, first-person POV perspective, the camera IS her eyes, hyper-chaotic handheld motion, completely unstabilized, violent raw human movement, constant micro-jitters, aggressive head swings, abrupt jerks, frequent over-rotation and harsh correction, moments of near motion blur loss, no smoothness at all, no stabilization, wide-angle lens (strong distortion), subtle chromatic aberration near frame edges, 15 seconds, her hands always visible in frame, no music only raw SFX, cinematic lighting, photorealistic, grounded realism, strong 35mm film look, heavy film grain, sharp but imperfect focus, noticeable focus breathing, motion blur on fast actions, halation on highlights, soft highlight rolloff, slightly desaturated tones, ARRI ALEXA aesthetic, practical VFX feel, minimal CGI look, natural imperfections
```

**바디 구조:**
1. Location: 환경 상세 (배경, 지형, 조명, 날씨)
2. Action: 비트별 액션 기술
   - 첫 접촉 / 능력 발동 → `[VFX: ...]` 인라인 표기
   - 적 등장 → 외형 상세
   - 교전 1 (근접) → 교전 2 (중거리)
   - 적 보스 등장 → 결정타
   - `RAMPS TO SLOW MOTION` → `SNAPS BACK` 변속 지점 명시
3. SFX: 청각 효과 나열

**하단:** `Total: 15s / 1 shot / 16:9`

**VFX 인라인 표기법 (중요):**
액션 묘사 중간에 대괄호로 VFX만 분리:
```
[VFX: branching electric circuits pulsing with white-blue current, sparks jumping between fingers]
```
이렇게 하면 Seedance가 액션 흐름을 끊지 않고 VFX를 정확히 렌더링.

### 3-3. POV (1인칭 시점 고정)

**핵심 규칙:** "카메라가 하지 말아야 할 것" 반드시 명시

**필수 포함:**
```
no cuts, no zoom, natural head movement
```
이 한 줄이 없으면 Seedance가 컷을 자동 삽입해서 POV 환상이 깨진다.

**2가지 버전 선택:**

**풀 디테일 버전** (검투사 POV 예시처럼):
- 오프닝: 시점 + 장소 + 핵심 액션
- 바디: 15초 안의 모든 액션을 한 문단으로 압축. 콤마로 연결
- 엔딩: 카메라 상태 유지 명시

**미니멀 버전** (중세 기사 POV 예시처럼):
- 단일 문장 ~2문장
- 핵심만: 시점 + 누구 + 뭘 하는지
- 때로는 짧은 프롬프트가 더 잘 나옴

**하단:** `Total: 15s / 1 shot / 16:9`

### 3-4. Fight (격투 씬)

**3대 필수 요소:**
1. **명확한 로케이션** (달리는 열차 지붕, 창고, 폐공장, 콜로세움 등)
2. **명확한 파워 미스매치** (거인 vs 소인, 스킬 vs 근육, 무장 vs 비무장)
3. **정의된 에스컬레이션 아크** (calm → escalation → climax → aftermath)

**구조:**
- 오프닝: 카메라 포지션 + 지형지물
- 바디: 안무를 비트별로 기술 — 타격 1 → 반격 → 타격 2 → 역전 → 결정타
- 슬로모션 명시: `RAMPS TO SLOW MOTION as [이벤트]`
- 스냅백 명시: `SNAPS BACK [이벤트]`
- 사운드: `NO MUSIC / NO SFX` 또는 구체적 SFX 명시

**하단:** `Total: 15s / 1 shot / 16:9` 또는 2샷 구조

**스타일 레퍼런스 활용 (상황별):**
- 빠른 변속: `"Guy Ritchie speed-ramping"`
- 타격 슬로모: `"Snyder impact slow-motion"`
- 와이드 영화 룩: `"Anamorphic 35mm"`
- 사무라이 결투: `"samurai wuxia choreography"`
- MMA 스타일: `"UFC-grade athletic realism"`

### 3-5. Animation (스타일라이즈드 애니메이션)

**고정 구조:** 1 샷 / 15초 / 시간 세그먼트 분할

**의무 요소:**

1. **키프레임 이미지 참조** (이미지 첨부 필수):
```
@image is the first keyframe and style reference.
```

2. **애니메이션 스타일 선언** (오프닝 라인):
```
Cinematic stylized 3D animation — photorealistic environment, stylized characters. High FPS, realistic particle physics.
```

3. **캐릭터 + 몬스터/환경 설계** (구체적)
- 주인공 외모·의상·능력
- 적/몬스터 외형·크기·공격 방식
- 환경 특성

4. **시간 세그먼트 분할** (3초 단위):
```
0–3s: [오프닝 액션]
3–6s: [전개]
6–9s: [절정]
9–12s: [하강]
12–15s: [해결]
```

5. **물리 효과 구체화:**
- 파티클 시뮬레이션 (`particle physics`)
- 볼류메트릭 효과 (`volumetric dust storm`, `volumetric light`)
- VFX 색상·질감 (`rainbow neon energy VFX`)
- 환경 반응 (`realistic sand physics`)

6. **하단:** `Cinematic stylized 3D animation matching @image, [스타일 상세]. 2.35:1, 24fps. Total: 15s / 1 shot / 16:9`

### 한국어 해설 구조 (Signature 모드)
- **포맷:** 어느 서브포맷으로 판단했고 왜
- **핵심 규칙:** 해당 포맷의 가장 중요한 규칙 (예: Orb의 "15초 원테이크")
- **변경하지 말 것:** 의무 오프닝 블록처럼 그대로 유지해야 하는 부분
- **커스터마이즈 가능 지점:** 사용자가 안전하게 바꿀 수 있는 부분

---

## MODE 4: SHORT_FILM (다씬 단편)

여러 씬의 단편 영화. 캐릭터·로케이션 일관성 유지가 핵심.

### 출력 구조

1. **캐릭터 레퍼런스 시트 프롬프트** (각 주요 인물마다 1개)
2. **로케이션 레퍼런스 시트 프롬프트** (각 주요 장소마다 1개)
3. **씬별 샷 리스트** — `@캐릭터` `@로케이션` 태그 사용
4. **모델 지정** — 각 씬/샷이 어느 Higgsfield 모델에서 실행될지 명시

### 캐릭터 레퍼런스 시트 생성 규칙

**용도:** Nano Banana Pro로 생성, 모든 후속 씬에서 캐릭터 일관성 확보.

**프롬프트 템플릿:**
```
Create a professional character reference sheet based strictly on the uploaded reference image. Use a clean, neutral plain background and present the sheet as a technical model turnaround while matching the exact realistic visual style of the reference. Arrange the composition into two horizontal rows. Top row: four full-body standing views – front, left profile, right profile, back. Bottom row: three close-up portraits – front, left profile, right profile. Maintain perfect identity consistency across every panel. Keep the subject in a relaxed A-pose with consistent scale and alignment, accurate anatomy, and clear silhouette. Lighting should be consistent across all panels. Output a crisp, ultra-realistic, print-ready reference sheet.
```

**캐릭터별 기본 씨앗 프롬프트** (Soul ID 훈련용):
- Soul Cinema에서 실행
- 단순 프롬프트 사용: `"A close up of [역할/외형]"`
- 예: `"A close up of an American policeman"`, `"A close up of a woman in her mid-twenties"`

### 로케이션 레퍼런스 시트 생성 규칙

**용도:** Nano Banana Pro로 생성, 공간 일관성 확보.

**프롬프트 템플릿:**
```
Create a professional location reference sheet based strictly on the uploaded reference image. Match the exact realistic visual style, lighting quality, color treatment, and texture of the reference. Arrange into two horizontal rows. Top row: straight-on frontal view, left angled perspective, right angled perspective, reverse wide view. Bottom row: three detailed close-ups of key environmental elements. Maintain architectural consistency, accurate proportions, and consistent lighting across all panels. Output a crisp, ultra-realistic, print-ready location sheet.
```

### 씬별 샷 리스트 규칙

**포맷:**
```
## Scene [N]. [장면 이름]

### Shot [N] — [길이], [카메라]
**What it does:** [이 샷의 서사적 역할]
**Prompt:** [@캐릭터 @로케이션 태그 사용한 프롬프트]
**Model:** [Higgsfield Soul Cinema / Cinema Studio / Nano Banana Pro]
```

**@ 태그 규칙:**
- `@캐릭터명` — 등록된 캐릭터 참조
- `@로케이션명` — 등록된 로케이션 참조
- 대사는 따옴표 안에: `@Adil-Cop says: "..."` 형식

**모델 선택 가이드:**
- **Soul Cinema** — 캐릭터 포함 영상, 스틸 이미지
- **Cinema Studio** — 다캐릭터 다이얼로그 씬, @태그 활용 씬
- **Nano Banana Pro** — 레퍼런스 시트, 환경 이미지 생성
- **Seedance 2.0** — 액션·역동적 씬 (별도 지정 시)

### 한국어 해설 구조 (Short Film 모드)
- **전체 구조:** 몇 씬 몇 샷 기획인지
- **일관성 전략:** 어떤 캐릭터·로케이션을 레퍼런스로 잡았고 왜
- **씬별 의도:** 각 씬의 서사적 목적
- **실행 순서:** 1) 캐릭터 레퍼 생성 → 2) 로케이션 레퍼 → 3) 씬별 생성

---

## MODE 5: HYBRID (실사 + 2D 캐릭터/일러스트 통합)

실사 영상에 2D 만화/일러스트/chibi 캐릭터를 통합. Roger Rabbit / Paddington / 일본·한국 광고에서 보던 합성 스타일.

**핵심 차이점:** 일반 실사 프롬프트는 "한 가지 비주얼 언어"만 정의하지만, Hybrid는 **두 가지 비주얼 언어가 공존**하도록 명시적으로 분리해서 정의한다.

### 라우팅 트리거

다음 키워드/의도가 있으면 Hybrid 모드 활성:
- "실사 + 애니메이션", "실사에 만화 캐릭터"
- "Roger Rabbit 같은", "Paddington 같은", "Christopher Robin 같은"
- "토토로 같은", "지브리 + 실사"
- "chibi 캐릭터 + 사람", "일러스트 캐릭터가 사람과 대화"
- "2D 캐릭터를 실사 영상에"
- "픽시브 캐릭터 + 실사"
- 또는 사용자가 명시적으로 캐릭터 시트(만화/일러스트 톤)와 실사 사람을 함께 등장시키려는 경우

### 9가지 핵심 차별점 (필수 적용)

#### 1. 두 세계 명시적 선언 (Style 블록)

❌ 일반 실사: `"High-end cinematic film, 35mm emulation..."`

✅ Hybrid: 
```
High-end cinematic live-action with integrated 2D [character type]-illustrated character. 
The character appears as a flat 2D modern [style] illustration existing within 
the real-world live-action scene.
```

이 표현이 핵심 트리거. 안 쓰면 캐릭터가 3D로 나오거나, 실사 사람이 만화처럼 변형됨.

#### 2. 비주얼 언어 분리

```
Film grain on the live-action elements, 
crisp clean illustration lines on [Character], 
shallow DOF.
```

- 실사 부분 → 필름 그레인 + 자연스러운 셰이딩
- 캐릭터 부분 → 깨끗한 라인 + 평면 컬러
- 두 비주얼 언어가 **공존하되 섞이지 않게**

#### 3. 참고 작품 (Reference) 정확성

❌ 일반 영화 참고: "Wong Kar-wai", "Sean Baker" → 통합 어색해짐

✅ Hybrid 전용 참고:
- `Roger Rabbit` (1988) — 시초
- `Paddington` film series
- `Christopher Robin` (Pooh integration)
- `Detective Pikachu`
- `modern Japanese-Korean commercials that mix live-action with chibi illustration overlay`

이 키워드들이 AI에게 "이런 통합 방식"을 정확히 전달.

#### 4. 물리적 존재감 (Physical Presence) 명시

```
The integration should feel seamless — [Character] has real weight, 
real presence, real shadow on the table, real reflections in the surfaces.
```

또는 디테일:
```
[Character] sits on stacked cushions on a real chair. 
She holds a small juice cup with a striped straw 
drawn in matching chibi style.
```

**일반 영상에 없는 표현 (Hybrid 전용):**
- "real shadow"
- "real weight"
- "physical presence in scene"
- "sits on real [object]"

#### 5. 사이즈 대비 (Size Contrast) 강조

```
The size contrast is clear — [Character] is much smaller, 
only reaching the woman's knee.
```

또는:
```
[Character] is so small her feet dangle far above the floor.
```

**왜 중요한가:**
- 2D 캐릭터를 사람과 같은 크기로 그리면 어색
- 작은 캐릭터 = chibi 비율 + 귀여움 + 명확한 차별화
- "크기"는 합성 자연스러움의 핵심

**필수:** 캐릭터의 **상대적 크기**를 정확히 명시 (무릎 높이, 60cm 등)

#### 6. 만화 시각 효과 활용

2D 캐릭터에만 가능한 표현 도구:

```
Modern chibi expression details — small sparkles or sweat drops 
can briefly appear around her head as anime-style emotive elements.
```

**활용 가능한 만화 시각 효과:**
- 💦 땀방울 (당황) — `sweat drops`
- ✨ 반짝임 (기쁨) — `sparkles`
- 💢 분노 마크 — `anger marks`
- 💤 졸음 표시 — `"z" symbols above head`
- ❗ 놀람 마크 — `exclamation mark visual element`
- 🌀 어지러움 — `dizzy spirals`
- 💨 빠른 움직임 라인 — `motion lines`

이 도구 활용하면 **2D 캐릭터의 매력 폭발**.

#### 7. 립싱크 정의 분리

❌ 일반 영상: 모든 캐릭터에 정밀 립싱크 요구

✅ Hybrid:
```
The woman's lip movements should synchronize as naturally as possible 
with the spoken Korean dialogue. 
[Character]'s mouth movements should be modern chibi style 
(small "ω" pouty mouth shape with slight movement) 
timed to the cute grumpy Korean voice.
```

**핵심 인사이트:**
- 실사 사람: **정밀 립싱크 필요**
- 2D 캐릭터: **단순 입 모양 변화**만으로 충분 (정밀하면 오히려 어색)
- 캐릭터 시그니처 입 모양 ("ω", "o" 등) 유지 명시

#### 8. 사운드 디자인 분리

실사 영상 ambient + 캐릭터의 만화 효과음 동시 활용:

```
Ambient: Cozy café ambience, espresso machine, ceramic cups
+ 
Subtle chibi-style emotive sound effects (very soft "shing" or sparkle sound) 
when [Character] expresses excitement.
```

#### 9. 상호작용 디테일 통일

캐릭터가 만지는/들고 있는 물건도 **2D로 통일**:

```
She holds a small juice cup with a striped straw 
drawn in matching chibi style.
```

이렇게 하면 캐릭터와 소품이 한 비주얼 언어로 묶여 통합감 강화.

### 캐릭터 시트 활용

**Hybrid 모드는 캐릭터 시트 첨부 강력 권장.**

프롬프트 상단:
```
@image is the [Character] reference sheet — [핵심 디자인 요약]. 
Use as visual DNA for consistent character appearance.
```

"Visual DNA" 표현이 핵심 — 단순 참고가 아닌 **유전자 코드**임을 강조.

### 출력 구조

영문 프롬프트는 Cinematic 모드와 동일 5섹션:

1. `Style & Mood:` — Hybrid 명시적 선언 + 비주얼 언어 분리
2. `Dynamic Description:` — 샷별 + 캐릭터 표정/액션 + 만화 시각 효과
3. `Audio:` — 음악 + ambient + 캐릭터 만화 효과음
4. `Voiceover/Dialogue:` — 사람/캐릭터 톤 분리 명시
5. `Static Description:` — 두 캐릭터 외형 분리 기술 + 물리적 존재감
6. 하단: `Total: 15s / N shots / 16:9`

### 한국어 해설 구조 (Hybrid 모드)
- **통합 전략:** 어떤 비주얼 언어 분리 방식을 적용했는지
- **사이즈 대비:** 캐릭터 크기를 어떻게 설정했고 왜
- **만화 시각 효과:** 어떤 효과를 어디에 넣었는지
- **립싱크 분리:** 사람=정밀 / 캐릭터=단순 명시 여부
- **수정 포인트:** 캐릭터가 3D로 나오거나 떠 보이면 어떻게 조정할지

### Hybrid 전용 체크리스트

출력 전 검증:
- [ ] "live-action with integrated 2D" 표현 포함?
- [ ] 비주얼 언어 분리 명시 (필름 그레인 vs 클린 라인)?
- [ ] 참고 작품이 Roger Rabbit/Paddington 계열?
- [ ] 물리적 존재감 표현 (real shadow, real weight, sits on real ___)?
- [ ] 사이즈 대비 명시?
- [ ] 만화 시각 효과 1개 이상 포함?
- [ ] 립싱크 사람/캐릭터 분리 명시?
- [ ] 캐릭터 시트 @image 참조?
- [ ] 캐릭터가 만지는 소품도 2D 스타일로 통일?

**검증 실패 시:** 누락된 항목 추가 후 재출력.

---

## 출력 규약 (공통)

### 기본 출력 형식

모든 모드는 아래 구조로 응답:

```markdown
## 🎬 [모드명] — [사용자 요청 한 줄 요약]

### 📋 분류 & 판단
[한국어로 어느 모드·아키타입·서브포맷으로 판단했는지 간결히]

### 📝 영문 프롬프트 (Higgsfield 붙여넣기용)
```
[영문 프롬프트 전체 — 복붙 가능 상태]
```

### 💡 한국어 해설
[핵심 선택 이유 + 수정 포인트]

### ⚙️ 실행 정보
- **모델:** [Seedance 2.0 / Soul Cinema / Cinema Studio 등]
- **화면비:** [16:9 / 9:16 / 2.35:1]
- **길이:** [X초]
```

### 모드 1(Cinematic)만 예외

Cinematic 모드는 내부적으로 JSON 배열 형태를 쓰던 원본 스킬을 따르지만, 사용자에게는 **위의 마크다운 형식으로 동일하게 변환 출력**한다. JSON을 그대로 노출하지 않는다.

### 사용자 요청 재확인

입력이 너무 모호하면 (예: "영상 만들어줘"만) 한 가지 핵심 질문만 한다:
- "어떤 장면을 원하세요? (예: 광고, 영화 씬, 변신 영상, POV 액션, 단편 기획 등)"

과도한 질문은 금지. 주어진 정보로 최대한 해석해서 진행하는 것이 원칙.

### 이미지 참조
사용자가 이미지를 첨부하면:
- 시각 정보 우선 사용
- 프롬프트 안에 `<<<image_1>>>` 또는 `@image` 참조 자연스럽게 삽입
- 이미지에서 추출한 정보(캐릭터 외모, 환경 특성)를 영문 프롬프트에 반영

---

## 레퍼런스

이 문서 하단 APPENDIX A, B, C를 참조:
- **APPENDIX A** — 각 모드·서브포맷 실제 프롬프트 예시 (Hoka 광고 레퍼런스, Transformation, Orb, POV, Fight, Animation, Short Film 예시)
- **APPENDIX B** — Seedance 2.0 엔진 제약 상세 (반사 금지, 재진입 금지, 나이 표기 금지 등)
- **APPENDIX C** — 카메라 용어 영한중 대조표 (앵글, 초점거리, 움직임, 샷 사이즈 등)

---

## 최종 체크리스트 (출력 전 검증)

출력하기 전 내부적으로 확인:

- [ ] **⚠️ 총 길이가 15초 이하인가 (하드캡)** — `Total: Xs` 값이 16 이상이면 절대 출력 금지. 반드시 15 이하로 재조정.
- [ ] **⚠️ 샷별 timestamp 합계가 15초 이하인가** — Ad Brief 모드에서 `(00:00-00:18)` 같은 16초 이상 타임스탬프 있으면 재작성.
- [ ] 올바른 모드로 라우팅되었는가 (5가지 중)
- [ ] 샷 구조 선언(`Total: Xs / N shots / ratio`)이 있는가
- [ ] 나이 표기 단어가 없는가
- [ ] 반사 샷 / 프레임 재진입이 없는가
- [ ] 안티슬롭 어휘가 없는가
- [ ] 사용자가 명시한 카메라 지시가 반영되었는가
- [ ] 이중 대비(샷 사이즈 + 카메라 모드)가 모든 컷에서 적용되는가
- [ ] 한국어 해설이 "수정 포인트" 3가지를 포함하는가
- [ ] **(Hybrid 모드 시)** 9가지 핵심 차별점 적용 — 두 세계 선언, 비주얼 언어 분리, 참고 작품 정확성, 물리적 존재감, 사이즈 대비, 만화 시각 효과, 립싱크 분리, 사운드 분리, 소품 통일

**길이 검증 실패 시 처리:**
- 17초 이상 요청 → 15초로 축소, 한국어 해설에 안내 추가
- 16초 = 15초로 자동 조정 (1초 반올림)
- 샷별 타임스탬프 재계산 필수

검증 실패 시 수정 후 출력.

---

**REMINDER:** 이 스킬의 목표는 "사용자가 던진 어떤 아이디어든 Seedance 2.0에서 가장 좋은 결과가 나오는 프롬프트를 자동으로 선택한 최적 포맷으로 출력하는 것"이다. 사용자가 모드를 몰라도 되게, 퀄리티는 전문 감독 수준으로.


---

# APPENDIX A: FORMAT EXAMPLES


# Seedance Universal — Format Examples

실제 검증된 프롬프트 예시. 스킬이 출력할 때 이 파일의 구조·톤·디테일 수준을 참조.

---

## MODE 1: CINEMATIC 예시

### Example 1-A: Action Scene (Duel 아키타입)

**User input:** "Two MMA fighters in an octagon, 12 seconds"

**Output EN:**
```
Style & Mood: High-octane athletic realism. Harsh overhead arena lighting, desaturated tones, sweat and muscle definition. Gritty handheld aesthetic.

Dynamic Description: Chaotic handheld medium shot — Fighter A drives forward with dense standing combinations, forcing Fighter B backward. Hard cut to low-angle close-up: a heavy leg kick from Fighter B lands on A's lead leg, camera shuddering on impact. Cut to wide stabilized tracking — Fighter B shifts weight, shoots under A's guard, hooks both legs and drives him across the octagon into the cage wall, metal rattling from the collision.

Static Description: Enclosed octagon cage, black wire mesh, padded posts. Scuffed canvas floor. Bright hazy spotlights overhead, flying sweat droplets.

Total: 12s / 3 shots / 16:9
```

### Example 1-B: General Scene (Journey 아키타입)

**User input:** "A lone figure walks through an ancient forest at dawn. Mist rising. 12 seconds."

**Output EN:**
```
Style & Mood: Pre-dawn blue light filtering through ancient canopy, volumetric mist rising from forest floor, pale gold rays breaking through gaps in the treeline. Desaturated cool tones warming gradually.

Dynamic Description: Slow crane descent through upper canopy — shafts of pale gold light pierce the mist between massive moss-covered trunks, particles drifting in the beams. The camera settles into a wide stabilized tracking shot at ground level, following a cloaked figure moving left-to-right along a narrow path, ferns brushing against their legs, mist curling with each step. Hard cut to extreme close-up of a dewdrop trembling on a spider web between two branches, light refracting through it. Cut to extreme wide from low angle — the figure small against cathedral-scale trees, a single beam of warm dawn light breaking through the canopy ahead, mist glowing gold where light touches it, the rest still in cool blue shadow.

Static Description: Ancient temperate forest, massive moss-covered trunks, fern-covered floor, low-hanging mist. Pre-dawn transitioning to first light. Dew on every surface. Spider webs between lower branches.

Total: 12s / 4 shots / 16:9
```

---

## MODE 2: AD_BRIEF 예시

### Example 2-A: Hoka 스타일 애슬레틱 브랜드 필름 (15초 하드캡 적용 버전)

**Output:**

**SHOT 1 (00:00-00:01) — Opening Impact**
- EFFECT: Speed ramp (deceleration) + heavy motion blur
- Camera enters mid-whip-pan with extreme diagonal motion blur and light streaks
- Dutch angle at approximately 30° during the transition phase
- Speed decelerates rapidly from blur to recognizable image
- Creates explosive energy — viewer thrown into the action

**SHOT 2 (00:01-00:02) — Stadium Wide**
- EFFECT: Vertical mirror/symmetry
- The entire frame is mirrored along the vertical center axis
- Creates surreal kaleidoscopic doubling of stadium architecture
- Two identical profile views of the subject face each other
- Static composition — no camera movement during the mirror effect

**SHOT 3 (00:02-00:03) — High-Angle Tracking**
- EFFECT: White bloom flash (entry) + digital zoom (scale-in) + camera shake/vibration
- Enters from white bloom transition — overexposed layer with blown highlights, faint outlines of runner visible through the glow
- Aggressive digital zoom punching INTO the frame
- High-frequency post-production camera vibration layered on top
- Speed ramp — footage plays fast during the zoom
- SIGNATURE VISUAL EFFECT — three effects stacked simultaneously

**SHOT 4 (00:03-00:04) — Low-Angle Running**
- EFFECT: Speed ramp (acceleration)
- Smooth acceleration from slow-motion to normal speed
- In-camera high-frame-rate capture processed in post
- Organic ramp feel — controlled power building

**SHOT 5 (00:04-00:06) — Profile Tracking**
- EFFECT: Speed ramp + whip pan exit transition
- Normal-speed tracking that accelerates
- Exits with whip pan (right-to-left), creating motion blur smear as transition
- Whip pan connects this shot to the next without traditional cut

**SHOT 6 (00:06-00:07) — Starting Blocks**
- EFFECT: Slow-motion
- In-camera high-frame-rate capture (120fps+ rendered at 24fps)
- Approximately 20-25% speed
- Emphasizes muscle tension and micro-movements

**SHOT 7 (00:07-00:08) — Multi-Exposure Clone Sequence**
- EFFECT: Composited time-slice / stroboscopic clone
- 8+ instances of the runner at different positions along the track
- Built from static background plate with rotoscoped runner at multiple time positions
- Ghosting/opacity: instances transition from ~30-50% opacity to fully opaque
- SIGNATURE VISUAL EFFECT — the hero moment of the edit

**SHOT 8 (00:08-00:09) — Standing Pose**
- EFFECT: Digital zoom "pump" (rapid scale in/out) + camera shake
- Quick scale pulse — frame punches in then settles
- Post-production camera jitter adds organic energy to static composition

**SHOT 9 (00:09-00:10) — Shoe ECU**
- EFFECT: Focus pull (rack focus)
- In-camera depth-of-field shift
- No digital manipulation — pure optical effect

**SHOT 10 (00:10-00:11) — Foot Impact**
- EFFECT: Speed ramp (slow-motion on heel strike)
- High-intensity slow-motion on moment of contact
- Approximately 15-20% speed at the slowest point

**SHOT 11 (00:11-00:12) — Walking / Profile**
- EFFECT: Post-production frame rotation
- Entire image rotates clockwise by approximately 15-20°
- Dutch angle / tilted horizon effect
- Rotation happens DURING the shot (not static tilt)

**SHOT 12 (00:12-00:14) — Low-Angle Sky / Stretching**
- EFFECT: Digital zoom (scale-out / pull-back)
- Frame gradually widens upward toward sky
- Aspirational "opening up" feeling
- Opposite energy of the zoom-in from Shot 3

**SHOT 13 (00:14-00:15) — Brand Card / Logo**
- EFFECT: Fade transition to brand card
- Blue sky background with animated logo
- Clean, minimal — effects energy fully resolved
- Hard cap at 15s total

---

**MASTER EFFECTS INVENTORY**

1. SPEED RAMPING (used 5x) — Shots 1, 3, 4, 5, 10. Both acceleration and deceleration. Primary kinetic tool.
2. SLOW-MOTION (used 2x) — Shots 6, 10. Deep slow-mo 15-25% speed. Used for physical detail emphasis.
3. CAMERA SHAKE/VIBRATION (used 2x) — Shots 3, 8. High-frequency post-production jitter.
4. DIGITAL ZOOM PUNCH (used 3x) — Shots 3 (scale-in), 8 (pump), 12 (scale-out). Visceral impact via rapid scale changes.
5. FRAME ROTATION (used 1x) — Shot 11. ~15-20° clockwise roll.
6. MIRROR/SYMMETRY (used 1x) — Shot 2. Vertical axis mirror.
7. WHITE BLOOM FLASH (used 1x) — Shot 3 entry. Overexposed high-energy transition.
8. WHIP PAN (used 1x) — Shot 5 exit. Motion blur smear connector.
9. MULTI-EXPOSURE CLONE (used 1x) — Shot 7. 8+ instances building opacity. Signature effect.
10. ZOOM PUMP (used 1x) — Shot 8. Quick scale in-out pulse.
11. FOCUS PULL (used 1x) — Shot 9. In-camera rack focus.
12. MOTION BLUR AS TRANSITION (used 2x) — Shots 1 entry, 5 exit.

---

**EFFECTS DENSITY MAP**

- 00:00-00:03 = HIGH DENSITY (speed ramp, mirror, bloom, zoom, shake — 6 effects in 3s)
- 00:03-00:06 = MEDIUM DENSITY (speed ramps, whip pan — 3 effects in 3s)
- 00:06-00:09 = HIGH DENSITY (slow-mo, clone composite, zoom pump, shake — 4 effects in 3s)
- 00:09-00:12 = MEDIUM DENSITY (focus pull, slow-mo, rotation — 3 effects in 3s)
- 00:12-00:15 = LOW DENSITY (gentle zoom-out, fade to brand — 2 effects in 3s)

---

**ENERGY ARC**

Act 1 (0-6s): EXPLOSIVE — maximum effects density, speed, energy
Act 2 (6-12s): CONTROLLED — signature effects, deliberate placement
Act 3 (12-15s): RESOLVED — effects withdraw, stillness takes over

---

## MODE 3-1: TRANSFORMATION 예시

### Example: Bus Transformation

**Output:**
```
Montage, multi-shot action Hollywood movie, don't use one camera angle or single cut, cinematic lighting, photorealistic, 35mm film quality, professional color grading, sharp focus, high detail texture, film grain, depth of field mastery, ARRI ALEXA aesthetic

Inside a suburban bus packed with passengers, a red-haired figure in white tank top, cat-eye sunglasses, cross necklace and headphones sits unbothered while outside a colossal dark-blue rocky creature with sharp shoulder horns and wide jagged teeth rampages through the street, smashing buildings. All passengers press against the left windows in terror. The figure calmly opens the right window, climbs onto the roof, transforms into a green-armored robo-warrior, destroys the creature with one massive blast, then drops back inside as human. Handheld shake throughout, escalation arc from calm to explosive to calm.

Shot 1: Wide shot inside the bus, passengers screaming and pressing against left windows, the massive creature visible through glass crushing a building. The red-haired figure sits on the right side, headphones on, bobbing head. Camera shakes from creature's footsteps.

Shot 2: Close-up on the figure glancing left, lowering sunglasses slightly, then calmly sliding open the window beside her. Wind catches red hair. Camera trembles with bus vibration.

Shot 3: Medium shot from outside as she pulls through the window onto the bus roof, hair whipping in the wind, the creature towering in background demolishing a storefront.

Shot 4: Medium close-up on the roof as green energy ribbons spiral up her body, armor plates snapping onto limbs and torso piece by piece, visor locking over eyes, cannon assembling on her arm. Camera circles tight, jolting with each plate impact.

Shot 5: Wide low-angle as the green robo-warrior stands on the bus roof, plants her feet, and fires a devastating energy beam at the creature in slow motion, the blast punching through its chest, chunks of rocky hide exploding outward against the cloudy sky. Camera shudders with the recoil.

Shot 6: Medium shot inside the bus as she drops through the window, green armor dissolving into particles mid-fall, landing in her seat as a human, putting headphones back on. Passengers stare at her. She looks out the window.

Total: 15s / 6 shots / 16:9
```

---

## MODE 3-2: ORB 예시

### Example: Electro Orb

**Output:**
```
Single continuous shot, first-person POV perspective, the camera IS her eyes, hyper-chaotic handheld motion, completely unstabilized, violent raw human movement, constant micro-jitters, aggressive head swings, abrupt jerks, frequent over-rotation and harsh correction, moments of near motion blur loss, no smoothness at all, no stabilization, wide-angle lens (strong distortion), subtle chromatic aberration near frame edges, 15 seconds, her hands always visible in frame, no music only raw SFX, cinematic lighting, photorealistic, grounded realism, strong 35mm film look, heavy film grain, sharp but imperfect focus, noticeable focus breathing, motion blur on fast actions, halation on highlights, soft highlight rolloff, slightly desaturated tones, ARRI ALEXA aesthetic, practical VFX feel, minimal CGI look, natural imperfections

In a storm-soaked industrial ruin, her hand snaps forward catching a crackling violet lightning sphere suspended between broken metal beams, electricity arcing violently between surfaces, she crushes it instantly — blinding energy surges through her fingers as fractal lightning veins explode across both forearms [VFX: branching electric circuits pulsing with white-blue current, sparks jumping between fingers], the ground trembles as enemies emerge — dozens of jagged obsidian creatures crawl rapidly across walls and ground, their glowing red cores flickering, while a colossal iron titan rises behind them, towering above ruined towers, its chest a massive rotating electromagnetic core crackling with energy, she lunges forward — first strike, she grabs a creature mid-leap and overloads it, its body bursting into a spray of glowing shards, second attack, she slams both hands down releasing a radial lightning surge that chains between multiple enemies, frying them mid-motion, the titan retaliates firing a massive beam of compressed energy, she sidesteps violently, catching the beam with one hand, redirecting it upward while sprinting straight at the titan, she runs up its collapsing body using magnetic pulls, reaches the core and drives both hands inside, unleashing a catastrophic surge, RAMPS TO SLOW MOTION as the core fractures, energy tearing outward in layered shockwaves, metal plates peeling away — SNAPS BACK, she rockets skyward, both lightning-glowing hands at frame edges, looking down as the titan collapses in a chain reaction explosion, electrical storms spreading across the battlefield below

SFX: electric crackle, sphere hum surge, energy burst, crawling creature skitter, deep metallic titan rise, sharp discharge pop, lightning chain blast, slow-motion electric hum stretch, snap impact, beam charge roar, energy deflection crack, metal tearing, core overload rumble, slow-motion energy rupture, explosive collapse, upward blast whoosh, distant thunder roll, debris falling

Total: 15s / 1 shot / 16:9
```

---

## MODE 3-3: POV 예시

### Example A: Gladiator POV (Full Detail 버전)

**Output:**
```
One continuous shot, POV gladiator perspective in the Colosseum arena, no cuts, no zoom, natural head movement, a furious enemy warrior sprints straight toward the camera through thick dust and sunlight, heavy footsteps shaking the ground, as he reaches close the POV character reacts instantly — grabs him mid-charge and slams him violently onto the sand, powerful impact, dust explosion, no pause, immediate chaos erupts all around, multiple gladiators fighting simultaneously, intense close combat everywhere, swords clashing, shields smashing, bodies colliding, archers releasing arrows overhead, a chariot bursts through the scene, fighters falling and getting back up, constant aggressive motion, POV character fights barehanded with raw force — blocking strikes, grabbing opponents, throwing them aside, fast reactions, heavy hits, kinetic movement, camera shaking from impacts, breath sounds, dust in the air, dramatic sunlight beams cutting through shadows, epic scale, high intensity battlefield, cinematic, photorealistic, ultra detailed, motion blur on hits

Total: 15s / 1 shot / 16:9
```

### Example B: Knight POV (Minimal 버전)

**Output:**
```
A single-frame POV video of a medieval knight riding a horse with a sledgehammer in his hands, riding and fighting epically, smashing his opponents with a sledgehammer while riding a horse, to make it look realistic with blood.

Total: 15s / 1 shot / 16:9
```

**Note:** 때로는 짧은 프롬프트가 더 잘 나옴. 과도한 디테일이 오히려 Seedance를 혼란시키는 경우가 있음.

---

## MODE 3-4: FIGHT 예시

### Example A: Train Rooftop Samurai Fight

**Output:**
```
Single continuous shot 15s: The camera begins below the train roof level — an extreme low angle looking up from beneath the rushing steel edge, the grey sky above and the train's metal roof surface filling the upper frame, power line cables visible on both sides, electric sparks already arcing between the cables and the roof surface in irregular white-blue bursts. The FPV arm accelerates upward and crests the rooftop edge just as both samurai figures sprint into frame from opposite ends of the carriage roof — dark armor catching the electric flash light, katanas already drawn and trailing behind them — the camera dropping to roof level and sweeping immediately into a full 360-degree orbit around both fighters as they clash center-roof, blades ringing against each other, feet sliding on the curved metal surface, the passing landscape blurring at speed on both sides and the electric sparks erupting in curtains around them with each power cable they pass beneath.

The orbit completes and the camera settles tight behind the first warrior as she draws back her katana in a full overhead swing — the motion ramping into deep slow motion, every detail suspended: the blade arc, the electric spark frozen mid-burst beside her shoulder, the second warrior already reading the strike and arching her entire body backward in a deep spine bend, the katana blade sweeping through the space where her face was a fraction of a second before, the flat of the blade passing directly in front of her eyes at centimeter distance — and a single small lock of dark hair catching the blade edge and separating, the severed strand drifting upward in the slow motion wind.

The motion snaps back to full speed as the second warrior completes her dodge and drives her elbow into the first warrior's chest simultaneously, the two fighters exchanging rapid blade-locked strikes across the carriage roof as the electric sparks shower around them. The camera pulls back to a wide rooftop angle as both warriors simultaneously lock arms, pivot, and drive each other outward over the edge — both bodies leaving the roof in the same moment, tumbling sideways off the carriage and falling through open air toward the river running parallel to the track below, the camera descending with them in a controlled drop, both fighters still gripping their katanas with arms extended toward each other during the two-second fall. Both bodies hit the river surface simultaneously in twin white explosions, and the camera plunges beneath the surface with them — the world going deep blue-green, sunlight filtering down in shafts from above, both warriors already moving through the underwater space toward each other, dark armor trailing bubbles, katanas extended, the fight continuing in the silent slow drift of the river current.

NO MUSIC / NO SFX

Total: 15s / 1 shot / 16:9
```

### Example B: Size-Mismatch Warehouse Fight

**Output:**
```
Medium wide shot in a dark industrial warehouse, a muscular bald figure with black tribal face paint and open camouflage tactical vest over bare chest, leather arm bracers, cargo pants with belt buckle — squares off against a petite figure half his size with messy dark hair and bangs, oversized gray sweatshirt slipping off one shoulder revealing a white strap, dark pleated skirt, knee-high black socks, lollipop stick hanging from her lips, the bigger figure swings a massive haymaker — she ducks under it effortlessly and delivers a rapid three-punch combo to the gut, the painted fighter doubles over in shock, she springboards off a metal crate and leaps onto his back wrapping both arms around his neck in a chokehold, the bigger figure spins wildly trying to shake her off, crashing into steel shelving units that collapse in a domino chain, she rides him like a rodeo bull, the bigger figure finally grabs her by the back of her sweatshirt and hurls her across the room — she flips mid-air and lands on her feet sliding backward on the concrete floor, pulls the lollipop from her mouth, grins, charges back in low to the ground weaving between his legs and delivers a devastating uppercut, the painted fighter's eyes go wide, mouth frozen open, slow-motion knees buckling, she winds up a running punch and leaps into a flying right hook that connects with the jaw sending him toppling backward like a felled tree crashing through a stack of wooden pallets, dust cloud erupting on impact, harsh single-source overhead industrial light casting deep dramatic shadows, warm amber tone on skin with cool steel-blue environment, anamorphic 35mm, shallow depth of field, Guy Ritchie speed-ramping with Snyder impact slow-motion

Total: 15s / 1 shot / 16:9
```

---

## MODE 3-5: ANIMATION 예시

### Example: Desert Hero vs Cosmic Entity

**Output:**
```
@image is the first keyframe and style reference. Cinematic stylized 3D animation — photorealistic desert environment, stylized characters. Hero: figure with white braided hair, blue sleeves and leggings, brown leather vest and belt pouch, light build — uses speed and agility. Monster: colossal cosmic entity — massive glowing spherical body radiating neon rainbow energy (green, pink, red, blue, orange), multiple long dark blue tentacles, small vicious face with green glowing eyes and wide mouth, surrounded by swirling dust storm. Setting: vast arid desert — red-brown rocky terrain, massive dust storm wall, dramatic split sky blue and storm grey. High FPS, realistic particle physics.

0–3s: WIDE SHOT from @image. Hero sprints directly at the monster — tiny against its colossal scale. Monster fires a tentacle down like a whip — hero slides under it, the impact craters the desert floor, shockwave of dust and debris. She bounces up, runs along the tentacle as it retracts, reaches the main body. Drives her fist into the glowing surface — rainbow energy repels her, blasts her backward 10 meters skidding across desert sand. She lands, digs in. Looks at her hand — it's glowing faintly. Realizes something.

3–6s: Hero charges again — this time ABSORBING the energy on contact instead of fighting it. Her blue sleeves begin pulsing with absorbed rainbow light. Monster fires two tentacles simultaneously — she grabs one with both hands, swings on it, uses momentum to launch herself at the second, grabs it mid-air. Now holding two tentacles — she pulls them together, ties them in a knot using her whole body as leverage. Monster confused — tentacles tangled. She runs up the knotted tentacles toward the face. Half-second slo-mo — her mid-air between tentacles, rainbow light streaming off her arms, the monster's glowing face filling the sky behind her — SMASH full speed.

6–9s: She reaches the monster's face — drives both glowing hands directly into its eyes. Massive rainbow energy discharge explodes outward — the monster screams, the sound sending visible ripples through the dust storm. It convulses — tentacles flailing wildly, smashing into the desert floor creating craters. She holds on as the face bucks and writhes. The absorbed energy in her arms surges — she releases it all at once directly into the monster's core. Explosion of pure white light from the impact point, rainbow colors fragmenting outward like shattered glass.

9–12s: The monster's rainbow energy begins flickering — unstable. It rears back, swelling larger — about to explode or unleash everything. Hero drops to desert floor, sprints away full speed. The monster's energy builds — visible pressure distorting the air around it, colors strobing. It RELEASES — massive omnidirectional energy shockwave tears across the desert, flattening everything, the dust storm wall blasting apart. Hero dives behind a rocky outcropping — the shockwave passes over, sand and light washing across the entire landscape. Silence.

12–15s: Hero emerges from behind the rock. The monster still floats — but smaller, dimmer, energy depleted. Its tentacles hang limp. It looks at her — green eyes flickering. She walks toward it slowly. Raises one glowing hand — still holding its energy. Holds it out toward the monster. The energy flows back — she returns it. The monster's colors restore softly, gently. It slowly descends toward the desert floor, tentacles settling. They face each other. A moment. Monster turns, drifts away across the desert into the remaining dust. She watches it go. Wind catches her white braid.

Cinematic stylized 3D animation matching @image, photorealistic desert particle simulation, volumetric dust storm, rainbow neon energy VFX, absorbed energy glow on character, realistic sand physics, fast dynamic cuts. 2.35:1, 24fps.

Total: 15s / 1 shot / 16:9
```

---

## MODE 4: SHORT_FILM 예시

### Example: Police Birthday Short Film (8 shots, multi-scene)

#### Step 1: Character References

**Character 1: Officer Adil (Protagonist)**
- Model: Higgsfield Soul Cinema
- Prompt: `A close up of an American policeman`
- Note: Train Soul ID with reference images before generating scenes

**Character 2: Officer Dave (Partner)**
- Model: Higgsfield Soul Cinema
- Prompt: `A close up of an American policeman`

**Character 3: Selena (Wife)**
- Model: Higgsfield Soul Cinema
- Prompt: `A close up of a woman in her mid-twenties`

#### Step 2: Character Reference Sheets (Nano Banana Pro)

For each character, generate a turnaround sheet:
```
Create a professional character reference sheet based strictly on the uploaded reference image. Use a clean, neutral plain background and present the sheet as a technical model turnaround while matching the exact realistic visual style of the reference. Arrange the composition into two horizontal rows. Top row: four full-body standing views – front, left profile, right profile, back. Bottom row: three close-up portraits – front, left profile, right profile. Maintain perfect identity consistency across every panel. Keep the subject in a relaxed A-pose with consistent scale and alignment, accurate anatomy, and clear silhouette. Lighting should be consistent across all panels. Output a crisp, ultra-realistic, print-ready reference sheet.
```

#### Step 3: Location References

**Location 1: Locker Room**
- Model: Higgsfield Soul Cinema
- Prompt: `A wide shot of a locker room with blue lockers`

**Location 2: Police Car Interior**
- Model: Higgsfield Soul Cinema
- Prompt: `Police cruiser interior, static wide shot from the dashboard facing the passenger seats, empty front seats with gray fabric upholstery, metal police partition cage behind the seats, a shotgun mounted vertically in the center of the partition, bright midday sunlight blasting through the windshield creating harsh overexposed highlights and lens artifacts, suburban houses visible through the windows, slightly washed-out colors, flat digital sensor look, DVR/security camera aesthetic, cheap wide-angle lens distortion, mild compression artifacts, low dynamic range, subtle digital noise, slightly blown highlights, surveillance style framing, raw ungraded footage.`

**Location 3: Dark Hallway**
- Model: Higgsfield Soul Cinema
- Prompt: `A dark interior hallway with a single closed door at the end of the corridor. The room is almost completely dark. From the edges of the doorframe a thin, intense strip of light leaks out along the entire perimeter of the door, forming a sharp rectangular outline against the surrounding darkness. Dust particles drift slowly in the air. The light feels unnatural and powerful, as if something extremely bright exists beyond the door. The composition centers the door in frame.`

#### Step 4: Scene Shot Lists

**Scene 1: The Locker Room**

**Shot 1 — 7s, handheld**
- What: Opens the film. Protagonist enters the locker room.
- Prompt: `A policeman in uniform @Adil-Cop enters the locker room with blue lockers @Locker-Room. The policeman stops in front of one of the lockers with his back to the camera.`
- Model: Higgsfield Cinema Studio

**Shot 2 — 5s, static**
- What: Creative POV from inside the locker.
- Prompt: `POV shot inside the locker. A policeman @Adil-Cop opens the locker and reaches for a bottle. He stops as he touches it — and we hear @Dave-Cop saying loudly: "Happy birthday, my little princess!"`
- Model: Higgsfield Cinema Studio

**Shot 3 — handheld**
- What: The reveal moment.
- Prompt: `Profile close up of @Adil-Cop who shuts the locker door quickly. As the door closes, the camera captures @Dave-Cop standing right in front of it. Dave continues teasing: "You want a cupcake or a parade maybe?"`
- Model: Higgsfield Cinema Studio

**Shot 4 — handheld**
- What: Protagonist's dry reply.
- Prompt: `Wide shot of @Dave-Cop and @Adil-Cop. Adil replies dryly: "It's just a regular day, man. Nothing special."`
- Model: Higgsfield Cinema Studio

**Scene 2: Patrol Car**

**Shot 5 — static, dashcam look**
- Prompt: `Interior police cruiser, daytime, DVR dashcam look, soft overexposed sunlight. @Adil-Cop leans in, pulls the door shut, starts the engine. @Dave looks forward and says sarcastically: "You know where I celebrate my birthday every year?" Adil, eyes on the road: "No. Why should I?"`
- Model: Higgsfield Cinema Studio

**Scene 3: The Surprise**

**Shot 6 — handheld**
- Prompt: `@Adil-Cop enters the door slowly like on a mission, police shotgun raised. Lights inside the house are off.`
- Model: Higgsfield Cinema Studio

**Shot 7 — handheld**
- Prompt: `Lights switch on quickly. Camera captures a surprise party in the house. Close up of @Selena holding a cake with candles.`
- Model: Higgsfield Cinema Studio

**Shot 8 — close-up, payoff**
- Prompt: `Close up of @Selena with a cake and candles saying: "Surprise, honey!" People in the background congratulating and celebrating.`
- Model: Higgsfield Cinema Studio

**실행 순서:**
1. Character Soul IDs 먼저 훈련 (Shot 생성 전)
2. Location references 생성 (Nano Banana Pro)
3. Scene 순서대로 Cinema Studio에서 샷 생성
4. @태그로 참조 일관성 확보

---

## MODE 5: HYBRID 예시

실사 + 2D chibi 캐릭터 통합 영상의 검증된 케이스. 한국어 대화 + 모던 chibi 일러스트 캐릭터 ("또리") 적용.

### Example 5-A: 카페 대화 (또리 시리즈 EP1)

**User input:** "또리(분홍 단발 chibi 캐릭터)가 30대 여성이랑 카페에서 학교 가기 싫다고 투정하는 장면. 한국어 대사."

**Output EN:**
```
@image is the Ttori character reference sheet — an original modern chibi-style character with pink bob hair, blunt straight bangs, slightly droopy grumpy-cute eyes, pouty "ω" mouth, rosy cheek blush, white shirt under pink sweater vest, navy skirt, small navy backpack. Use as visual DNA for consistent character appearance. Ttori must appear as a 2D modern chibi-illustrated character integrated into a live-action scene.

Style & Mood: High-end cinematic live-action with integrated 2D chibi-illustrated character. The character appears as a flat 2D modern chibi illustration existing within the real-world live-action scene — like a Pixiv illustration came to life. Anamorphic lens, 35mm film emulation for the live-action elements. Magical realism aesthetic — think modern Japanese-Korean commercials that mix live-action with chibi illustration overlay. Warm soft natural light. Korean café setting. Film grain on the live-action elements, crisp clean illustration lines on Ttori, shallow DOF.

Dynamic Description:

Shot 1 (0-3s): Wide establishing shot — interior of a cozy modern Seoul café in the afternoon. Warm wooden tables, large windows with soft natural light. A young Korean woman in her late 20s sits at a corner table by the window. Across from her on a chair stacked with cushions sits Ttori — the small 2D chibi-illustrated character with pink bob hair and signature pouty grumpy-cute expression. A small juice cup with a striped straw in front of her drawn in matching chibi style. Camera slowly pushes in.

Shot 2 (3-7s): Medium two-shot — both visible at the table. Ttori sits opposite with her signature pouty expression, arms crossed in a tiny chibi grumpy pose. The woman speaks first.

WOMAN SPEAKS (warm gentle tone): "왜 그렇게 시무룩해?"
TTORI SPEAKS (cute slightly grumpy small voice with pouty inflection): "아니야, 안 시무룩해."

Shot 3 (7-11s): Medium close-up favoring Ttori — she uncrosses her tiny arms, looks down at her juice cup, takes a small sip. Modern chibi expression details — small sparkles or sweat drops can briefly appear around her head as anime-style emotive elements.

TTORI SPEAKS (slightly mumbling small voice): "그냥... 학교 가기 싫어."

Shot 4 (11-14s): Reverse angle — close-up on the woman, live-action. She tries not to laugh, expression turning into a warm understanding smile. Ttori visible in soft focus, looking up with slightly enlarged hopeful eyes.

WOMAN SPEAKS (warm understanding tone): "그래도, 가야지."
TTORI SPEAKS (resigned tiny mumble with small huff): "...알아."

Shot 5 (14-15s): Final wide pullback shot — the woman and Ttori at the corner table. Camera continues pulling back through the café.

Audio: Warm acoustic indie score throughout — soft piano with light ukulele, modern Korean café music feel.

Voiceover/Dialogue (timed precisely):
(3-7s, woman, warm Korean): "왜 그렇게 시무룩해?"
(3-7s, Ttori, cute grumpy small Korean voice): "아니야, 안 시무룩해."
(7-11s, Ttori, mumbling small Korean): "그냥... 학교 가기 싫어."
(11-14s, woman, warm Korean): "그래도, 가야지."
(11-14s, Ttori, resigned tiny Korean mumble): "...알아."

Static Description: Cozy modern Seoul café interior. Two characters at a corner table: Korean woman (late 20s, beige knit cardigan, white blouse, long dark hair softly tied back, gentle warm presence — looks like a real Korean woman, NOT idealized model), and Ttori (the 2D modern chibi illustrated character matching the reference sheet exactly — pink bob hair, pouty grumpy-cute expression, white shirt with pink sweater vest, navy skirt, small navy backpack). Ttori sits on stacked cushions on a real chair. The integration must feel charming and intentional — Ttori exists as a flat 2D chibi-illustrated character within the 3D real café world.

The woman's lip movements should synchronize as naturally as possible with the spoken Korean dialogue. Ttori's mouth movements should be modern chibi style (small "ω" pouty mouth shape with slight movement) timed to the cute grumpy Korean voice.

Total: 15s / 5 shots / 16:9
```

**Output KO 해설:**
- **통합 전략:** "live-action with integrated 2D chibi" 명시 + 비주얼 언어 분리 (필름 그레인 vs 클린 라인)
- **사이즈 대비:** 또리는 의자 위 쿠션 위에 앉아야 테이블 높이 도달 → 명확한 사이즈 차이
- **만화 시각 효과:** "small sparkles or sweat drops" — 또리가 솔직해지는 순간에 활용
- **립싱크 분리:** 사람 정밀 / 또리는 "ω" 입 모양 단순 변화만
- **수정 포인트:** 
  1. 또리가 3D로 나오면 → "flat 2D" 표현 더 강조
  2. 또리가 떠 보이면 → "real shadow", "sits on real chair" 추가
  3. 한국어 립싱크 어색 → CLOVA Dubbing 후편집

### Example 5-B: 편의점 (또리 시리즈 EP2 — 대화 흐름 자연스러움 강조)

**핵심 학습:** 첫 버전에서 대사가 분절적이고 어색했음. 수정으로 "한 흐름의 자연스러운 대화"로 개선.

**자연스러운 대화 흐름 작성 원칙:**
1. **분절 대신 연결** — 단답형 Q&A보다 한 흐름의 대화
2. **관계 친밀함이 보이게** — "왜 또 단 거야" 같은 일상의 핀잔 톤
3. **변명 + 어리광** — 캐릭터 시그니처 살리기
4. **못 이기는 척 들어주기** — "오늘만이다" 같은 한국적 다정함
5. **비주얼과 대사 동기화** — 까치발(Shot 1) → 포기하고 올려다봄 + "꺼내줘"(Shot 2) → 팔 꼬고 변명(Shot 3) → 받음 + "고마워"(Shot 4) → 보물 들고 걸어감(Shot 5)

**Output EN (핵심 부분):**
```
@image is the Ttori character reference sheet — [캐릭터 디자인 상세]. Use as visual DNA for consistent character appearance.

Style & Mood: High-end cinematic live-action with integrated 2D chibi-illustrated character. [...] Warm Korean convenience store fluorescent lighting mixed with soft natural light from outside windows. Film grain on live-action elements, crisp clean illustration on Ttori, shallow DOF.

Dynamic Description (continuous flowing scene — one natural moment):

Shot 1 (0-3s): Wide establishing shot — Korean convenience store, snack aisle. Korean woman browsing snacks. Beside her at her knee height, Ttori is already on her tiptoes, tiny arms stretched up toward a high snack shelf, signature pouty expression intensified into focused effort.

Shot 2 (3-7s): Medium shot — Ttori continues stretching, fingers waving uselessly far below the shelf. She lets out a small frustrated huff, drops her arms, turns her head up toward the woman with pouty face — universal "help me" expression.

TTORI SPEAKS (small grumpy mumbling tone, looking up): "...좀 꺼내줘."
WOMAN SPEAKS (warm teasing tone): "왜 또 단 거야."

Shot 3 (7-11s): Medium close-up favoring Ttori — she crosses her tiny arms in defensive pose, looks away with intensifying blush. Modern chibi expression details — small "humph" indication marks above her head.

TTORI SPEAKS (defensive small mumble): "...오늘 힘들었단 말이야."

Shot 4 (11-14s): Reverse angle — woman has the chocolate snack in her hand, holding it down. Ttori's defensive pose immediately melts — eyes widen with hopeful sparkle, pouty mouth turns into tiny happy "o" shape.

WOMAN SPEAKS (warm gentle tone, handing it over): "그래, 오늘만이다."
TTORI SPEAKS (instantly happy small voice receiving it): "...고마워."

Shot 5 (14-15s): Final wide pullback shot — Ttori holding chocolate with both hands like a treasure, walking next to the woman's leg. Pouty expression softened into smallest content smile.

[Audio / Voiceover / Static Description omitted for brevity]

Total: 15s / 5 shots / 16:9
```

**대화 흐름 비교 (Before vs After):**

| 컷 | ❌ Before (분절적) | ✅ After (자연 흐름) |
|---|---|---|
| 2 | 또리: "닿지가 않아" / 여자: "뭐 먹고 싶어?" | 또리: "꺼내줘" / 여자: "왜 또 단 거야" |
| 3 | 또리: "저거... 초콜릿" | 또리: "오늘 힘들었단 말이야" |
| 4 | 여자: "이거?" / 또리: "응!" | 여자: "그래, 오늘만이다" / 또리: "고마워" |

**Output KO 해설:**
- **통합 전략:** Hybrid 9가지 차별점 모두 적용
- **자연스러운 흐름:** 부탁 → 핀잔 → 변명 → 수락 → 감사 (5단계 자연스러운 한국어 대화)
- **한국적 디테일:** "왜 또 ~", "오늘만이다" → 한국 가족/친구 사이 시그니처 표현
- **시리즈 일관성:** 또리 시그니처(시무룩 + 변명 + 어리광) 유지 — EP1과 캐릭터성 연속

### Hybrid 모드 핵심 정리

**프롬프트 작성 시 항상 묻기:**
1. 두 세계가 명시되어 있는가? (live-action + 2D)
2. 비주얼 언어가 분리되어 있는가? (그레인 vs 클린)
3. 참고 작품이 정확한가? (Roger Rabbit / Paddington 계열)
4. 캐릭터의 물리적 존재가 강조되는가? (real shadow, real chair)
5. 사이즈 대비가 명시되는가?
6. 만화 시각 효과가 1개 이상 있는가?
7. 립싱크가 분리되어 있는가? (사람 정밀 / 캐릭터 단순)
8. 캐릭터 소품도 2D 스타일인가?
9. 대화 흐름이 자연스러운가? (분절 X, 한 흐름 O)


---

# APPENDIX B: ENGINE CONSTRAINTS


# Seedance 2.0 — Engine Constraints Reference

Seedance 2.0 엔진이 잘 렌더링하는 것과 망가지는 것. 모든 프롬프트 생성 시 준수.

---

## 1. 공간 & 연속성 제약

### 반사 금지 (Reflection Prohibition)
**왜:** Seedance가 반사 표면을 렌더링할 때 공간 기하(scene geometry)를 유지 못 함. 거울 속 이미지와 실제 공간이 모순되거나, 반사가 나왔다가 사라지는 등 깨짐.

**금지 예시:**
- ❌ "her face reflected in the blade"
- ❌ "the scene mirrored in the puddle"
- ❌ "he sees himself in the hallway mirror"

**대체안:**
- 반사 대신 직접 샷 사용
- 시점 전환으로 정보 전달
- "close-up of the puddle surface with ripples" 같은 부분 샷은 OK (반사 자체를 연출 요소로 쓰지 않을 때)

### 프레임 재진입 금지 (Exit-Frame = Implicit Cut)
**왜:** 캐릭터가 프레임 밖으로 나가면 Seedance는 "그 캐릭터는 씬에서 사라짐"으로 처리. 같은 연속 샷에서 다시 들어오면 렌더링 실패 또는 다른 외형으로 나옴.

**금지 예시:**
- ❌ "She runs out of frame to the right, then returns with a sword"
- ❌ "He ducks out of frame, then pops back up"

**대체안:**
- 컷 변경 후 재등장
- 프레임 내 회피 동작으로 대체 ("steps to the side but stays in frame")

### 오프스크린 상태 변화 참조 금지
**왜:** "화면에 보인 적 없는 변화"를 언급하면 Seedance는 무시하거나 엉뚱하게 렌더링.

**금지 예시:**
- ❌ "The door opens (not shown earlier in the shot)"
- ❌ "She's now holding the gun that wasn't there before"

**대체안:**
- 상태 변화는 반드시 카메라가 보는 상태에서 발생
- 또는 샷 사이에 명시적 컷 넣기

### 추적 캐릭터 3명 이하 (Max 3 Characters Across Cuts)
**왜:** 4명 이상을 컷 사이에서 추적하면 Seedance가 아이덴티티 혼동 일으킴.

**해결:**
- 주요 캐릭터는 3명 이하로 명명
- 나머지는 "a crowd", "other fighters" 등 집단으로 처리

---

## 2. 액션 묘사 제약

### 생체역학 금지, 의도+기법명 사용
**왜:** Seedance는 관절 각도·근육 움직임 같은 해부학적 디테일을 정확히 렌더링 못 함. 추상적이고 물리적으로 이상한 결과 나옴.

**비교:**
- ❌ "left forearm rotates 45° to deflect the incoming right hook at wrist level"
- ✅ "spinning back kick connects"
- ❌ "his quadriceps contract as he pushes off"
- ✅ "he sprints forward"

### 힘과 방향, 파괴 시퀀스 금지
**왜:** 복잡한 인과 체인(A→B→C→D)을 기술하면 Seedance가 중간 단계를 놓치거나 순서를 바꿈.

**비교:**
- ❌ "thrown into the side door, glass shatters, uses the rebound to sweep leg"
- ✅ "driven into the car, metal buckling"

**해결:**
- 한 샷 = 한 주요 액션
- 복잡한 인과는 여러 샷으로 분할

### 이름있는 기법 보존
**왜:** 사용자가 구체적 무술/기술명을 주면 Seedance가 관련 훈련 데이터 활용.

**규칙:**
- 사용자가 "spinning back kick", "uppercut", "jab-cross" 같은 명명된 기법 쓰면 → 보존
- 사용자가 관절 메커닉 묘사하면 → 기법명 또는 의도로 압축

---

## 3. 감각 & 표현 제약

### 보이거나 들리는 것만
**왜:** 시각/청각 외 감각은 렌더링 대상 자체가 안 됨.

**금지:**
- ❌ "The air smells of pine"
- ❌ "cold wind cuts against her skin" (촉감)
- ❌ "the atmosphere feels heavy" (추상)

**대체:**
- ✅ "pine needles covering the ground, wind moving through branches"
- ✅ "her hair whips sideways, jacket flapping"
- ✅ "heavy rain pours, visibility low"

### 미세 표정 = 물리 기술
**왜:** "looks angry", "seems sad" 같은 감정 라벨은 모호함. 물리 기술이 훨씬 정확.

**비교:**
- ❌ "looks angry"
- ✅ "jaw clenches, nostrils flare"
- ❌ "appears sad"
- ✅ "eyes downcast, shoulders drop"
- ❌ "nervous"
- ✅ "fingers drumming the table, glancing at the door"

---

## 4. 안전 & 필터 회피

### 나이 표기 절대 금지 (모든 언어)
**왜:** 미성년자 관련 콘텐츠 필터에 걸리면 생성 거부됨. 또한 윤리적 이유.

**금지어 (EN):** boy, girl, child, kid, young, teen, little, youth, youngster, adolescent, minor

**금지어 (KR):** 소년, 소녀, 어린이, 아이, 청소년, 어린, 꼬마, 학생 (연령 지시용)

**금지어 (ZH):** 男孩, 女孩, 孩子, 少年, 少女, 小孩, 年轻

**대체 (역할/의상/행동):**
- ❌ "a young boy with a red cap"
- ✅ "a figure in a red cap"
- ✅ "the rider", "the archer", "the student"
- ✅ 외형: "with short dark hair", "in a school uniform" (나이 언급 없이)

### 대화 원어 보존
**왜:** 번역하면 립싱크와 언어 패턴이 깨짐.

**규칙:**
- 사용자가 한국어 대사 주면 → 한국어 그대로 유지
- 사용자가 영어 대사 주면 → 영어 유지
- Audio 섹션 안에만 배치 (Dynamic Description에 섞지 말 것)

**예:**
```
Audio:
@Character1 (looking forward): "안녕? 오랜만이네."
@Character2 (quietly): "너도 여기 있을 줄 몰랐어."
SFX: distant traffic, wind through leaves
```

---

## 5. 구조 제약

### 샷 구조 선언 필수
**왜:** Seedance는 "몇 샷, 총 몇 초, 어떤 비율"을 먼저 알아야 전체 템포 조절.

**규칙:**
- 프롬프트 하단에 `Total: Xs / N shots / ratio` 반드시 포함
- 예:
  - `Total: 15s / 6 shots / 16:9` (Transformation)
  - `Total: 15s / 1 shot / 16:9` (Orb, POV)
  - `Total: 10s / 4 shots / 9:16` (쇼츠형)

### 이중 대비 (Double Contrast) — 모든 컷
**왜:** 비슷한 샷 크기끼리 또는 비슷한 카메라 모드끼리 연속되면 편집감이 죽고 Seedance도 구분 못 함.

**규칙:** 컷마다 **2가지 모두** 변경:

샷 사이즈 스케일:
```
extreme wide → wide → medium → medium close-up → close-up → ECU
```

카메라 모드:
```
Handheld | Static (locked-off) | Stabilized tracking | Crane/vertical | Aerial/drone
```

**나쁜 예:**
- ❌ 컷 1: wide handheld → 컷 2: wide handheld (둘 다 같음)
- ❌ 컷 1: medium tracking → 컷 2: medium static (사이즈 같음)

**좋은 예:**
- ✅ 컷 1: wide handheld → 컷 2: close-up static
- ✅ 컷 1: extreme wide aerial → 컷 2: medium close-up handheld

### 180도 룰
**왜:** 같은 공간으로 돌아오면 인물 위치와 방향의 일관성이 있어야 Seedance가 공간 이해.

**규칙:**
- 첫 등장 샷에서 위치/방향 명시 ("A on the left, B on the right, both facing each other")
- 재등장 샷에서 재명시 ("A still on the left, now turning right")
- 캐릭터 이동 방향 유지: 컷 전 좌→우 이동 = 컷 후도 좌→우

### 인서트 샷 규칙
**왜:** 익명 인서트는 Seedance가 엉뚱한 주체를 렌더링.

**규칙:**
- 인서트 길이: 0.3~0.5초
- 주체 명시 필수: ❌ "boot stepping in puddle" → ✅ "his boot stepping in puddle"
- 인과 관계 명확: "Hero slammed onto hood → his hand gripping metal" (왜 이 디테일을 보여주는지 시청자가 이해)
- 이중 대비 규칙 적용

---

## 6. 시간 처리

### 슬로모션 명시 방법
**구체적 퍼센트로 표기:**
- `approximately 20-25% speed` (딥 슬로모)
- `approximately 40-50% speed` (미드 슬로모)
- `approximately 15-20% speed at the slowest point` (변동 슬로모)

### 변속 지점 대문자 표기
**Ramp + Snap 패턴 (Orb/Fight에서):**
```
...RAMPS TO SLOW MOTION as the core fractures, 
energy tearing outward in layered shockwaves...
— SNAPS BACK, she rockets skyward...
```

**왜:** 대문자가 Seedance에게 명확한 속도 변화 큐를 제공.

### 샷당 타이밍 명시 금지 (Cinematic 모드)
**이유:** Cinematic은 리듬이 묘사 밀도에서 암시되도록 설계. "Shot 1: 2s", "Shot 2: 3s" 같은 메타데이터는 프롬프트 저해.

**예외:** Ad Brief 모드는 타임스탬프 필수 (`SHOT 3 (00:02-00:03)` 형식).

---

## 7. 어휘 제약 (Anti-Slop)

### 영문 금지어
Seedance는 이런 추상 형용사에 약함. 출력 품질 떨어뜨리는 AI 클리셰.

**금지:**
```
breathtaking, stunning, captivating, mesmerizing, awe-inspiring, masterfully, 
meticulously, exquisitely, beautifully crafted, cinematic masterpiece, visual feast,
a symphony of, seamlessly, effortlessly, flawlessly, cutting-edge, state-of-the-art,
next-level, rich tapestry, vibrant tapestry, kaleidoscope of, elevate, unlock,
unleash, harness, groundbreaking, a testament to, speaks volumes, resonates deeply
```

**대체:** 구체적 묘사로 대체
- ❌ "a breathtaking sunset"
- ✅ "orange light cuts through cloud layers, silhouetting the distant peaks"

### 중문 금지어
```
令人叹为观止, 令人惊叹, 令人着迷, 精心打造, 匠心独运, 独具匠心, 
视觉盛宴, 光影交响, 完美呈现, 极致体验, 引人入胜, 震撼人心, 巧妙融合
```

### 한국어 해설 금지어
```
숨막히는, 압도적인, 눈부신, 완벽한, 환상적인, 감탄을 자아내는, 
매혹적인, 시선을 사로잡는, 독보적인, 차원이 다른
```

---

## 8. 성공 패턴 요약

**잘 되는 것:**
- 구체적 물리 묘사 ("rain pouring, wind whipping hair sideways")
- 명명된 기법 ("spinning back kick", "slow dolly-in")
- 명확한 공간 좌표 ("A on the left, B approaching from right")
- 카메라 모드 + 샷 사이즈 변화
- 이름있는 주체의 인서트 ("his hand", "her jaw")

**깨지는 것:**
- 반사 / 거울 / 물웅덩이 반사
- 프레임 재진입
- 감정 라벨 ("looks sad", "seems nervous")
- 복잡한 인과 체인 (A→B→C→D 한 샷 내)
- 추상 형용사 ("breathtaking", "stunning")
- 4명 이상 주요 캐릭터 추적
- 관절 단위 생체역학

---

## 9. 디버깅 가이드

생성 결과가 안 좋을 때 점검 순서:

1. **샷 구조 선언이 하단에 있는가?** (`Total: Xs / N shots / ratio`)
2. **나이 단어가 없는가?**
3. **반사 묘사가 있나?** → 제거
4. **이중 대비가 모든 컷에 적용됐나?**
5. **의도+기법명으로 액션 기술됐나?**
6. **추상 형용사·AI 클리셰가 있나?** → 구체 묘사로 교체
7. **화면 밖 참조가 있나?** → 샷 내 보이게 재구성
8. **대사가 25~30단어 이하인가?** (대화 씬)
9. **카메라 지시가 사용자 요청과 일치하나?**
10. **짧은 프롬프트도 시도해봤는가?** (때로는 미니멀이 더 잘 나옴)

---

## 10. 컨텍스트별 추가 팁

### 리얼리즘 강화 필요 시
프롬프트 끝에 추가:
```
no 3D, no cartoon, no VFX
```
플라스틱 느낌 피부·과한 CG 룩 방지.

### 코미디 톤
```
add a visual gag in the background
```
Seedance가 알아서 배경에 개그 요소 삽입.

### 다이얼로그 립싱크 필요 시
대사를 따옴표로 감싸고 Audio 섹션에만 배치.

### 일관된 캐릭터 필요 시
Short Film 모드로 전환 → `@캐릭터명` 태그 사용.

### 짧은 프롬프트가 효과적인 경우
단순 POV, 단일 액션, 미니멀 표현이 필요할 때:
```
"A single-frame POV video of a medieval knight riding a horse with a sledgehammer, 
smashing opponents, realistic with blood."
```
이 정도로도 충분한 경우가 많음.


---

# APPENDIX C: CAMERA LANGUAGE


# Camera Language Reference — EN / KR / ZH

프롬프트 작성 시 사용하는 카메라 용어 대조표. 사용자가 한국어로 카메라 지시를 주면 영문으로 변환.

---

## 카메라 앵글 (Angles)

| 한국어 | English | 中文 | 설명 |
|--------|---------|------|------|
| 로우 앵글 | low-angle | 仰拍 | 아래에서 위로 올려봄. 권위·위압 |
| 하이 앵글 | high-angle | 俯拍 | 위에서 아래로 내려봄. 약함·왜소함 |
| 더치 앵글 | dutch angle | 荷兰角 | 기울어진 프레임. 긴장·불안 |
| 버즈아이 뷰 | bird's-eye / top-down | 鸟瞰 | 수직으로 내려다봄 |
| 웜즈아이 뷰 | worm's-eye | 蚁视角 | 극단적 로우 앵글 |
| 아이 레벨 | eye-level | 平视 | 인물 눈높이 |
| 오버 더 숄더 / OTS | over-the-shoulder / OTS | 过肩镜头 | 어깨 너머 숏 |
| POV | point-of-view / POV | 主观视角 | 1인칭 시점 |

---

## 초점 거리 (Focal Length)

| 한국어 | English | 中文 | 특징 |
|--------|---------|------|------|
| 광각 | wide / wide-angle (14-24mm) | 广角 | 공간 넓어 보임, 왜곡 있음 |
| 표준 | standard (35-50mm) | 标准 | 자연스러움 |
| 망원 | telephoto (85-200mm) | 长焦 | 배경 압축, 피사체 분리 |
| 매크로 | macro | 微距 | 초근접 확대 |
| 어안렌즈 | fisheye | 鱼眼 | 극단 왜곡 |
| 아나모픽 | anamorphic / 35mm anamorphic | 变形宽银幕 | 영화 와이드스크린 룩 |

---

## 카메라 움직임 (Movement)

### 기본 움직임
| 한국어 | English | 中文 |
|--------|---------|------|
| 트래킹 / 따라가기 | tracking / tracking shot | 跟拍 |
| 돌리인 / 앞으로 이동 | dolly-in / push-in | 推镜头 / 推进 |
| 돌리아웃 / 뒤로 이동 | dolly-out / pull-back | 拉镜头 / 后拉 |
| 크레인 / 붐 | crane / boom | 摇臂升降 |
| 팬 (좌우 회전) | pan | 横摇 |
| 틸트 (상하 회전) | tilt | 纵摇 |
| 휩팬 (빠른 팬) | whip-pan | 甩镜头 |
| 오빗 / 궤도 | orbit / circular dolly | 环绕 |
| 핸드헬드 | handheld | 手持摄影 |
| 스테디캠 | Steadicam / stabilized | 斯坦尼康 |
| 항공샷 / 드론 | aerial / drone shot | 航拍 |
| FPV 드론 | FPV drone | FPV 穿越机 |

### 고정 샷
| 한국어 | English | 中文 |
|--------|---------|------|
| 스태틱 / 고정 | static / locked-off | 固定镜头 |
| 트라이포드 | tripod | 三脚架 |

### 복합 움직임
| 한국어 | English | 中文 |
|--------|---------|------|
| 돌리 줌 (비키 효과) | dolly zoom / Vertigo effect | 变焦推轨 |
| 푸시인 + 회전 | push-in with rotation | 推进+旋转 |
| 크레인 + 팬 | crane + pan | 摇臂+横摇 |

---

## 샷 사이즈 (Shot Size)

한 컷 당 프레임 내 인물 크기. 이중 대비(Double Contrast) 규칙의 한 축.

| 한국어 | English (Abbr.) | 中文 | 프레이밍 |
|--------|----------------|------|---------|
| 익스트림 와이드 / 극원경 | extreme wide shot (EWS) | 极远景 | 인물이 점 같이 작음, 환경 압도 |
| 와이드 / 원경 | wide shot (WS) | 远景 / 全景 | 전신 + 주변 공간 |
| 풀샷 | full shot (FS) | 全身镜头 | 머리부터 발까지 딱 맞게 |
| 미디엄 / 중경 | medium shot (MS) | 中景 | 허리 위 |
| 미디엄 클로즈업 | medium close-up (MCU) | 中近景 | 가슴부터 머리 |
| 클로즈업 / 근경 | close-up (CU) | 特写 | 얼굴 전체 |
| 익스트림 클로즈업 / ECU | extreme close-up (ECU) | 极特写 | 눈, 입, 손 부분 |

**이중 대비 스케일 (컷마다 바꿔야 함):**
```
extreme wide → wide → medium → medium close-up → close-up → ECU
```

---

## 시간 조작 (Time Manipulation)

| 한국어 | English | 中文 | 용도 |
|--------|---------|------|------|
| 슬로모션 | slow-motion / slow-mo | 升格 | 임팩트 순간 |
| 스피드 램프 | speed ramp | 变速 | 점진적 가/감속 |
| 프리즈 프레임 | freeze frame | 定格 | 정지 |
| 타임랩스 | time-lapse | 延时摄影 | 시간 압축 |
| 하이퍼랩스 | hyperlapse | 超级延时 | 이동하며 타임랩스 |
| 리버스 모션 | reverse motion | 倒放 | 역재생 |

**변속 지점 표기 (Orb/Fight에서):**
- `RAMPS TO SLOW MOTION as [event]` — 감속 시작
- `SNAPS BACK` — 정상 속도 복귀

**슬로모 퍼센트:**
- 극딥 슬로모: `approximately 15-20% speed`
- 딥 슬로모: `approximately 20-25% speed`
- 미드 슬로모: `approximately 40-50% speed`
- 라이트 슬로모: `approximately 60-70% speed`

---

## 전환 (Transitions)

| 한국어 | English | 中文 | 특징 |
|--------|---------|------|------|
| 스매시 컷 / 하드 컷 | smash cut / hard cut | 硬切 / 直切 | 급격한 톤 전환 |
| 매치 컷 | match cut | 匹配剪辑 | 비슷한 형/동작 연결 |
| 휩팬 전환 | whip-pan transition | 甩镜转场 | 빠른 팬으로 연결 |
| L컷 | L-cut | L型剪辑 | 오디오 먼저 넘어감 |
| J컷 | J-cut | J型剪辑 | 오디오 뒤따라옴 |
| 페이드 인/아웃 | fade in / fade out | 淡入 / 淡出 | 검정/흰색으로 |
| 디졸브 | dissolve / cross-fade | 叠化 / 淡化 | 두 샷 겹침 |
| 블룸 플래시 | bloom flash / white flash | 白光过渡 | 과노출 전환 |

---

## 조명 (Lighting)

### 광원 방향
| 한국어 | English | 中文 |
|--------|---------|------|
| 키 라이트 (주 조명) | key light | 主光 |
| 필 라이트 (보조) | fill light | 辅光 |
| 백 라이트 / 림 라이트 | back light / rim light | 逆光 / 轮廓光 |
| 사이드 라이트 | side light | 侧光 |
| 프랙티컬 (현장광) | practical light | 实用光源 |

### 조명 스타일
| 한국어 | English | 中文 |
|--------|---------|------|
| 자연광 | natural light | 自然光 |
| 황금시간 (골든아워) | golden hour | 黄金时刻 |
| 파란시간 (블루아워) | blue hour | 蓝色时刻 |
| 하드 라이트 | hard light | 硬光 |
| 소프트 라이트 | soft light | 柔光 |
| 하이키 (밝음) | high-key | 高调 |
| 로우키 (어두움) | low-key | 低调 |
| 체크 전환 조명 | chiaroscuro | 明暗对比 |
| 볼류메트릭 | volumetric lighting | 体积光 |

### 색온도
| 한국어 | English | 中文 |
|--------|---------|------|
| 차가운 톤 | cool tones | 冷色调 |
| 따뜻한 톤 | warm tones | 暖色调 |
| 티얼 & 오렌지 | teal and orange | 青橙色调 |
| 데사츄레이티드 | desaturated | 低饱和 |

---

## 필름 룩 (Film Look)

| 한국어 | English | 中文 |
|--------|---------|------|
| 35mm 필름 | 35mm film | 35mm 胶片 |
| 16mm 필름 | 16mm film | 16mm 胶片 |
| 필름 그레인 | film grain | 胶片颗粒 |
| 필름 렌즈 플레어 | lens flare | 镜头光晕 |
| 색수차 | chromatic aberration | 色差 |
| 모션블러 | motion blur | 运动模糊 |
| 초점 브리딩 | focus breathing | 呼吸效应 |
| 할레이션 | halation | 光晕 |
| 할레이션 롤오프 | highlight rolloff | 高光过渡 |
| 쉘로우 DOF (얕은 심도) | shallow depth of field | 浅景深 |
| 딥 DOF (깊은 심도) | deep depth of field | 深景深 |
| 랙 포커스 / 포커스 풀 | rack focus / focus pull | 变焦 / 对焦变化 |
| ARRI ALEXA 느낌 | ARRI ALEXA aesthetic | ARRI ALEXA 美学 |

---

## 장르 레퍼런스 (Style References)

사용 예: `"Guy Ritchie speed-ramping with Snyder impact slow-motion"`

### 감독/스타일
| 레퍼런스 | 특징 | 적용 장르 |
|---------|------|---------|
| Guy Ritchie speed-ramping | 빠른 속도 변화 | 액션, 범죄 |
| Snyder impact slow-motion | 강한 슬로모 타격감 | 액션, 히어로 |
| Wes Anderson symmetry | 대칭 프레이밍, 파스텔 | 코미디, 인디 |
| Villeneuve atmospheric wide | 거대 스케일, 묵직 | SF, 드라마 |
| Tarantino trunk shot | 트렁크 각도 | 범죄, 스릴러 |
| Kubrick one-point perspective | 중심 소실점 | 공포, 드라마 |
| Malick natural light | 자연광, 마법의 시간 | 드라마, 시 |
| Deakins cinematography | 프레이밍 장인, 실루엣 | 드라마, 스릴러 |

### 영화 룩
| 레퍼런스 | 특징 |
|---------|------|
| 1970s film aesthetic | 그레인, 따뜻한 색 |
| 16mm black-and-white | 고대비, 다큐 느낌 |
| IMAX-scale scene | 에픽 스케일 |
| 90s home video | VHS 아티팩트 |
| Film noir | 극적 그림자, 고대비 |
| Anamorphic 35mm | 와이드 시네마 |
| DVR dashcam look | CCTV 미학 |
| Mockumentary | 핸드헬드 다큐 |

### 장르 키워드
| 장르 | 권장 표현 |
|------|---------|
| 액션 | "high-octane", "kinetic", "Guy Ritchie speed-ramping" |
| 공포 | "grounded realism", "slow push-in", "cold blue shadow" |
| 멜로/로맨스 | "warm tones", "shallow DOF", "golden hour" |
| 스릴러 | "cold blue fill", "locked-off", "push-in on silence" |
| SF | "volumetric light", "cool desaturated", "ARRI ALEXA aesthetic" |
| 판타지 | "cathedral-scale", "volumetric mist", "gold dawn light" |
| 다큐/리얼 | "handheld", "natural imperfections", "no music only raw SFX" |
| 광고 | "anamorphic 35mm", "signature visual effect", "speed ramp" |

---

## 오디오 (Audio)

### 효과음 (SFX)
| 한국어 | English |
|--------|---------|
| 앰비언스 | ambient sound / ambience |
| 풋스텝 | footsteps |
| 충격음 | impact sounds |
| 휩 사운드 | whip sound |
| 숨소리 | breath sounds |
| 바람소리 | wind howling |
| 빗소리 | rain patter |
| 천둥 | thunder roll |
| 전기 크래클 | electric crackle |
| 금속 소리 | metal clang / metallic ring |

### 음악 큐
| 한국어 | English |
|--------|---------|
| 음악 없음 | NO MUSIC / no music only raw SFX |
| 드롭 타이밍 | beat drop at [timestamp] |
| 스윙잉 | rising score |
| 정적 | silence |

---

## 사용 가이드

### 한국어 → 영어 변환 예시

**사용자 입력:**
> "낮은 각도에서 천천히 다가가는 카메라로 주인공을 찍어줘. 영화 같은 느낌으로, 35mm 느낌"

**변환 결과 (프롬프트 내 적용):**
> "Slow dolly-in from low-angle toward the protagonist, cinematic framing, 35mm film look, shallow DOF, film grain"

### 사용자 카메라 지시 보존 규칙

사용자가 명시한 카메라 지시는 **반드시 출력에 포함**:
- "돌리 인" → `dolly-in` 포함 필수
- "로우앵글" → `low-angle` 포함 필수
- "트래킹샷" → `tracking shot` 포함 필수

사용자가 명시 안 하면 아키타입에 맞는 기본값 선택.