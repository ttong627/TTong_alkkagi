# HyperFrames 적용 검토

[HyperFrames](https://github.com/heygen-com/hyperframes)는 HeyGen이 공개한 오픈소스
**HTML → 비디오 렌더링 프레임워크**다 (MIT). HTML/CSS/JS로 장면을 작성하면 헤드리스
Chrome이 타임라인을 프레임 단위로 시킹하며 캡처하고 ffmpeg로 인코딩해, **같은 입력이면
항상 같은 MP4**가 나온다.

## HyperFrames 개요

| 항목 | 내용 |
|---|---|
| 설치 | `npx hyperframes init my-video` (npm 패키지 `hyperframes`) |
| 요구사항 | Node.js 22+, ffmpeg, 헤드리스 Chrome |
| 저작 방식 | HTML + `data-composition-id` / `data-start` / `data-duration` 타이밍 속성 |
| 렌더링 | `npx hyperframes render` (로컬), 클라우드/Lambda 렌더 지원 |
| 애니메이션 | CSS, GSAP, Lottie, Three.js, Anime.js, Web Animations API — **시킹 가능(seekable)해야 함** |
| 미리보기 | `npx hyperframes preview` (브라우저) |

## 이 스킬에 적용 가능한가?

**결론: 적용 가능하다. 단, 기존 렌더러의 대체가 아니라 "벡터 소스 전용의 별도 렌더 경로"로.**

### 잘 맞는 부분

- **SVG 필기 애니메이션**: `stroke-dasharray` / `stroke-dashoffset` CSS 애니메이션으로
  "선을 따라 그리는" 효과를 벡터 정밀도로 구현할 수 있다. 픽셀 마스크 방식(현행)보다
  선이 깨끗하고, 해상도 무관.
- **펜 추적**: CSS Motion Path(`offset-path: path(...)`)로 펜 이미지가 같은 경로를
  정확히 따라가게 할 수 있다. 현행의 격자/골격 근사보다 궤적이 정확하다.
- **자막**: HTML 텍스트라 번인 후처리 없이 타이밍 속성만으로 표시·스타일링이 된다.
- **결정론적 출력**: 프레임 시킹 방식이라 시스템 부하와 무관하게 항상 같은 결과.
- **에이전트 친화**: 이 스킬 자체가 Claude 같은 에이전트가 구동하므로, "에이전트가
  HTML을 작성한다"는 HyperFrames의 설계 철학과 정확히 맞물린다.

### 제약

- **의존성 무게**: 현행 렌더러는 Python venv(opencv/numpy/av/Pillow)만으로 동작한다.
  HyperFrames는 Node 22+, 헤드리스 Chrome, 시스템 ffmpeg가 추가로 필요하다.
- **소스가 벡터여야 함**: 현행 파이프라인은 래스터 PNG(이미지 생성 AI 산출물)를
  받는다. SVG 경로가 없으면 stroke 애니메이션을 만들 수 없으므로,
  래스터 → 벡터 변환(potrace, 골격 추적→path 변환) 단계가 필요하다.
  반대로 **처음부터 SVG로 그리는 장면**(프로그래매틱 생성)은 바로 적용된다.
- **채색 단계 재설계 필요**: 현행 "잉크→컬러 2단계"를 SVG에서 재현하려면
  fill 요소의 clip-path/마스크 애니메이션 설계가 별도로 필요하다.

### 적합/부적합 시나리오

| 시나리오 | 판단 |
|---|---|
| AI 이미지 생성으로 만든 래스터 선화 | 현행 Python 렌더러 유지 (벡터화 비용 큼) |
| 코드로 그리는 SVG 장면 (예: 이 저장소의 설날 예시) | HyperFrames 경로가 더 깨끗한 결과 |
| 자막·타이포·UI 오버레이가 많은 영상 | HyperFrames 우세 (HTML 텍스트) |
| 오프라인·경량 환경 (Node/Chrome 설치 불가) | 현행 Python 렌더러 유지 |

## 통합 파이프라인 (Phase A~C — 구현됨)

세 단계 모두 `scripts/` 에 구현되어 있다. 전체 흐름:

```bash
# Phase A: 벡터 장면 생성 (예시 — 자기 장면은 같은 규약의 SVG를 직접 준비)
<ENV_PY> scripts/generate_svg_example.py examples/scene-01-seollal.svg

# Phase B: SVG + annotation → HyperFrames 컴포지션 HTML
<ENV_PY> scripts/compile_hyperframes.py examples/scene-01-seollal.svg     examples/scene-01-seollal.annotation.json out/composition.html

# Phase C: HyperFrames 로 결정론적 MP4 렌더 (Node 22+ 필요, 미설치 시 폴백 안내)
<ENV_PY> scripts/render_hyperframes.py out/composition.html out/scene.mp4
```

1. **Phase A — `generate_svg_example.py`**: annotation element id 와 1:1 로
   대응하는 `<g id>` 그룹을 가진 SVG 를 생성. 그룹 안에서 `class="stroke"` 는
   펜이 따라 그릴 윤곽, `class="fill"` 은 채색 단계에 나타날 면.
2. **Phase B — `compile_hyperframes.py`**: HyperFrames 계약(단일 paused GSAP
   타임라인 `window.__timelines["main"]`, 루트 `data-start="0"`/`data-duration`,
   시킹 안전)을 따르는 HTML 을 생성. 획 리빌은 `stroke-dashoffset`(길이 비례
   배분), 펜은 `getPointAtLength` 로 현재 획을 정확히 추적, 자막은 annotation
   의 `subtitle` 을 요소 구간에 맞춰 표시. 브라우저에서 `?play` 로 단독 재생 가능.
3. **Phase C — `render_hyperframes.py`**: Node 22+ 확인 → `npx hyperframes init
   --example blank` 로 프로젝트 준비(캐시 재사용) → 컴파일된 HTML 을
   `index.html` 로 배치 → `npx hyperframes render` 실행 → 산출 MP4 회수.
   Node 미설치/실패 시 기존 Python 렌더러 사용을 안내하고 명확히 종료.

검증: 컴파일된 HTML 을 헤드리스 브라우저에서 타임라인 `seek()` 로 3개 시점
(3.5s/16s/27.5s) 정지 캡처해 잉크→채색 순서, 펜 추적, 자막 표시를 확인했다 —
이 시킹 방식이 곧 HyperFrames 렌더러의 프레임 캡처 방식이다.

## PoC (개념 증명)

`experimental/hyperframes-poc.html` — **프레임워크 없이 브라우저에서 바로 열리는**
자체 완결형 데모다. 다음 메커니즘을 시연한다:

- SVG `stroke-dashoffset` 애니메이션으로 집·나무·해를 순서대로 "그리기"
- CSS Motion Path로 펜 아이콘이 현재 그려지는 경로를 따라 이동
- 자막이 장면 타이밍에 맞춰 교체 표시
- 각 요소에 HyperFrames 규약(`data-start`/`data-duration`)을 주석으로 병기 —
  실제 통합 시 이 속성을 HyperFrames 타임라인이 읽는다

모든 애니메이션은 CSS 기반(시킹 가능)이라 HyperFrames의 프레임 시킹과 호환된다.

## 결론

- **Phase A~C 파이프라인이 구현되어**, 벡터(SVG) 소스 장면은 HyperFrames 경로로
  결정론적 MP4 를 만들 수 있다. 컴파일된 HTML 은 브라우저 시킹 검증을 통과했다.
- 래스터(PNG) 소스 장면과 오프라인·경량 환경에서는 기존 Python 렌더러가 기본이다.
  두 경로는 같은 annotation.json 을 공유하므로 장면 데이터는 호환된다.
- 남은 과제: 래스터 → SVG 자동 벡터화(현재는 SVG 를 직접 준비해야 함),
  HyperFrames `check` 게이트 통과 상태의 CI 유지.
