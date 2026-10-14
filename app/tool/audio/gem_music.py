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
import re
import sys
import time
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, r"D:\Gemma4\tongtong_studio")
import flow_browser as FB  # noqa: E402

HERE = Path(__file__).resolve().parent
OUT = HERE / "gen"
STOP = ("한도에 도달", "한도를 초과", "업그레이드", "구매", "결제", "충전")
# 10-14 실측: 기본 모델(3.1 Pro)이 「Sorry, something went wrong」만 답해 10분씩 기다렸다 → 오류 답이면 바로 넘어간다.
FAIL = ("went wrong", "encountered an error", "문제가 발생", "오류가 발생")
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


def _button(page, text: str):
    """단추 글자가 꼭 [text] 인 단추(모델 단추는 이름이 「모드 선택 도구 열기 …」라 글자로 찾는다)."""
    return page.locator("button").filter(has_text=re.compile(rf"^\s*{re.escape(text)}\s*$"))


def choose(page, shown: str, buttons: list[str], option: str) -> None:
    """음악 칸 아래 선택 단추(길이·보컬·모델)에서 [option] 을 고른다. 이미 [shown] 이 보이면 그대로."""
    if _button(page, shown).count():
        return
    for b in buttons:
        loc = _button(page, b)
        if loc.count():
            loc.first.click(timeout=10000)
            page.wait_for_timeout(1200)
            page.get_by_text(option, exact=True).last.click(timeout=10000)
            page.wait_for_timeout(1200)
            return
    raise RuntimeError(f"「{option}」 고를 단추를 못 찾음({buttons})")


def make_one(br, prompt: str, dest: Path, shots: Path, ui: list[dict] | None = None) -> Path | None:
    page = br.contexts[0].new_page()
    page.set_viewport_size({"width": 1600, "height": 1000})
    try:
        page.goto("https://gemini.google.com/app?hl=ko", wait_until="domcontentloaded")
        page.wait_for_timeout(6000)
        page.get_by_label("업로드 및 도구").first.click()
        page.wait_for_timeout(1500)
        page.locator(".cdk-overlay-container").get_by_text("음악 만들기", exact=True).first.click(timeout=20000)
        page.wait_for_timeout(1500)
        for u in ui or []:
            choose(page, u["shown"], u["buttons"], u["pick"])
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
            said = page.locator("model-response").last.inner_text() if page.locator("model-response").count() else ""
            if any(w in said for w in FAIL):
                page.screenshot(path=str(shots / f"{dest.stem}_error.png"))
                print(f"  ⚠️{dest.stem} 재미나이 오류 답: {said.strip().splitlines()[-1][:120]}")
                return None
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
    ap.add_argument("--spec", default="gemini_music.json", help="주문서(같은 폴더) — 짧은 곡은 gemini_jingles.json")
    a = ap.parse_args()
    spec = json.loads((HERE / a.spec).read_text(encoding="utf-8"))
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
            secs = f" Length about {t['secs']} seconds." if spec.get("say_secs", True) else ""
            prompt = f"{spec['common']}{secs} {t['prompt']}"
            try:
                got = make_one(br, prompt, dest, shots, spec.get("ui"))
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
