# -*- coding: utf-8 -*-
"""무협 캐릭터 21명 × 2자세를 **코덱스**와 **나노바나나(안티그라비티)** 로 같은 문구로 뽑는다 — 형 PC 에서 돈다.

2026-10-11 형 지시: 「캐릭터는 코덱스 2.5 이미지와 나노바나나 2.1 이미지를 비교해서 탄탄한 구성으로」.
두 엔진 모두 구독 안(API 키 없음) — 그림도구 스킬의 tt_draw.py(draw_codex · draw_agy)를 그대로 부른다.

  python app\\tool\\art\\gen_cast.py                      # 두 엔진 · 42장씩(이미 있는 파일은 건너뜀)
  python app\\tool\\art\\gen_cast.py --only seokdu,yeonbi  # 몇 명만
  python app\\tool\\art\\gen_cast.py --engines codex       # 한 엔진만
  python app\\tool\\art\\gen_cast.py --push                # 다 뽑은 뒤 브랜치 art/wuxia-cast 로 올림

결과: app/tool/art/gen/<엔진>/<id>_<idle|attack>.png (배경은 초록 #00FF00 — 앱에 넣을 때 지운다)
- 서 있기를 먼저 뽑고, 탄지 자세는 **그 엔진의 서 있기 그림을 기준으로 첨부**해 같은 사람이 되게 한다(코덱스만 첨부 가능).
- 비교·고르기·배경 지우기·앱 크기로 줄이기는 클라우드 세션이 한다(tool/art/pick_cast.py).
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
SKILL = Path.home() / ".claude" / "skills" / "그림도구" / "scripts"
OUT = HERE / "gen"

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


def load_tt():
    if not (SKILL / "tt_draw.py").exists():
        sys.exit(f"그림도구 스킬이 없다: {SKILL} — 이 PC 에 /그림도구 가 설치돼 있어야 한다.")
    sys.path.insert(0, str(SKILL))
    import tt_draw  # noqa: E402  — 코덱스·안티그라비티 연결은 한 벌(tt_draw)만 쓴다
    return tt_draw


def prompt_for(spec: dict, who: dict, pose: str) -> str:
    return f"{who['desc']}\n{spec['poses'][pose]}\n\n{spec['style']}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--engines", default="codex,agy")
    ap.add_argument("--only", default="")
    ap.add_argument("--poses", default="idle,attack")
    ap.add_argument("--redo", action="store_true", help="이미 있는 그림도 다시")
    ap.add_argument("--push", action="store_true", help="끝나면 브랜치 art/wuxia-cast 로 올림")
    a = ap.parse_args()

    spec = json.loads((HERE / "wuxia_cast.json").read_text(encoding="utf-8"))
    only = {x for x in a.only.split(",") if x}
    cast = [c for c in spec["cast"] if not only or c["id"] in only]
    engines = [e for e in a.engines.split(",") if e]
    poses = [p for p in a.poses.split(",") if p]
    tt = load_tt()

    log = []
    for eng in engines:
        for who in cast:
            for pose in poses:
                dest = OUT / eng / f"{who['id']}_{pose}"
                if not a.redo and any(dest.with_suffix(x).exists() for x in (".png", ".jpg", ".webp")):
                    continue
                prompt = prompt_for(spec, who, pose)
                refs = []
                if eng == "codex" and pose != "idle":
                    idle = next((p for p in (OUT / eng).glob(f"{who['id']}_idle.*")), None)
                    if idle:
                        refs = [idle]
                t0 = time.time()
                try:
                    if eng == "codex":
                        got = tt.draw_codex(prompt, refs, spec["ratio"], dest,
                                            "같은 인물(얼굴·머리·옷·색)과 그림체" if refs else "")
                    else:
                        got = tt.draw_agy(prompt, spec["ratio"], dest)
                except Exception as e:  # 한 장 실패로 나머지를 멈추지 않는다.
                    got = None
                    print(f"  ⛔{eng} {who['id']}_{pose}: {e}")
                ok = bool(got)
                log.append({"engine": eng, "id": who["id"], "pose": pose, "ok": ok,
                            "file": str(got.relative_to(REPO)) if ok else None,
                            "secs": round(time.time() - t0, 1)})
                print(f"{'✅' if ok else '⛔'} {eng} {who['id']}_{pose} {round(time.time() - t0)}초")

    OUT.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d_%H%M%S")
    (OUT / f"log_{stamp}.json").write_text(json.dumps(log, ensure_ascii=False, indent=1), encoding="utf-8")
    bad = [x for x in log if not x["ok"]]
    print(f"\n끝: {len(log) - len(bad)}/{len(log)} 장 · 실패 {len(bad)}")

    if a.push:
        br = "art/wuxia-cast"
        run = lambda *c: subprocess.run(c, cwd=REPO, check=True)  # noqa: E731
        cur = subprocess.run(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=REPO,
                             capture_output=True, text=True).stdout.strip()
        if cur != br:
            run("git", "checkout", "-B", br)
        run("git", "add", "-f", str(OUT.relative_to(REPO)))
        run("git", "commit", "-m", f"무협 캐릭터 시안 (코덱스·나노바나나) {stamp}")
        run("git", "push", "-u", "origin", br)
        print(f"올림: 브랜치 {br}")
    return 0 if not bad else 1


if __name__ == "__main__":
    raise SystemExit(main())
