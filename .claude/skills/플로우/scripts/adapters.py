# -*- coding: utf-8 -*-
"""안토니가 만든 스토리보드 → Flow 스토리 정본(story.json) 뼈대.

  python adapters.py md <스토리보드.md> --title 제목 [--ratio 9:16] [--out story.json]
      storyboard 스킬의 메인 표(| # | 타임코드 | 지속 | 샷/앵글 | 카메라 무브 | 화면 설명(액션) | …)
  python adapters.py folk <_작품_script> [--grade 4] [--out story.json]
      민담 보드의 하이라이트 컷(9번째 칸 등급 ≥ grade — folk_audit C2 와 같은 기준)

★뼈대다. cast·locations(기준 그림)는 사람이 고른다 — 그림으로 누가 누구인지 기계가 못 정한다.
  비워 둔 채 flow_story.py 를 돌리면 무엇을 채울지 목록이 나온다.
★Flow 길이는 4·6·8·10초뿐 — 스토리보드 초를 **위로** 맞추고 원래 초는 source_seconds 에 남긴다.
"""
from __future__ import annotations

import argparse
import importlib
import json
import re
import sys
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

STUDIO = Path(r"D:\Gemma4\tongtong_studio")
LENGTHS = (4, 6, 8, 10)
NARRATOR = ("해설", "내레이터", "나레이션", "narrator")


def snap(sec: float, allowed: tuple[int, ...] = LENGTHS) -> int:
    for a in allowed:
        if sec <= a:
            return a
    return allowed[-1]


def _cells(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def from_markdown(md: str) -> list[dict]:
    """storyboard 스킬 메인 표 → 장면 목록. 표 머리줄은 이름으로 찾는다(칸 순서가 바뀌어도 된다)."""
    lines = md.splitlines()
    head = next((i for i, l in enumerate(lines)
                 if l.strip().startswith("|") and "타임코드" in l and ("화면 설명" in l or "액션" in l)), None)
    if head is None:
        raise ValueError("스토리보드 메인 표(타임코드·화면 설명 칸)를 못 찾았다")
    cols = _cells(lines[head])

    def col(*keys: str) -> int | None:
        return next((i for i, c in enumerate(cols) if any(k in c for k in keys)), None)

    idx = {"dur": col("지속"), "angle": col("샷/앵글", "앵글"), "move": col("카메라"),
           "action": col("화면 설명", "액션"), "light": col("조명"), "sound": col("사운드"),
           "line": col("대사", "자막"), "trans": col("전환")}
    shots: list[dict] = []
    for l in lines[head + 1:]:
        if not l.strip().startswith("|"):
            break                                          # 표가 끝났다
        cells = _cells(l)
        if all(set(c) <= set("-: ") for c in cells):
            continue                                       # 구분줄
        get = lambda k: cells[idx[k]] if idx[k] is not None and idx[k] < len(cells) else ""  # noqa: E731
        m = re.search(r"\d+(\.\d+)?", get("dur"))
        sec = float(m.group(0)) if m else 8.0
        say = get("line").strip().strip('"“”')
        shots.append({
            "id": f"S{len(shots) + 1:02d}",
            "duration": snap(sec), "source_seconds": sec,
            "action": get("action"),
            "camera": " · ".join(x for x in (get("angle"), get("move")) if x),
            "light": get("light"),
            "dialogue": [{"who": None, "line": say}] if say and say not in ("-", "—", "없음") else [],
            "cast": [], "location": None,
            "notes": " / ".join(x for x in (get("sound"), get("trans")) if x),
        })
    return shots


def from_folk_board(cuts: list, script: list, grade_min: int = 4,
                    image_dir: Path | None = None, video_dir: Path | None = None) -> list[dict]:
    """민담 보드 하이라이트 컷 → 장면 목록. 영상은 하이라이트에만 쓴다(형 규칙 — 편당 12개).

    하이라이트 = **video/ 에 영상이 붙은 컷** 또는 등급 칸(7·8번) ≥ grade_min.
    ★2026-09-15 실측: 도미·바리데기·우투리·구미호 보드는 등급 칸이 **전부 1** 이다 —
      하이라이트를 video/ 파일 이름으로 표시했다(열전만 7번 칸 = 4). 등급만 보면 0장면이 된다.
    """
    vids = {p.stem for p in video_dir.glob("*.mp4")} if video_dir and video_dir.exists() else set()
    shots = []
    for c in cuts:
        grade = max((c[k] for k in (7, 8) if len(c) > k and isinstance(c[k], (int, float))), default=0)
        if c[2] not in vids and grade < grade_min:
            continue
        lines = [script[i - 1] for i in range(c[0], min(c[1], len(script)) + 1)]
        img = image_dir / f"{c[2]}.png" if image_dir else None
        shots.append({
            "id": c[2], "title": c[3], "duration": 10, "action": c[4], "camera": "", "light": "",
            "mood": c[5],
            "dialogue": [{"who": None, "role": l[0], "line": l[1]} for l in lines
                         if l[0] not in NARRATOR][:2],
            "cast": [], "location": None,
            "start_frame": str(img) if img and img.exists() else None,
        })
    return shots


def skeleton(title: str, shots: list[dict], ratio: str = "16:9", style: str | None = None) -> dict:
    return {"title": title, "ratio": ratio, "model": "Omni Flash 1.1", "style": style,
            "cast": [], "locations": [], "shots": shots,
            "_todo": "cast·locations 에 기준 그림을 채우고, 각 shot 의 cast·location 을 적는다. "
                     "action 에 생김새를 다시 적지 말 것 · 사람 동작 하나 + camera 하나"}


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="kind", required=True)
    md = sub.add_parser("md")
    md.add_argument("path")
    md.add_argument("--title", required=True)
    md.add_argument("--ratio", default="16:9")
    md.add_argument("--style")
    md.add_argument("--out")
    fk = sub.add_parser("folk")
    fk.add_argument("module")
    fk.add_argument("--grade", type=int, default=4)
    fk.add_argument("--style", default="통통그림체0")
    fk.add_argument("--out")
    a = ap.parse_args()
    if a.kind == "md":
        st = skeleton(a.title, from_markdown(Path(a.path).read_text(encoding="utf-8")), a.ratio, a.style)
    else:
        sys.path.insert(0, str(STUDIO))
        mod = importlib.import_module(a.module)
        epd = STUDIO / "Projects" / "channel_story" / getattr(mod, "EP", a.module)
        cuts = json.loads((epd / "board.json").read_text(encoding="utf-8"))["cuts"]
        title = getattr(mod, "TITLE", a.module).split("|")[0].strip()
        st = skeleton(title, from_folk_board(cuts, mod.SCRIPT, a.grade, epd / "image", epd / "video"),
                      "16:9", a.style)
    out = Path(a.out or "story.json")
    out.write_text(json.dumps(st, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"✅ {out} — 장면 {len(st['shots'])}개 · cast·locations 를 채울 차례")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
