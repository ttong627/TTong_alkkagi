# 구글 Flow / Veo 3.1 사양 (프롬프트 설계 근거)

스킬이 사양을 확정할 때 읽는다. 사양은 변할 수 있으니 의심되면 최신 정보를 웹에서 재확인한다.
(확인 시점: 2026년 6월)

## 단일 클립 길이
- Veo 3.1은 한 번 생성에 **4초 · 6초 · 8초** 클립을 만든다(최대 8초).
- 8초 한계는 단일 생성의 제약이며, 더 길게 가려면 클립을 잇거나 Extend를 쓴다.

## 길이 확장 (Extend / 장면 확장)
- Extend는 클립당 **약 7~8초**를 이어붙인다.
- 최대 **20회 확장**, 원본+확장 합쳐 **최대 약 148초**.
- Veo는 소스 클립의 **마지막 24프레임(약 1초)** 을 분석해 다음을 잇는다 → **클립을 안정된 구도에서 끝낼수록** 확장이 자연스럽다. 동작 중간·복잡한 전환에서 끊으면 불안정.

## 캐릭터/연속성 일관성 기법
일관성은 자동이 아니다. 아래를 조합한다.
1. **Ingredients to Video** — 참조 이미지 **최대 3장**을 넣어 인물·오브젝트·배경 정체성을 유지. 다중 샷·대화 장면에 적합. 참조 이미지는 Gemini(2.5 Flash Image)로 캐릭터/세팅 시트를 먼저 만들어 쓰는 흐름이 권장됨.
2. **프롬프트 반복** — 드리프트를 막는 가장 강력한 수단. 모든 확장/클립 프롬프트가 **원본 정보의 80% 이상을 그대로 반복**해야 한다. 인물은 이름만이 아니라 **얼굴 특징·의상·자세까지 매번 완전 묘사**.
3. **Frames-to-Video(시작/끝 프레임)** — 클립 N의 마지막 프레임을 저장해 클립 N+1의 시작 프레임으로 쓰면 이어짐이 자연스럽다. 긴 영상은 저장한 참조 프레임으로 '재시작'하는 게 품질 유지에 유리.
4. **한계 인지** — 참조 이미지로도 완벽 일치는 어렵다. 얼굴·의상·비율에 미세 변화가 생길 수 있고, **4~5회 확장 후 눈에 띄는 변화**가 나타나기 쉽다. 정확도가 중요하면 생성물을 검수하고 어긋난 클립은 재생성한다.

## 자막 관련 (이 스킬의 절대 규칙)
- Veo는 대사·내레이션이 있으면 **화면에 자막을 자동 생성**하는 경향이 있다.
- 이를 막으려면 프롬프트에 **명시적으로 자막/텍스트 비생성**을 지시한다: "no subtitles, no captions, no on-screen text, no burned-in text". 대사는 "음성으로만" 들리게 지정한다.

## 클립 수 계산 규칙 (총 길이 맞추기)
- 목표 `T`초를 4·6·8 조합으로 정확히 채운다. 8을 최대로 쓰고 나머지를 6/4로 보정.
- `N_min = ceil(T / 8)`.
- 4·6·8로 못 떨어지는 값(홀수 등)은 가장 가까운 구성으로 맞추고 조정 사실을 해설에 밝힌다.

---

## 출처
- [Ultimate prompting guide for Veo 3.1 — Google Cloud Blog](https://cloud.google.com/blog/products/ai-machine-learning/ultimate-prompting-guide-for-veo-3-1)
- [Google Flow Veo 3: Complete Guide (2026) — veo3ai.io](https://www.veo3ai.io/blog/google-flow-veo-3-guide-2026)
- [How to Extend Veo 3.1 Videos Beyond 8 Seconds — aifreeapi.com](https://www.aifreeapi.com/en/posts/veo-3-extend-video-length)
- [How to Extend a Scene in Veo 3.1 — skywork.ai](https://skywork.ai/blog/how-to-extend-veo-3-1-scene-guide/)
- [Make Videos Longer Than 8 Seconds in Veo 3 — toolfolio.io](https://toolfolio.io/productive-value/make-videos-longer-than-eight-seconds-in-veo)
