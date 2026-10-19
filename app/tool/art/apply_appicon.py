# -*- coding: utf-8 -*-
"""코덱스가 그린 앱 아이콘 한 장으로 안드로이드 아이콘·스토어 그림을 모두 만든다.

2026-10-19 형 「게임 아이콘만 잘좀 만들고 이쁘고 임펙트 있게」·「어떤 이미지인지 알 수 있도록 해주고 귀엽고 이쁜 이미지로」
→ 주문서 wuxia_world.json 의 appicon_g(머리띠 맨 흰 돌이 어지러운 검은 돌을 판 밖으로 · 뒤에 튕기는 손가락).

  python app\\tool\\art\\apply_appicon.py [appicon_g]

만드는 것
- mipmap-*/ic_launcher.png(옛 안드로이드 · 그림 그대로)
- mipmap-*/ic_launcher_background.png(적응형 · 흐린 그림 위에 그림을 80% 로 · 108dp 판의 가운데 72dp 가 보인다)
- mipmap-*/ic_launcher_foreground.png(적응형 앞 칸 · 비움) · 흑백 아이콘(monochrome)은 예전 것 그대로
- store/icon-512.png · store/feature-graphic-1024x500.png(로비 배경 + 제목 + 아이콘)
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
RES = REPO / "app" / "android" / "app" / "src" / "main" / "res"
STORE = REPO / "store"
FONT = REPO / "app" / "assets" / "fonts" / "BlackHanSans-Regular.ttf"
DENS = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def source(name: str) -> Image.Image:
    p = next(q for q in (HERE / "gen" / "world").glob(f"{name}.*") if q.suffix.lower() in (".png", ".jpg", ".webp"))
    return Image.open(p).convert("RGB")


def rounded(im: Image.Image, r: float) -> Image.Image:
    m = Image.new("L", im.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, im.width - 1, im.height - 1), int(im.width * r), fill=255)
    out = im.convert("RGBA")
    out.putalpha(m)
    return out


def adaptive(src: Image.Image, side: int) -> Image.Image:
    """흐린 그림을 바닥에 깔고, 그림을 80% 크기로 가운데에(모서리 둥글게)."""
    bg = src.resize((side, side), Image.LANCZOS).filter(ImageFilter.GaussianBlur(side / 24)).convert("RGBA")
    k = round(side * 0.80)
    fg = rounded(src.resize((k, k), Image.LANCZOS), 0.18)
    bg.alpha_composite(fg, ((side - k) // 2, (side - k) // 2))
    return bg.convert("RGB")


def feature(src: Image.Image) -> Image.Image:
    w, h = 1024, 500
    lobby = Image.open(REPO / "app" / "assets" / "images" / "scenes" / "bg_lobby.webp").convert("RGB")
    k = w / lobby.width
    lobby = lobby.resize((w, round(lobby.height * k)), Image.LANCZOS)
    top = round(lobby.height * 0.18)
    canvas = lobby.crop((0, top, w, top + h)).convert("RGBA")
    shade = Image.new("RGBA", (w, h), (20, 8, 16, 0))
    d = ImageDraw.Draw(shade)
    for x in range(w):  # 왼쪽은 어둡게(글씨 자리) → 오른쪽으로 옅게
        d.line([(x, 0), (x, h)], fill=(20, 8, 16, int(200 * max(0, 1 - x / (w * 0.75)))))
    canvas.alpha_composite(shade)
    icon = rounded(src.resize((360, 360), Image.LANCZOS), 0.2)
    glow = Image.new("RGBA", (400, 400), (0, 0, 0, 0))
    ImageDraw.Draw(glow).rounded_rectangle((10, 10, 390, 390), 80, fill=(255, 200, 80, 150))
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(14)), (w - 360 - 60 - 20, (h - 400) // 2))
    canvas.alpha_composite(icon, (w - 360 - 60, (h - 360) // 2))
    d = ImageDraw.Draw(canvas)
    big = ImageFont.truetype(str(FONT), 96)
    small = ImageFont.truetype(str(FONT), 34)
    tiny = ImageFont.truetype(str(FONT), 24)
    for text, font, y, fill in (("알까기", big, 120, (255, 214, 102)), ("탄지무림", big, 228, (255, 255, 255))):
        d.text((56, y), text, font=font, fill=fill, stroke_width=6, stroke_fill=(40, 10, 20))
    d.text((60, 352), "검지로 톡! 무협 알까기", font=small, fill=(255, 240, 220), stroke_width=4, stroke_fill=(40, 10, 20))
    d.text((60, 440), "(주)웰쉐어로지스", font=tiny, fill=(230, 220, 210), stroke_width=3, stroke_fill=(40, 10, 20))
    return canvas.convert("RGB")


def main() -> int:
    name = sys.argv[1] if len(sys.argv) > 1 else "appicon_g"
    src = source(name)
    clear = lambda s: Image.new("RGBA", (s, s), (0, 0, 0, 0))  # noqa: E731
    for dens, k in DENS.items():
        d = RES / f"mipmap-{dens}"
        src.resize((round(48 * k), round(48 * k)), Image.LANCZOS).save(d / "ic_launcher.png", optimize=True)
        s = round(108 * k)
        adaptive(src, s).save(d / "ic_launcher_background.png", optimize=True)
        clear(s).save(d / "ic_launcher_foreground.png", optimize=True)
    src.resize((512, 512), Image.LANCZOS).save(STORE / "icon-512.png", optimize=True)
    feature(src).save(STORE / "feature-graphic-1024x500.png", optimize=True)
    print("만듦:", name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
