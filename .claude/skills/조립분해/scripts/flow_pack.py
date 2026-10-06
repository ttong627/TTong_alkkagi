# -*- coding: utf-8 -*-
"""입체 영상에 구글 Flow 로 화풍 입히기 — 편집 패키지 만들기 + 받은 클립 검사.

Flow 공식 도움말(2026-09-15 확인 · support.google.com/flow/answer/16352836):
  Gemini Omni Flash 1.1 「기존 영상을 활용한 AI 편집」 — 가로·세로 · **최대 10초** · 업로드한 영상을 새 프롬프트와 소재로 수정
  360p 초안은 크레딧 절반 · Pro/Ultra 는 360p→720p 올리기 크레딧 0
비유: 색보정 외주. 움직임(원본 영상)은 우리가 찍어 넘기고, Flow 는 **겉모습만** 바꾼다. 생성 버튼은 형이 누른다.

★통통그림체 문구에는 인물·얼굴·손 문장이 섞여 있고, 그림체 3 의 기준 그림은 **캐릭터 시트**다.
  사물 영상에 그대로 주면 Flow 가 사람·캐릭터를 끼워 넣는다 → 렌더링 문장만 남기고, 캐릭터 시트는 넣지 않는다.
"""
from __future__ import annotations

import json
import math
import re
import shutil
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
FLOW_SCRIPTS = HERE.parent.parent / "플로우" / "scripts"
sys.path.insert(0, str(HERE))
sys.path.insert(1, str(FLOW_SCRIPTS))

import media  # noqa: E402
import plan as P  # noqa: E402

MAX_EDIT = 10.0
FRACS = (0.1, 0.5, 0.9)
PKG = "플로우_화풍"
PEOPLE = re.compile(
    r"\b(figures?|people|persons?|characters?|faces?|hands?|fingers?|hanbok|expressions?|eyes|eyebrows|mouths?|"
    r"proportions?|acting|man|woman|men|women|hair|sunglasses|glasses|skin|body|costume|outfit|wearing|boss)\b", re.I)


# ── 자르기 ─────────────────────────────────────────────────

def _cuts(a: float, b: float, limit: float) -> list[float]:
    n = max(1, math.ceil((b - a) / limit - 1e-9))
    return [a + (b - a) * i / n for i in range(n + 1)]


def segments(timeline: list, limit: float = MAX_EDIT) -> list[tuple[float, float]]:
    """구간 경계에서만 자른다. 조각 수는 가장 적게, 그중 가장 짧은 조각이 가장 길게(너무 짧은 조각 방지)."""
    cuts = sorted({round(x, 6) for _, a, b in timeline for x in _cuts(a, b, limit)})
    inner, best = cuts[1:-1], None
    for mask in range(1 << len(inner)):
        pts = [cuts[0]] + [c for i, c in enumerate(inner) if mask >> i & 1] + [cuts[-1]]
        lens = [y - x for x, y in zip(pts, pts[1:])]
        if max(lens) > limit + 1e-6:
            continue
        score = (len(lens), -min(lens))
        if best is None or score < best[0]:
            best = (score, pts)
    return list(zip(best[1], best[1][1:]))


# ── 프롬프트 ───────────────────────────────────────────────

def rendering_only(text: str) -> str:
    """사람·얼굴·손·옷 문장을 빼고 붓질·재질·색·빛 문장만 남긴다."""
    sentences = re.split(r"(?<=[.!?])\s+", re.sub(r"\s+", " ", text or "").strip())
    return " ".join(s for s in sentences if s and not PEOPLE.search(s))[:900]


def style_parts(name: str) -> tuple[str, str, Path | None, bool]:
    """(화풍 이름, 렌더링 문구, 기준 그림, 기준 그림이 캐릭터 시트인가) — /그림도구 정본을 /플로우 길로 읽는다."""
    import flow_story
    title, text, ref = flow_story.style_bits(name)
    is_sheet = bool(ref) and bool(re.search(r"character|캐릭터", str(ref), re.I))
    return title, rendering_only(text), ref, is_sheet


