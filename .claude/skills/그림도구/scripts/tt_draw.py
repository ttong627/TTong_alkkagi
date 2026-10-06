# -*- coding: utf-8 -*-
"""그림 한 장 — **이름 붙은 그림체**로 뽑고, 숫자 검사로 벗어나면 다시 뽑는다.

  python tt_draw.py "장면 설명(영문 권장)" [--style 통통그림체1] [--engine codex|agy]
                    [--ratio 16:9] [--tries 2] [--out 받을폴더]

엔진 (둘 다 구독 안 · API 키 없음)
  codex  ChatGPT 구독 내장 그림 도구. **기준 그림을 첨부**해 그림체를 붙잡는다 ← 통통그림체1 기본
  agy    안티그라비티 나노바나나(folk_antigravity 연결). 글만 넣는다 — 기준 그림 첨부 불가
⛔유료 API 키로 가는 길은 이 도구에 없다.

「변형 없이」를 지키는 세 겹
  ① 문구 — style.json 의 prompt 한 곳에서만 붙인다(도구마다 따로 적지 않는다)
  ② 기준 그림 — refs/ 를 코덱스에 첨부한다
  ③ 숫자 — style_check 로 재서 벗어나면 다시 뽑는다
★숫자를 통과해도 **눈으로 본다** — 글자·도장·손가락·얼굴은 숫자로 못 잡는다.
"""
from __future__ import annotations

import argparse
import importlib
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import style_check as sc  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

STUDIO = Path(r"D:\Gemma4\tongtong_studio")          # folk_antigravity 연결 SSOT 가 있는 곳
CODEX_IMAGES = Path.home() / ".codex" / "generated_images"
CODEX_JS = Path.home() / "AppData" / "Roaming" / "npm" / "node_modules" / "@openai" / "codex" / "bin" / "codex.js"
IMG_EXT = (".png", ".jpg", ".jpeg", ".webp")


def build_prompt(scene: str, style: dict) -> str:
    """문구는 style.json 한 곳. 단, **정본이 따로 있는 그림체**(통통그림체0 = folk_style.py)는
    그 모듈의 build() 를 부른다 — 복사해 두면 정본이 두 벌이 되어 반드시 어긋난다."""
    mod = style.get("prompt_module")
    if mod:
        sys.path.insert(0, str(STUDIO))
        m = importlib.import_module(mod)
        attr = style.get("prompt_attr")
        if attr:                     # 렌더링 문구 한 줄만 정본에서 가져온다(예: _jahwal_char.LOOK)
            return f"{scene.strip()}\n\n{getattr(m, attr)}"
        return m.build(scene.strip())
    return f"{scene.strip()}\n\n{style['prompt']}"


def codex_cmd() -> list[str]:
    """codex.cmd 를 거치면 한글·줄바꿈 인자가 깨질 수 있어 node 로 직접 부른다."""
    node = shutil.which("node")
    if node and CODEX_JS.exists():
        return [node, str(CODEX_JS)]
    exe = shutil.which("codex")
    if not exe:
        raise RuntimeError("codex 가 없다 — npm i -g @openai/codex 후 codex login")
    return [exe]


def codex_args(prompt: str, refs: list[Path], ratio: str, ref_note: str = "") -> list[str]:
    """ref_note = 기준 그림에서 **무엇을** 따를지 — 그림체마다 다르다(style.json)."""
    note = ref_note or "그림체(붓질·질감·색)"
    msg = (f"이미지를 한 장 생성해 줘. 비율 {ratio}. "
           + (f"첨부한 그림은 **그림체 기준**이다 — {note}을(를) 그대로 따르고, "
              "그림 속 인물·장소는 따라 하지 말고 아래 내용을 그린다. " if refs else "")
           + "파일은 쓰지 말고 이미지 생성 도구만 써.\n"
           + f"내용: {prompt}\n생성한 파일의 절대 경로를 마지막 줄에 출력해.")
    args = codex_cmd() + ["exec", "--skip-git-repo-check", msg]   # ★글을 -i 앞에 — -i 는 여러 값을 받는다
    for r in refs:
        args += ["-i", str(r)]
    return args


