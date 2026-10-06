---
name: 사업분석
description: "사업 분석 틀 12종을 한 곳에서 — 린캔버스·시장규모(TAM/SAM/SOM)·경쟁사분석·배틀카드·포터 5포스·PESTLE·GTM전략·가격전략·수익화전략·포지셔닝·가치제안·고객여정. 사업계획서·공모서·제안서의 분석 장을 쓸 때, 또는 「린캔버스」「시장규모」「경쟁사 분석」「5포스」「PESTLE」「가격 전략」「고객 여정」이라고 하면 쓴다."
---

# 사업분석 — 분석 틀 12종 (2026-09-27 pm-* 12개를 하나로 합침)

> 옛 `pm-*` 스킬 12개의 본문은 **그대로** `references/` 에 있다. 틀을 고른 뒤 그 파일 하나만 읽는다(한꺼번에 다 읽지 않는다).

## 1. 틀 고르기

| 형이 말하는 것 | 틀 | 파일 |
|---|---|---|
| 사업모델 한 장, 새 사업 가설 | 린 캔버스 | `references/lean-canvas.md` |
| 시장이 얼마나 큰가 | TAM/SAM/SOM | `references/market-sizing.md` |
| 경쟁사와 비교 | 경쟁사 분석 | `references/competitor-analysis.md` |
| 영업·입찰 대응용 비교 카드 | 배틀카드 | `references/competitive-battlecard.md` |
| 산업 구조·진입 장벽 | 포터 5 Forces | `references/porters-five-forces.md` |
| 정책·경제·사회 환경(공모서 「추진 배경」) | PESTLE | `references/pestle-analysis.md` |
| 시장 진입·출시 계획 | GTM 전략 | `references/gtm-strategy.md` |
| 가격·단가 설계 | 가격 전략 | `references/pricing-strategy.md` |
| 매출 모델·과금 구조 | 수익화 전략 | `references/monetization-strategy.md` |
| 차별화 자리 잡기 | 포지셔닝 | `references/positioning-ideas.md` |
| 핵심 가치 문구(카피) | 가치제안 | `references/value-prop-statements.md` |
| 고객이 겪는 단계·접점 | 고객 여정 지도 | `references/customer-journey-map.md` |

여러 틀이 필요하면(예: 공모서 = PESTLE → 시장규모 → 경쟁사 → 린캔버스) 순서대로 하나씩 읽고 쓴다.

## 2. 형 맞춤 규칙 (원문 틀보다 우선)

- **숫자는 실제 출처로만.** 시장 규모·단가·인원은 형 자료(Vault `10_사업`, 젬마 `ask_gemma`, 공공데이터)에서 찾아 출처를 붙인다. 없으면 「추정」이라고 쓰고 계산식을 보인다. ⛔지어낸 사례·수치 금지.
- **주체를 먼저 정한다** — 사협(비영리·발행 주체)인지 로지스(영리)인지에 따라 수익화·가격 장이 달라진다.
- 사회적경제 공모서면 「사회적 가치」(취약계층 고용·지역 기여)를 경쟁 우위 칸에 반드시 넣는다.
- 결과물이 한글 문서면 `hwpdoc`(`D:\Gemma4\_tools\hwpdoc` README 먼저), 발표면 pptx 스킬로 넘긴다.
- 한국어로 쓰고, 결론(한 줄)을 맨 앞에 둔다.
