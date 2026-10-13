# -*- coding: utf-8 -*-
"""재미나이 앱(gemini.google.com · 형 구독 · API 키 없음) 「음악 만들기」로 배경음악을 뽑는다 — 형 PC 에서 돈다.

  python app\\tool\\audio\\gem_music.py                   # gemini_music.json 9곡(이미 있는 곡은 건너뜀)
  python app\\tool\\audio\\gem_music.py --only bgm_lobby  # 몇 곡만

곡마다 새 대화: + → 「음악 만들기」 → common + prompt → 소리가 뜨면 받아 gen/<id>.<확장자>.
전용 크롬 창(flow_browser, 9333)의 새 탭을 쓰고 닫는다. 한도·결제·업그레이드 글자가 뜨면 아무것도 누르지 않고 멈춘다.
"""
from __future__ import annotations

import argparse
import base64
import json
import sys
import time
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, r"D:\Gemma4\tongtong_studio")
import flow_browser as FB  # noqa: E402

HERE = Path(__file__).resolve().parent
OUT = HERE / "gen"
STOP = ("한도에 도달", "한도를 초과", "업그레이드", "구매", "결제", "충전")
WAIT_MAX = 600
BLOB = """async (u) => { const b = await (await fetch(u)).arrayBuffer(); let s = ''; const a = new Uint8Array(b);
  for (let i = 0; i < a.length; i += 0x8000) s += String.fromCharCode.apply(null, a.subarray(i, i + 0x8000)); return btoa(s); }"""


class Limit(RuntimeError):
    pass


def media_src(page) -> str | None:
    for sel in ("audio", "video"):
        loc = page.locator(sel)
        if loc.count():
            el = loc.last
            src = el.get_attribute("src") or (el.locator("source").first.get_attribute("src")
                                              if el.locator("source").count() else None)
            if src:
                return src
    return None


def make_one(br, prompt: str, dest: Path, shots: Path) -> Path | None:
    page = br.contexts[0].new_page()
    page.set_viewport_size({"width": 1600, "height": 1000})
    try:
        page.goto("https://gemini.google.com/app?hl=ko", wait_until="domcontentloaded")
        page.wait_for_timeout(6000)
        page.get_by_label("업로드 및 도구").first.click()
        page.wait_for_timeout(1500)
        page.locator(".cdk-overlay-container").get_by_text("음악 만들기", exact=True).first.click(timeout=20000)
        page.wait_for_timeout(1500)
        box = page.get_by_label("Gemini 프롬프트 입력").first
        box.click()
        box.fill(prompt)
        page.wait_for_timeout(800)
        page.keyboard.press("Enter")
        # 10-13 실측: 「문제가 발생했습니다」 뒤 글이 입력칸에 그대로 남는 일이 있다 → 보내기 단추로 한 번 더.
        page.wait_for_timeout(4000)
        if box.inner_text().strip():
            page.locator("button[aria-label*='보내기']").first.click(timeout=10000)
        t0 = time.time()
        while time.time() - t0 < WAIT_MAX:
            page.wait_for_timeout(10000)
            if media_src(page):
                break
            body = page.inner_text("body")
            hit = [w for w in STOP if w in body]
            if hit:
                page.screenshot(path=str(shots / f"{dest.stem}_limit.png"))
                raise Limit(f"멈춤 글자 {hit}")
        else:
            page.screenshot(path=str(shots / f"{dest.stem}_timeout.png"))
            print(f"  ⚠️{dest.stem} 10분 안에 소리가 안 나왔다")
            return None
        page.wait_for_timeout(4000)
        page.screenshot(path=str(shots / f"{dest.stem}_done.png"))
        said = page.locator("model-response").last.inner_text() if page.locator("model-response").count() else ""
        (shots / f"{dest.stem}_answer.txt").write_text(said, encoding="utf-8")
        src = media_src(page)
        data = base64.b64decode(page.evaluate(BLOB, src)) if src.startswith("blob:") else FB.fetch(page, src)
        ext = ".wav" if data[:4] == b"RIFF" else ".mp4" if data[4:8] == b"ftyp" else ".mp3"
        out = dest.with_suffix(ext)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(data)
        print(f"  ⬇{dest.stem} 받음 {len(data) / 1e6:.1f}MB {time.time() - t0:.0f}초 ({ext})")
        return out
    except Limit:
        raise
    except Exception as e:
        page.screenshot(path=str(shots / f"{dest.stem}_error.png"))
        print(f"  ⚠️{dest.stem} 실패: {str(e).splitlines()[0][:200]}")
        return None
    finally:
        page.close()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    spec = json.loads((HERE / "gemini_music.json").read_text(encoding="utf-8"))
    only = {x for x in a.only.split(",") if x}
    tracks = [t for t in spec["tracks"] if not only or t["id"] in only]
    shots = OUT / "_화면"
    shots.mkdir(parents=True, exist_ok=True)
    pw, br, blank = FB.connect("__gem_none__")
    blank.close()
    ok, bad = [], []
    try:
        for t in tracks:
            dest = OUT / t["id"]
            if any(dest.with_suffix(x).exists() for x in (".mp3", ".wav", ".mp4", ".m4a")):
                continue
            prompt = f"{spec['common']} Length about {t['secs']} seconds. {t['prompt']}"
            try:
                got = make_one(br, prompt, dest, shots)
            except Limit as e:
                print(f"⛔한도 — {e}")
                bad.append(t["id"])
                break
            (ok if got else bad).append(t["id"])
    finally:
        pw.stop()
    print(f"\n끝: 성공 {len(ok)} · 실패 {len(bad)} {bad}")
    return 0 if not bad else 1


if __name__ == "__main__":
    raise SystemExit(main())