def draw_codex(prompt: str, refs: list[Path], ratio: str, dest: Path,
               ref_note: str = "") -> Path | None:
    t0 = time.time()
    run = subprocess.run(codex_args(prompt, refs, ratio, ref_note), capture_output=True, text=True,
                         encoding="utf-8", errors="ignore", stdin=subprocess.DEVNULL, timeout=900)
    src = printed_image(run.stdout or "", t0)
    if src is None:
        tail = (run.stdout or run.stderr or "")[-300:].replace("\n", " ")
        print(f"  ⛔코덱스가 그림을 안 만들었다 (rc={run.returncode}) {tail}")
        return None
    out = dest.with_suffix(src.suffix.lower())
    out.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, out)
    return out


def printed_image(stdout: str, t0: float) -> Path | None:
    """코덱스가 **마지막 줄에 찍은 경로**를 먼저 믿는다.

    ★두 장을 동시에 뽑으면 「가장 새 파일」은 남의 그림일 수 있다.
      경로가 안 찍혔을 때만 t0 뒤에 생긴 가장 새 파일로 찾는다.
    """
    for line in reversed(stdout.strip().splitlines()):
        p = Path(line.strip().strip("`\"'"))
        if p.suffix.lower() in IMG_EXT and p.exists():
            return p
    new = sorted((p for p in CODEX_IMAGES.rglob("*")
                  if p.suffix.lower() in IMG_EXT and p.stat().st_mtime >= t0),
                 key=lambda p: p.stat().st_mtime)
    return new[-1] if new else None


def draw_agy(prompt: str, ratio: str, dest: Path) -> Path | None:
    sys.path.insert(0, str(STUDIO))
    import folk_antigravity as fa                     # 연결 SSOT — 한 벌만 둔다
    base, hdr = fa.connect()
    return fa.generate(base, hdr, prompt, dest.with_suffix(".png"), aspect=ratio)


def main() -> int:
    ap = argparse.ArgumentParser(description="이름 붙은 그림체로 그림 한 장")
    ap.add_argument("scene")
    ap.add_argument("--style", default="통통그림체1")
    ap.add_argument("--engine", choices=["codex", "agy"])
    ap.add_argument("--ratio", help="안 주면 그림체의 ratio_default (없으면 16:9)")
    ap.add_argument("--tries", type=int, default=2)
    ap.add_argument("--out")
    a = ap.parse_args()

    style = sc.load_style(a.style)
    sdir = sc.STYLES / a.style
    refs = [sdir / r for r in style.get("refs", []) if (sdir / r).exists()]
    engine = a.engine or style.get("engine_default", "codex")
    ratio = a.ratio or style.get("ratio_default", "16:9")
    out_dir = Path(a.out) if a.out else (
        Path.home() / "Downloads" / f"그림도구_{datetime.now():%y%m%d_%H%M%S}")
    prompt = build_prompt(a.scene, style)
    print(f"■ {style['title']} · 엔진 {engine} · 기준 그림 {len(refs)}장 · 받을 곳 {out_dir}")

    for i in range(1, a.tries + 1):
        dest = out_dir / f"{a.style}_{i:02d}"
        got = (draw_codex(prompt, refs, ratio, dest, style.get("ref_note", "")) if engine == "codex"
               else draw_agy(prompt, ratio, dest))
        if not got:
            continue
        m = sc.metrics(got)
        off = sc.judge(m, style["ranges"])
        print(f"  {i}차 {got.name} {m}" + (f" ← 벗어남 {off}" if off else " ✅"))
        if not off:
            print(f"✅ {got}\n→ 숫자 통과. 이제 **눈으로** 본다(글자·도장·손가락·얼굴).")
            return 0
    print(f"⛔{a.tries}번 뽑아도 그림체 기준을 못 맞췄다 — 문구·기준 그림을 본다. 받은 곳: {out_dir}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