def edit_prompt(ratio: str, notes: str, use_ref: bool) -> tuple[str, list[str]]:
    import flow_story
    body = [
        ("Restyle this entire video so it looks like the attached style reference image."
         if use_ref else "Restyle this entire video in the visual style described below."),
        "Keep the camera movement, the timing and every object exactly as in the source video: the same number of "
        "parts, the same shapes, the same positions and the same motion from start to end.",
        "Change only the look: rendering, brushwork, materials, colors, background and lighting.",
    ]
    if use_ref:
        body.append("Use the reference image only for its rendering style. Do not copy any character, person or "
                    "object from it.")
    body += ["Do not add or remove anything. No people, no hands, no text, no logos, no captions.", f"{ratio} frame."]
    warns: list[str] = []
    prompt = "\n".join(body + ([f"Style notes: {notes}"] if notes else []))
    bad, warn = flow_story.gate(prompt)
    if bad and notes:
        warns.append("화풍 문구에 막히는 낱말이 있어 문구를 뺐다 — " + "; ".join(bad))
        prompt = "\n".join(body)
        bad, warn = flow_story.gate(prompt)
    if bad:
        raise SystemExit("⛔ 편집 프롬프트가 문지기에 걸렸다 — " + "; ".join(bad))
    return prompt, warns + warn


# ── 패키지 ─────────────────────────────────────────────────

def _readme(meta: dict, out: Path) -> str:
    rows = "\n".join(f"| {s['id']} | {s['start']:.1f}~{s['end']:.1f}초 ({s['end'] - s['start']:.1f}초) | "
                     f"{' · '.join(s['phases'])} |" for s in meta["segments"])
    ref_line = ("   → 소재(참고 그림)로 `01_화풍기준` 을 추가한다\n" if meta["use_ref"] else "")
    sheet = ("\n⚠️이 화풍의 기준 그림은 **캐릭터 시트**라 넣지 않았다 — 넣으면 Flow 가 캐릭터를 끼워 넣을 수 있다.\n"
             "   문구만으로 부족하면 **캐릭터가 없는** 같은 화풍 장면 그림을 골라 소재로 넣는다.\n"
             if meta["ref_is_sheet"] else "")
    return f"""# 「{meta['title']}」 — Flow 화풍 입히기

만든 때 {meta['made']} · 화풍 **{meta['style']}** · 조각 {len(meta['segments'])}개
(Omni Flash 1.1 영상 편집은 한 번에 **최대 10초**라 구간 경계에서 나눴다)

| 조각 | 시간 | 구간 |
|---|---|---|
{rows}

## 순서
1. flow.google.com → 새 프로젝트 「{meta['title']} 화풍」
2. 프롬프트 칸 설정 → 모델 **Gemini Omni Flash 1.1** · 비율 **{meta['ratio']}** · 해상도 **360p(초안, 크레딧 절반)**
3. 왼쪽 **업로드** → `02_원본클립/` 의 조각 영상을 올린다{' + `01_화풍기준` 그림' if meta['use_ref'] else ''}
4. 올린 **P01** 을 연다 → **영상 수정(기존 영상을 활용한 AI 편집)** → `03_편집프롬프트/P01.txt` 붙여넣기
{ref_line}   → 생성 전 크레딧 확인 → 생성
5. 조각마다 반복 — **같은 프롬프트·같은 기준**을 쓴다(조각끼리 화풍이 다르면 이음매에서 튄다)
6. 마음에 드는 것만 **720p 올리기**(ULTRA 크레딧 0) → 내려받아 `04_받은클립/P01.mp4` … 이름으로 둔다
7. 검사: `python "{HERE / 'make.py'}" 플로우검사 "{out}"`
   → 조각마다 원본 움직임을 따르는지 숫자 + `05_대조/` 그림 · 다 모이면 `화풍_완성.mp4` 로 잇는다

⚠️버튼 이름은 공식 도움말 표현이다 — 화면의 실제 이름은 처음 쓸 때 확인한다(안토니가 아직 눌러 보지 않았다)
⚠️AI 편집은 부품 수·모양을 바꿀 수 있다 → **조립 순서의 정본은 `입체.mp4`·`도면선.mp4`**
{sheet}⛔생성 버튼 자동 클릭 없음 · 검색에 걸리는 공유 링크판 도구에는 넣지 않는다
"""


