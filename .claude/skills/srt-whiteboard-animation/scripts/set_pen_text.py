# -*- coding: utf-8 -*-
"""펜대 문구 커스터마이징 도구.

빈 펜 이미지(assets/drawing-hand-blank.png)의 흰 배럴에 원하는 문구를
배럴 축 각도에 맞춰 합성해 drawing-hand.png 를 만든다.

사용법:
  <ENV_PY> scripts/set_pen_text.py "미래이음연구소"
  <ENV_PY> scripts/set_pen_text.py "내 브랜드" --out assets/drawing-hand.png
"""
import argparse
import math
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

SKILL_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_BLANK = SKILL_ROOT / "assets" / "drawing-hand-blank.png"
DEFAULT_OUT = SKILL_ROOT / "assets" / "drawing-hand.png"

FONT_CANDIDATES = [
    "C:/Windows/Fonts/malgunbd.ttf",                      # Windows 맑은 고딕 볼드
    "C:/Windows/Fonts/malgun.ttf",
    "/System/Library/Fonts/AppleSDGothicNeo.ttc",          # macOS
    "/usr/share/fonts/truetype/nanum/NanumGothicBold.ttf",  # Linux
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
]


def load_font(size: int, font_path: str | None):
    paths = [font_path] if font_path else FONT_CANDIDATES
    for p in paths:
        if p:
            try:
                return ImageFont.truetype(p, size)
            except OSError:
                continue
    print("[err] 한글 폰트를 찾지 못했습니다. --font 로 폰트 파일을 지정하세요.", file=sys.stderr)
    sys.exit(1)


def barrel_geometry(rgba: np.ndarray):
    """흰 배럴 영역의 내부 마스크·중심·축 각도를 계산."""
    rgb, alpha = rgba[..., :3], rgba[..., 3]
    white = ((alpha > 200) & (rgb.min(axis=2) > 195)).astype(np.uint8) * 255
    n, labels, stats, _ = cv2.connectedComponentsWithStats(white, 8)
    if n < 2:
        print("[err] 흰 배럴 영역을 찾지 못했습니다.", file=sys.stderr)
        sys.exit(1)
    best = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    barrel = (labels == best).astype(np.uint8) * 255
    inner = cv2.erode(barrel, np.ones((7, 7), np.uint8), iterations=2)
    ys, xs = np.nonzero(inner)
    pts = np.column_stack([xs, ys]).astype(np.float32)
    mean = pts.mean(axis=0)
    cov = np.cov((pts - mean).T)
    evals, evecs = np.linalg.eigh(cov)
    axis = evecs[:, np.argmax(evals)]
    angle = math.degrees(math.atan2(axis[1], axis[0]))
    if angle < -90:
        angle += 180
    if angle > 90:
        angle -= 180
    major_len = 4.0 * math.sqrt(max(evals))  # 축 방향 대략 길이 (±2σ)
    minor_len = 4.0 * math.sqrt(min(evals))  # 배럴 폭 방향 대략 길이
    return inner, mean, angle, major_len, minor_len


def main() -> None:
    ap = argparse.ArgumentParser(description="펜대 문구를 원하는 한글/텍스트로 교체")
    ap.add_argument("text", help="펜대에 넣을 문구 (한글 3~7자 권장)")
    ap.add_argument("--blank", default=str(DEFAULT_BLANK), help="빈 펜 이미지 경로")
    ap.add_argument("--out", default=str(DEFAULT_OUT), help="출력 경로 (기본: assets/drawing-hand.png)")
    ap.add_argument("--font", default=None, help="폰트 파일 경로 (기본: 시스템 한글 폰트 자동 탐색)")
    ap.add_argument("--size", type=int, default=None, help="폰트 크기 (기본: 배럴 길이에 맞춰 자동)")
    ap.add_argument("--color", default="38,34,32", help="문구 색 R,G,B (기본 진회색)")
    args = ap.parse_args()

    base = Image.open(args.blank).convert("RGBA")
    rgba = np.array(base)
    inner, mean, angle, major_len, minor_len = barrel_geometry(rgba)

    color = tuple(int(c) for c in args.color.split(",")) + (255,)

    # 폰트 크기 자동: 배럴 길이의 78% 안에 들어가도록 이진 탐색
    def text_width(size: int) -> int:
        f = load_font(size, args.font)
        d = ImageDraw.Draw(Image.new("RGBA", (8, 8)))
        b = d.textbbox((0, 0), args.text, font=f)
        return b[2] - b[0]

    if args.size:
        size = args.size
    else:
        lo, hi = 20, 140
        target = major_len * 0.78
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if text_width(mid) <= target:
                lo = mid
            else:
                hi = mid - 1
        # 배럴 폭(단축)도 넘지 않게 제한
        size = min(lo, int(minor_len * 0.72))
    font = load_font(size, args.font)

    pad = size * 2
    d0 = ImageDraw.Draw(Image.new("RGBA", (8, 8)))
    bbox = d0.textbbox((0, 0), args.text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    layer = Image.new("RGBA", (tw + pad, th + pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text((pad // 2 - bbox[0], pad // 2 - bbox[1]), args.text, font=font, fill=color)
    rot = layer.rotate(-angle, expand=True, resample=Image.BICUBIC)

    px, py = int(mean[0] - rot.width / 2), int(mean[1] - rot.height / 2)
    clip = np.zeros((base.height, base.width, 4), np.uint8)
    y0, x0 = max(py, 0), max(px, 0)
    y1, x1 = min(py + rot.height, base.height), min(px + rot.width, base.width)
    rot_np = np.array(rot)
    clip[y0:y1, x0:x1] = rot_np[y0 - py:y1 - py, x0 - px:x1 - px]
    clip[..., 3] = (clip[..., 3].astype(int) * (inner // 255)).astype(np.uint8)

    lost = 1 - clip[..., 3].sum() / max(1, rot_np[..., 3].sum())
    out = Image.alpha_composite(base, Image.fromarray(clip))
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    out.save(args.out)
    print(f"[ok] 펜 문구 적용: '{args.text}' (폰트 {size}px, 각도 {angle:.1f}도, 잘림 {lost * 100:.1f}%)")
    if lost > 0.02:
        print("[warn] 문구가 배럴 밖에서 일부 잘렸습니다. 더 짧은 문구나 --size 축소를 권장합니다.")
    print(f"OUTPUT={args.out}")


if __name__ == "__main__":
    main()
