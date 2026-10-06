# -*- coding: utf-8 -*-
"""Phase B — annotation.json + SVG → HyperFrames 컴포지션 HTML 컴파일러.

SVG(그룹 id = annotation element id)와 annotation.json 을 읽어,
HyperFrames 계약(단일 paused GSAP 타임라인, data-* 타이밍, 시킹 안전)을
따르는 index.html 을 생성한다.

- 각 요소: 잉크(획 리빌 stroke-dashoffset, 길이 비례 배분) → 채색(fill 페이드)
- 펜: 현재 그려지는 path 를 getPointAtLength 로 정확히 추적 (타임라인 구동)
- 자막: annotation 의 subtitle 을 요소 구간에 맞춰 표시 (autoAlpha)

생성물은 브라우저에서 `?play` 를 붙여 단독 재생·검증할 수 있고,
HyperFrames 프로젝트의 index.html 로 그대로 렌더된다 (render_hyperframes.py).

사용법:
  <ENV_PY> scripts/compile_hyperframes.py <장면.svg> <주석.json> <출력.html>
"""
import argparse
import json
import sys
from pathlib import Path

GSAP_CDN = "https://cdn.jsdelivr.net/npm/gsap@3.14.2/dist/gsap.min.js"

TEMPLATE = """<!doctype html>
<html lang="ko">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width={w}, height={h}" />
<script src="{gsap}"></script>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  html, body {{ width: {w}px; height: {h}px; overflow: hidden; background: #000; }}
  #root {{ position: relative; width: {w}px; height: {h}px; }}
  #paper {{ position: absolute; inset: 0; background: {paper}; }}
  #scene {{ position: absolute; inset: 0; }}
  #scene svg {{ width: 100%; height: 100%; display: block; }}
  #pen {{ position: absolute; left: 0; top: 0; width: 54px; height: 54px;
         margin-left: -6px; margin-top: -48px; pointer-events: none; }}
  .subtitle {{ position: absolute; left: 0; right: 0; bottom: {submargin}px; text-align: center;
              font: 700 {subsize}px "Malgun Gothic", "Apple SD Gothic Neo", sans-serif; color: #262320;
              text-shadow: -2px 0 {paper}, 2px 0 {paper}, 0 -2px {paper}, 0 2px {paper}; }}
</style>
</head>
<body>
<div id="root" data-composition-id="main" data-start="0" data-duration="{dur:.2f}"
     data-width="{w}" data-height="{h}">
  <div id="paper"></div>
  <div id="scene">
{svg}
  </div>
  <svg id="pen" viewBox="0 0 54 54">
    <g transform="rotate(40 27 27)">
      <rect x="21" y="4" width="12" height="34" rx="3" fill="#FAF5E8" stroke="#3E3832" stroke-width="2"/>
      <polygon points="21,38 33,38 27,52" fill="#7A3B2E" stroke="#3E3832" stroke-width="2"/>
      <rect x="21" y="0" width="12" height="7" rx="2" fill="#7A3B2E"/>
    </g>
  </svg>
{subtitles}
</div>

<script>
window.__timelines = window.__timelines || {{}};
const tl = gsap.timeline({{ paused: true }});
const PLAN = {plan};

// 초기 상태: 모든 획은 감춤(dashoffset), 채색은 투명, 펜·자막은 숨김
const penEl = document.getElementById("pen");
gsap.set(penEl, {{ autoAlpha: 0 }});
document.querySelectorAll(".subtitle").forEach(el => gsap.set(el, {{ autoAlpha: 0 }}));

for (const el of PLAN.elements) {{
  const group = document.getElementById(el.id);
  if (!group) continue;
  const strokes = Array.from(group.querySelectorAll("path.stroke"));
  const fills = Array.from(group.querySelectorAll(".fill"));
  const lens = strokes.map(p => p.getTotalLength());
  const totalLen = lens.reduce((a, b) => a + b, 0) || 1;
  // gap 을 dash 보다 20px 크게 + offset 10px 여유:
  // dash 경계가 경로 시작점에 정확히 걸리며 round linecap 점이 찍히는 것을 방지
  strokes.forEach((p, i) => gsap.set(p, {{
    strokeDasharray: `${{lens[i]}} ${{lens[i] + 20}}`,
    strokeDashoffset: lens[i] + 10,
  }}));
  fills.forEach(f => gsap.set(f, {{ opacity: 0 }}));

  const inkDur = el.dur * PLAN.inkRatio;
  const colorDur = el.dur - inkDur;
  let t = el.start;
  tl.set(penEl, {{ autoAlpha: 1 }}, t);
  strokes.forEach((p, i) => {{
    const d = inkDur * lens[i] / totalLen;
    tl.to(p, {{ strokeDashoffset: 0, duration: d, ease: "none" }}, t);
    const state = {{ k: 0 }};
    tl.to(state, {{
      k: 1, duration: d, ease: "none",
      onUpdate: () => {{
        // viewBox(=캔버스 픽셀)와 루트가 1:1 이므로 픽셀 좌표 그대로 사용
        const pt = p.getPointAtLength(state.k * lens[i]);
        gsap.set(penEl, {{ x: pt.x, y: pt.y }});
      }},
    }}, t);
    t += d;
  }});
  tl.set(penEl, {{ autoAlpha: 0 }}, el.start + inkDur);
  if (fills.length) {{
    tl.to(fills, {{ opacity: 1, duration: Math.max(0.4, colorDur * 0.8),
                    ease: "power1.inOut", stagger: Math.min(0.15, colorDur * 0.1) }},
          el.start + inkDur);
  }}
  const sub = document.getElementById("sub-" + el.id);
  if (sub) {{
    tl.to(sub, {{ autoAlpha: 1, duration: 0.15 }}, el.start);
    tl.to(sub, {{ autoAlpha: 0, duration: 0.15 }}, el.subEnd);
  }}
}}

window.__timelines["main"] = tl;
// 단독 검증용: ?play 로 열면 즉시 재생 (HyperFrames 렌더에는 영향 없음)
if (new URLSearchParams(location.search).has("play")) tl.play();
</script>
</body>
</html>
"""