def package(out: Path, style: str) -> int:
    scene = json.loads((out / "_장면키.json").read_text(encoding="utf-8"))
    src = out / "입체.mp4"
    if not src.exists():
        print(f"❌ {src} 가 없다 — 먼저 make.py 렌더 <계획> --모드 입체")
        return 1
    pkg = out / PKG
    title, notes, ref, is_sheet = style_parts(style)
    use_ref = bool(ref) and not is_sheet
    prompt, warns = edit_prompt(scene["ratio"], notes, use_ref)
    issues, rows = [], []
    (pkg / "03_편집프롬프트").mkdir(parents=True, exist_ok=True)
    for i, (a, b) in enumerate(segments([tuple(x) for x in scene["timeline"]]), 1):
        sid = f"P{i:02d}"
        issues += media.cut(src, a, b, pkg / "02_원본클립" / f"{sid}.mp4")
        (pkg / "03_편집프롬프트" / f"{sid}.txt").write_text(prompt + "\n", encoding="utf-8")
        rows.append({"id": sid, "start": round(a, 3), "end": round(b, 3), "src": f"02_원본클립/{sid}.mp4",
                     "phases": [P.PHASE_KO[ph] for ph, x, y in scene["timeline"] if x < b - 1e-6 and y > a + 1e-6]})
    if use_ref:
        shutil.copy2(ref, pkg / f"01_화풍기준{ref.suffix.lower()}")
    (pkg / "04_받은클립").mkdir(exist_ok=True)
    (pkg / "04_받은클립" / "넣는법.txt").write_text("Flow 에서 받은 영상을 조각 이름(P01.mp4 …)으로 이 폴더에 둔다.\n",
                                                  encoding="utf-8")
    from PIL import Image
    first = next(iter(sorted((out / "입체_장면").glob("*.png"))), None)
    size = list(Image.open(first).size) if first else ([1920, 1080] if scene["ratio"] == "16:9" else [1080, 1920])
    meta = {"title": scene["title"], "style": style, "style_title": title, "ratio": scene["ratio"], "fps": scene["fps"],
            "size": size, "segments": rows, "use_ref": use_ref, "ref_is_sheet": is_sheet, "notes": notes,
            "warnings": warns, "made": f"{datetime.now():%Y-%m-%d %H:%M}"}
    (pkg / "조각.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    (pkg / "00_먼저읽기.md").write_text(_readme(meta, out), encoding="utf-8")
    print(f"Flow 화풍 패키지 — {pkg}")
    for s in rows:
        print(f"  {s['id']} {s['start']:.1f}~{s['end']:.1f}초 · {' · '.join(s['phases'])}")
    print(f"  화풍 {style} · 기준 그림 {'넣음' if use_ref else ('캐릭터 시트라 뺌' if is_sheet else '없음')}"
          f" · 렌더링 문구 {len(notes)}자")
    for w in warns:
        print("  ⚠️", w)
    for e in issues:
        print("  ❌", e)
    return 1 if issues else 0


# ── 받은 클립 검사 ─────────────────────────────────────────

def edge_structure(a, b) -> float:
    """윤곽선끼리의 구조 유사도 — 색·질감(화풍)이 바뀌어도 모양·위치가 같으면 높다."""
    import cv2
    import numpy as np
    from skimage.metrics import structural_similarity
    h, w = a.shape[:2]
    size = (320, max(2, round(320 * h / w)))

    def edges(img):
        g = cv2.cvtColor(cv2.resize(img, size), cv2.COLOR_BGR2GRAY)
        return cv2.GaussianBlur(cv2.dilate(cv2.Canny(g, 50, 150), np.ones((3, 3), np.uint8)), (7, 7), 0)
    return float(structural_similarity(edges(a), edges(b), data_range=255))


def _side_by_side(src_frames, got_frames, path: Path, sid: str) -> None:
    import cv2
    from PIL import Image, ImageDraw, ImageFont
    font = ImageFont.truetype(r"C:/Windows/Fonts/malgun.ttf", 16)
    tiles = []
    for s, g in zip(src_frames, got_frames):
        a = Image.fromarray(cv2.cvtColor(s, cv2.COLOR_BGR2RGB))
        a.thumbnail((480, 480))
        b = Image.fromarray(cv2.cvtColor(g, cv2.COLOR_BGR2RGB)).resize(a.size)
        tiles.append((a, b))
    tw, th = tiles[0][0].size
    sheet = Image.new("RGB", (tw * 2, (th + 24) * len(tiles)), "white")
    draw = ImageDraw.Draw(sheet)
    for i, ((a, b), frac) in enumerate(zip(tiles, FRACS)):
        y = i * (th + 24)
        draw.text((6, y + 3), f"{sid} 원본 {frac:.0%}", font=font, fill=(30, 30, 30))
        draw.text((tw + 6, y + 3), f"{sid} Flow {frac:.0%}", font=font, fill=(30, 30, 30))
        sheet.paste(a, (0, y + 24))
        sheet.paste(b, (tw, y + 24))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def check(out: Path) -> int:
    import cv2
    from flow_similarity import clip_frames                  # /플로우 와 같은 장면 뽑기
    pkg = out / PKG
    meta = json.loads((pkg / "조각.json").read_text(encoding="utf-8"))
    report, received, bad = {}, [], 0
    for seg in meta["segments"]:
        src = pkg / seg["src"]
        got = next((pkg / "04_받은클립" / f"{seg['id']}{e}" for e in (".mp4", ".mov", ".webm")
                    if (pkg / "04_받은클립" / f"{seg['id']}{e}").exists()), None)
        if got is None:
            print(f"  · {seg['id']} 받은 클립 없음")
            continue
        sf, gf_raw = clip_frames(src, FRACS), clip_frames(got, FRACS)
        if len(sf) != len(FRACS) or len(gf_raw) != len(FRACS):
            report[seg["id"]] = {"flags": ["장면을 못 뽑았다"]}
            bad += 1
            continue
        gf = [cv2.resize(g, (s.shape[1], s.shape[0])) for s, g in zip(sf, gf_raw)]
        follow = [round(edge_structure(s, g), 3) for s, g in zip(sf, gf)]
        baseline = round(edge_structure(sf[0], sf[-1]), 3)     # 같은 영상의 다른 순간 — 「안 따라감」의 기준선
        mean = sum(follow) / len(follow)
        ds, dg = media.seconds(src), media.seconds(got)
        flags = []
        if abs(ds - dg) > 0.5:
            flags.append(f"길이 {dg:.1f}초 ≠ 원본 {ds:.1f}초")
        if abs(sf[0].shape[1] / sf[0].shape[0] - gf_raw[0].shape[1] / gf_raw[0].shape[0]) > 0.03:
            flags.append("화면비가 다르다")
        if mean <= baseline:
            flags.append(f"움직임·구도가 원본을 안 따른다(닮음 {mean:.2f} ≤ 같은 영상 다른 순간 {baseline:.2f})")
        _side_by_side(sf, gf, pkg / "05_대조" / f"{seg['id']}.png", seg["id"])
        report[seg["id"]] = {"닮음": follow, "기준선": baseline, "원본초": round(ds, 2), "받은초": round(dg, 2),
                             "flags": flags}
        bad += bool(flags)
        received.append(got)
        print(f"  {'❌' if flags else '✅'} {seg['id']} 닮음 {follow} · 기준선 {baseline}" + (f" ← {flags}" if flags else ""))
    if received and len(received) == len(meta["segments"]):
        issues = media.join(received, out / "화풍_완성.mp4", tuple(meta["size"]), meta["fps"])
        report["잇기"] = issues
        print("  " + ("❌ " + "; ".join(issues) if issues else f"🎬 화풍_완성.mp4 ({media.seconds(out / '화풍_완성.mp4'):.1f}초)"))
    (pkg / "_검사.json").write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
    print("→ 숫자는 보조다. `05_대조` 그림을 눈으로 본다 · 첫 실측 뒤 기준을 보정한다")
    return 1 if bad else 0
