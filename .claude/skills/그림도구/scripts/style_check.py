# -*- coding: utf-8 -*-
"""그림체 숫자 검사 — 「변형 없이」를 눈대중이 아니라 **숫자로** 잰다.

형용사는 모델에게 가는 길에 사라지고 숫자는 남는다.
수묵화는 **종이가 넓고 · 채도가 낮고 · 먹이 진하다.** 3D·게임CG·총천연색으로 흐르면
네 숫자가 한꺼번에 무너진다.

  paper  종이(밝고 채도 낮은 곳) 비율
  sat    평균 채도
  ink    진한 먹(아주 어두운 곳) 비율
  color  색 화려함(Hasler–Süsstrunk colorfulness)

★숫자는 **보조 문**이다. 통과해도 그림은 반드시 눈으로 본다(형 규칙 — 한 장씩 다 본다).

사용
  python style_check.py <그림…>                      숫자만 찍는다
  python style_check.py <그림…> --style 통통그림체1   기준 범위로 판정 (종료코드 1 = 벗어남)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

HERE = Path(__file__).resolve().parent
STYLES = HERE.parent / "styles"


def metrics(path: Path) -> dict[str, float]:
    """그림 한 장의 네 숫자. 크기에 흔들리지 않게 768 안으로 줄여 잰다."""
    im = Image.open(path).convert("RGB")
    im.thumbnail((768, 768))
    rgb = np.asarray(im, dtype=np.float32) / 255.0
    hsv = np.asarray(im.convert("HSV"), dtype=np.float32) / 255.0
    s, v = hsv[..., 1], hsv[..., 2]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    rg, yb = r - g, 0.5 * (r + g) - b
    colorful = (np.hypot(rg.std(), yb.std()) + 0.3 * np.hypot(rg.mean(), yb.mean())) * 255.0
    return {
        "paper": round(float(((v > 0.78) & (s < 0.22)).mean()), 4),
        "sat": round(float(s.mean()), 4),
        "ink": round(float((v < 0.30).mean()), 4),
        "color": round(float(colorful), 2),
    }


def judge(m: dict[str, float], ranges: dict[str, list[float]]) -> list[str]:
    """기준 범위를 벗어난 숫자들. 빈 목록이면 통과."""
    return [f"{k} {m[k]} (기준 {lo}~{hi})"
            for k, (lo, hi) in ranges.items() if not lo <= m[k] <= hi]


def load_style(name: str) -> dict:
    return json.loads((STYLES / name / "style.json").read_text(encoding="utf-8"))


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    style = sys.argv[sys.argv.index("--style") + 1] if "--style" in sys.argv else None
    if style:
        args = [a for a in args if a != style]
    if not args:
        print(__doc__)
        return 1
    ranges = load_style(style)["ranges"] if style else None
    bad = 0
    for a in args:
        m = metrics(Path(a))
        if ranges is None:
            print(f"{Path(a).name}  {m}")
            continue
        off = judge(m, ranges)
        bad += bool(off)
        print(f"{'✅' if not off else '❌'} {Path(a).name}  {m}" + (f"  ← {off}" if off else ""))
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
