# -*- coding: utf-8 -*-
"""배경·대전장 바닥·아이콘을 **코덱스**로 캐릭터와 같은 손그림 무협 화풍으로 뽑고 앱에 넣는다.

2026-10-19 형 「나머지 기능에서도 그래픽을 다 바꿔주고 코덱스를 이용한 이미지 제작해서 다 적용 해줘야 해」·
「추가 기능들 모두 디자인 다 지금 규칙대로 모두 적용 해줘」.
코덱스는 구독 안(API 키 없음) — 그림도구 스킬의 tt_draw.draw_codex 를 그대로 부른다.

  python app\\tool\\art\\gen_world.py draw                 # 주문서 wuxia_world.json 전부(있는 그림은 건너뜀)
  python app\\tool\\art\\gen_world.py draw --only coin,lock --redo
  python app\\tool\\art\\gen_world.py apply                # gen/world/*.png → app/assets/images/(scenes|icons)/*.webp
  python app\\tool\\art\\gen_world.py sheet                # 한눈에 보기 → gen/world/_sheet_*.jpg

그림체 기준으로 캐릭터 그림 한 장(반달 서 있기)을 첨부한다 — 인물은 따라 하지 않고 붓질·색만.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
ASSETS = REPO / "app" / "assets" / "images"
OUT = HERE / "gen" / "world"
STYLE_REF = ASSETS / "chars" / "banDal_idle.webp"

sys.path.insert(0, str(HERE))
from gen_cast import load_tt  # noqa: E402
from pick_cast import key_green  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

# 앱에 넣는 크기(예전 그림과 같게).
SIZE = {"bg": (1080, 1920), "floor": (1024, 1024), "icon": (320, 320)}


def spec() -> dict:
    return json.loads((HERE / "wuxia_world.json").read_text(encoding="utf-8"))


def found(item_id: str) -> Path | None:
    return next((p for p in OUT.glob(f"{item_id}.*") if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp")), None)


def style_ref() -> Path:
    """코덱스 첨부용 PNG(webp 를 못 읽을 때 대비)."""
    ref = OUT / "_style_ref.png"
    if not ref.exists():
        OUT.mkdir(parents=True, exist_ok=True)
        im = Image.open(STYLE_REF).convert("RGBA")
        bg = Image.new("RGBA", im.size, (0, 255, 0, 255))
        bg.alpha_composite(im)
        bg.convert("RGB").save(ref)
    return ref


def draw(a) -> int:
    s = spec()
    only = {x for x in a.only.split(",") if x}
    items = [i for i in s["items"] if (not only or i["id"] in only) and (a.redo or not found(i["id"]))]
    tt = load_tt()
    # 2026-10-19: 공용 설정(~/.codex/config.toml)의 기본 모델 gpt-6.1-sol 은 구독 계정에서 거부된다
    # (「not supported when using Codex with a ChatGPT account」) — 이 실행에서만 모델을 바꾼다.
    base = tt.codex_cmd
    tt.codex_cmd = lambda: base() + ["-c", f'model="{a.model}"']
    ref = style_ref()

    def one(it: dict) -> tuple[str, bool, int]:
        kind = s["kinds"][it["kind"]]
        prompt = f"{it['desc']}\n\n{kind['style']}"
        t0 = time.time()
        try:
            got = tt.draw_codex(prompt, [ref], kind["ratio"], OUT / it["id"],
                                "그림체(붓질·선·색감·명암)만 — 인물은 그리지 않는다")
        except Exception as e:  # 한 장 실패로 나머지를 멈추지 않는다.
            print(f"  ⛔{it['id']}: {e}")
            got = None
        ok = bool(got)
        print(f"{'✅' if ok else '⛔'} {it['id']} {round(time.time() - t0)}초", flush=True)
        return it["id"], ok, round(time.time() - t0)

    print(f"뽑을 그림 {len(items)}장 · 동시 {a.jobs}")
    with ThreadPoolExecutor(a.jobs) as ex:
        log = list(ex.map(one, items))
    bad = [x for x in log if not x[1]]
    (OUT / f"log_{time.strftime('%Y%m%d_%H%M%S')}.json").write_text(
        json.dumps(log, ensure_ascii=False), encoding="utf-8")
    print(f"\n끝: {len(log) - len(bad)}/{len(log)} · 실패 {[x[0] for x in bad]}")
    return 1 if bad else 0


def cover(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """비율을 지키며 꽉 채우고 가운데를 자른다."""
    w, h = size
    k = max(w / im.width, h / im.height)
    im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    x, y = (im.width - w) // 2, (im.height - h) // 2
    return im.crop((x, y, x + w, y + h))


def icon(im: Image.Image, size: tuple[int, int] = SIZE["icon"]) -> Image.Image:
    """초록 지우기 → 그림만 잘라 → 정사각형 가운데(여백 6%) → [size]."""
    im = key_green(im)
    box = im.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    if box:
        im = im.crop(box)
    side = round(max(im.size) / 0.88)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    return sq.resize(size, Image.LANCZOS)


def apply(a) -> int:
    s = spec()
    only = {x for x in a.only.split(",") if x}
    miss = []
    for it in s["items"]:
        if only and it["id"] not in only:
            continue
        src = found(it["id"])
        if not src:
            miss.append(it["id"])
            continue
        im = Image.open(src)
        if it["kind"].startswith("appicon"):
            continue  # 앱 아이콘은 apply_appicon.py 가 만든다.
        if it["kind"] in ("icon", "pet"):
            dest = ASSETS / "icons" / f"{it['id']}.webp"
            size = (480, 480) if it["kind"] == "pet" else SIZE["icon"]
            icon(im, size).save(dest, "WEBP", quality=90, method=6)
        else:
            dest = ASSETS / "scenes" / f"{it['id']}.webp"
            cover(im.convert("RGB"), SIZE[it["kind"]]).save(dest, "WEBP", quality=82, method=6)
        print(f"넣음 {dest.relative_to(REPO)} ({dest.stat().st_size // 1024}KB)")
    if miss:
        print(f"⛔아직 없는 그림: {miss}")
    return 1 if miss else 0


def sheet(a) -> int:
    s = spec()
    for kind, cell in (("bg", (180, 320)), ("floor", (200, 200)), ("icon", (110, 110))):
        its = [i for i in s["items"] if i["kind"] == kind]
        cols = 8 if kind == "icon" else 7
        rows = (len(its) + cols - 1) // cols
        bg = (255, 255, 255) if kind == "icon" else (0, 0, 0)
        out = Image.new("RGB", (cols * cell[0], rows * cell[1]), bg)
        for k, it in enumerate(its):
            folder = "icons" if kind == "icon" else "scenes"
            f = ASSETS / folder / f"{it['id']}.webp"
            if not f.exists():
                continue
            im = Image.open(f).convert("RGBA")
            im.thumbnail(cell, Image.LANCZOS)
            out.paste(im, ((k % cols) * cell[0], (k // cols) * cell[1]), im)
        out.save(OUT / f"_sheet_{kind}.jpg", quality=88)
        print(OUT / f"_sheet_{kind}.jpg")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["draw", "apply", "sheet"])
    ap.add_argument("--only", default="")
    ap.add_argument("--redo", action="store_true")
    ap.add_argument("--jobs", type=int, default=3)
    ap.add_argument("--model", default="gpt-6-sol")
    a = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    return {"draw": draw, "apply": apply, "sheet": sheet}[a.cmd](a)


if __name__ == "__main__":
    raise SystemExit(main())
