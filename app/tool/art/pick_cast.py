#!/usr/bin/env python3
"""무협 캐릭터 시안(gen_cast.py 결과)을 비교하고, 고른 것을 앱 그림으로 만든다 — 클라우드에서 돈다.

  python tool/art/pick_cast.py compare                 # build/compare/<id>.png · build/compare/_all.png
  python tool/art/pick_cast.py apply picks.json        # assets/images/chars/<id>_{idle,attack,face}.webp

picks.json = {"<id>": {"engine": "codex"|"agy"}, ...}  (또는 "*": {"engine": "codex"} 로 모두)
 - engine: 어느 엔진 그림을 쓸지(서 있기·탄지 둘 다 같은 엔진 — 한 사람이 두 화풍이 되지 않게)
 - 방향: 앱 그림은 **오른쪽을 본다**(탄지 손이 오른쪽). 탄지 자세가 왼쪽으로 뻗었으면 두 자세 모두 뒤집는다(엔진마다 방향이 들쭉날쭉 — 나노바나나 실측).

처리: 초록 배경(#00FF00) 지우기 → 가장자리 초록 번짐 빼기 → 몸만 잘라 880×1040 판에 발을 y=1032 에 맞춰 세움
      → 얼굴만 따로 256×256(동그란 얼굴 칸용 · 7등신이라 전신 그림에서 얼굴이 작다).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

APP = Path(__file__).resolve().parents[2]
GEN = APP / "tool" / "art" / "gen"
OUT = APP / "assets" / "images" / "chars"
CMP = APP / "build" / "compare"
W, H, FEET = 880, 1040, 1032
FIG_H = 1000  # 머리끝~발끝 높이(화소)


def find(engine: str, cid: str, pose: str) -> Path | None:
    for ext in (".png", ".jpg", ".jpeg", ".webp"):
        p = GEN / engine / f"{cid}_{pose}{ext}"
        if p.exists():
            return p
    return None


def key_green(im: Image.Image) -> Image.Image:
    """초록 배경 → 투명. 초록이 빨강·파랑보다 얼마나 앞서는지로 투명도를 정하고, 가장자리 초록을 뺀다."""
    a = np.asarray(im.convert("RGBA")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lead = g - np.maximum(r, b)
    alpha = np.clip(1 - (lead - 40) / (120 - 40), 0, 1)
    # 남는 초록 번짐: 초록을 빨강·파랑 큰 쪽까지 내린다(반투명 가장자리).
    spill = lead > 0
    g2 = np.where(spill, np.maximum(r, b) + (g - np.maximum(r, b)) * 0.15, g)
    out = np.stack([r, g2, b, a[..., 3] * alpha], -1)
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), "RGBA")


def faces_left(im: Image.Image) -> bool:
    """탄지 자세가 왼쪽으로 뻗었나: 어깨 높이(키의 22~40%)에서 몸통 가운데로부터 왼쪽·오른쪽 끝까지 거리를 견준다.
    뻗은 팔이 더 멀리 나간다(머리카락은 위, 허리띠는 아래라 이 높이를 피한다)."""
    a = np.asarray(key_green(im).getchannel("A")).astype(np.float32)
    ys, _ = np.nonzero(a > 24)
    top, bottom = ys.min(), ys.max()
    hgt = bottom - top
    torso = a[top + int(hgt * 0.3) : top + int(hgt * 0.55)]
    cx = (torso.sum(0) * np.arange(torso.shape[1])).sum() / max(1, torso.sum())
    band = a[top + int(hgt * 0.22) : top + int(hgt * 0.40)] > 24
    cols = np.nonzero(band.any(0))[0]
    return (cx - cols.min()) > (cols.max() - cx)


def place(im: Image.Image, flip: bool) -> Image.Image:
    im = key_green(im)
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    alpha = np.asarray(im.getchannel("A"))
    ys, xs = np.nonzero(alpha > 24)
    if len(xs) == 0:
        raise ValueError("빈 그림")
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    fig = im.crop(box)
    k = FIG_H / fig.height
    if fig.width * k > W - 8:
        k = (W - 8) / fig.width
    fig = fig.resize((max(1, round(fig.width * k)), max(1, round(fig.height * k))), Image.LANCZOS)
    # 몸통 가운데(아래 절반의 무게중심)를 판 가운데에.
    fa = np.asarray(fig.getchannel("A")).astype(np.float32)
    lower = fa[fa.shape[0] // 2 :]
    cx = (lower.sum(0) * np.arange(lower.shape[1])).sum() / max(1, lower.sum())
    canvas = Image.new("RGBA", (W, H))
    x = int(round(W / 2 - cx))
    x = min(max(x, W - fig.width), 0) if fig.width > W else min(max(x, 0), W - fig.width)
    canvas.alpha_composite(fig, (x, FEET - fig.height))
    return canvas


def face(full: Image.Image) -> Image.Image:
    """서 있기 그림에서 얼굴 둘레를 정사각형으로(머리끝에서 그림 높이의 0~22%)."""
    a = np.asarray(full.getchannel("A")).astype(np.float32)
    ys, xs = np.nonzero(a > 24)
    top, bottom = ys.min(), ys.max()
    hgt = bottom - top
    band = a[top : top + int(hgt * 0.13)]
    cx = (band.sum(0) * np.arange(band.shape[1])).sum() / max(1, band.sum())
    side = int(hgt * 0.24)
    cy = top + int(hgt * 0.095)
    box = (int(cx - side / 2), int(cy - side / 2), int(cx + side / 2), int(cy + side / 2))
    return full.crop(box).resize((256, 256), Image.LANCZOS)


def checker(w: int, h: int) -> Image.Image:
    c = Image.new("RGBA", (w, h), (70, 60, 50, 255))
    px = c.load()
    for y in range(0, h, 32):
        for x in range(0, w, 32):
            if (x // 32 + y // 32) % 2:
                for yy in range(y, min(y + 32, h)):
                    for xx in range(x, min(x + 32, w)):
                        px[xx, yy] = (90, 80, 68, 255)
    return c


def compare() -> None:
    spec = json.loads((APP / "tool" / "art" / "wuxia_cast.json").read_text(encoding="utf-8"))
    CMP.mkdir(parents=True, exist_ok=True)
    tiles = []
    bg = checker(W // 2, H // 2)
    for who in spec["cast"]:
        row = []
        for eng in ("codex", "agy"):
            for pose in ("idle", "attack"):
                p = find(eng, who["id"], pose)
                t = bg.copy()
                if p:
                    t.alpha_composite(place(Image.open(p), flip=False).resize((W // 2, H // 2)))
                row.append(t)
        sheet = Image.new("RGBA", (W // 2 * 4 + 30, H // 2), (30, 24, 20, 255))
        for i, t in enumerate(row):
            sheet.alpha_composite(t, (i * (W // 2) + (30 if i >= 2 else 0), 0))
        sheet.convert("RGB").save(CMP / f"{who['id']}.png")
        tiles.append(sheet)
    if tiles:
        allh = sum(t.height for t in tiles)
        big = Image.new("RGB", (tiles[0].width, allh))
        y = 0
        for t in tiles:
            big.paste(t.convert("RGB"), (0, y))
            y += t.height
        big.resize((big.width // 3, big.height // 3)).save(CMP / "_all.png")
    print(f"비교 그림 {len(tiles)}장 → {CMP} (왼쪽 둘 = 코덱스 서기·탄지 · 오른쪽 둘 = 나노바나나)")


def apply(picks_path: str) -> None:
    picks = json.loads(Path(picks_path).read_text(encoding="utf-8"))
    spec = json.loads((APP / "tool" / "art" / "wuxia_cast.json").read_text(encoding="utf-8"))
    ids = [c["id"] for c in spec["cast"]]
    for cid in ids:
        pk = picks.get(cid) or picks.get("*")
        if not pk:
            continue
        eng = pk["engine"]
        att = find(eng, cid, "attack")
        if not att or not find(eng, cid, "idle"):
            alt = "agy" if eng == "codex" else "codex"
            if find(alt, cid, "attack") and find(alt, cid, "idle"):
                print(f"↪ {cid}: {eng} 그림이 모자라 {alt} 로")
                eng, att = alt, find(alt, cid, "attack")
            else:
                print(f"⛔{cid}: 두 자세가 다 있는 엔진이 없음 — 건너뜀")
                continue
        flip = faces_left(Image.open(att)) if "flip" not in pk else bool(pk["flip"])
        for pose in ("idle", "attack"):
            img = place(Image.open(find(eng, cid, pose)), flip)
            img.save(OUT / f"{cid}_{pose}.webp", "WEBP", quality=88, method=6)
            if pose == "idle":
                face(img).save(OUT / f"{cid}_face.webp", "WEBP", quality=90, method=6)
        print(f"✅ {cid} ← {eng}{' (뒤집음)' if flip else ''}")


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "compare":
        compare()
    elif len(sys.argv) >= 3 and sys.argv[1] == "apply":
        apply(sys.argv[2])
    else:
        sys.exit(__doc__)