def main() -> None:
    ap = argparse.ArgumentParser(description="SVG + annotation → HyperFrames 컴포지션 HTML")
    ap.add_argument("svg", help="장면 SVG 경로 (그룹 id = annotation element id)")
    ap.add_argument("annotation", help="annotation.json 경로")
    ap.add_argument("output", help="출력 HTML 경로")
    ap.add_argument("--ink-ratio", type=float, default=2 / 3,
                    help="요소 시간 중 잉크(획) 단계 비율 (기본 2/3, 나머지는 채색)")
    ap.add_argument("--subtitle-size", type=int, default=34, help="자막 크기 px (기본 34)")
    ap.add_argument("--subtitle-margin", type=int, default=36, help="자막 하단 여백 px (기본 36)")
    args = ap.parse_args()

    svg_text = Path(args.svg).read_text(encoding="utf-8").strip()
    ann = json.loads(Path(args.annotation).read_text(encoding="utf-8"))
    w = ann["canvas"]["width"]
    h = ann["canvas"]["height"]
    dur_s = ann.get("sceneDurationMs", 10000) / 1000.0

    elements = sorted(ann["elements"], key=lambda e: e.get("sequence", 0))
    plan_elements = []
    subtitle_divs = []
    for i, e in enumerate(elements):
        start = e["reveal"]["startMs"] / 1000.0
        dur = e["reveal"]["durationMs"] / 1000.0
        nxt = elements[i + 1]["reveal"]["startMs"] / 1000.0 if i + 1 < len(elements) else dur_s
        sub_end = max(start + dur, min(nxt, dur_s) - 0.05)
        plan_elements.append({"id": e["id"], "start": round(start, 3),
                              "dur": round(dur, 3), "subEnd": round(sub_end, 3)})
        sub = (e.get("subtitle") or "").strip()
        if sub:
            subtitle_divs.append(
                f'  <div class="subtitle" id="sub-{e["id"]}">{sub}</div>')

    for e in plan_elements:
        if f'id="{e["id"]}"' not in svg_text:
            print(f"[err] SVG 에 그룹 id=\"{e['id']}\" 가 없습니다. "
                  "annotation element id 와 SVG 그룹 id 가 일치해야 합니다.", file=sys.stderr)
            sys.exit(1)

    html = TEMPLATE.format(
        w=w, h=h, dur=dur_s, gsap=GSAP_CDN, paper="#F5EBD7",
        svg="\n".join("    " + line for line in svg_text.splitlines()),
        subtitles="\n".join(subtitle_divs),
        subsize=args.subtitle_size, submargin=args.subtitle_margin,
        plan=json.dumps({"inkRatio": args.ink_ratio, "elements": plan_elements},
                        ensure_ascii=False),
    )
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html, encoding="utf-8")
    print(f"[ok] 컴포지션 생성: 요소 {len(plan_elements)}개, {dur_s:.1f}초, {w}x{h}")
    print(f"OUTPUT={out}")


if __name__ == "__main__":
    main()
