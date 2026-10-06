# -*- coding: utf-8 -*-
"""/조립분해 실행기 — 계획 한 장 → 준비 · 렌더(입체·도면선) · 영상 · 검사 · Flow 화풍 패키지.

  python make.py 준비 <조립계획.json> [--출력 폴더]
  python make.py 렌더 <조립계획.json> [--모드 둘다|입체|도면선] [--초안] [--미리보기 0,5.2,10.2] [--강행] [--출력 폴더]
  python make.py 플로우 <출력폴더> [--화풍 통통그림체3]
  python make.py 플로우검사 <출력폴더>

비유: 제작 진행표. 콘티(plan·camera) → 촬영(blender_scene) → 편집(media) → 시사(검사) → 색보정 외주(Flow).
"""
from __future__ import annotations

import argparse
import json
import math
import os
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:  # noqa: BLE001
    pass

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import camera  # noqa: E402
import media  # noqa: E402
import plan as P  # noqa: E402

BLENDER = Path(os.environ.get("BLENDER_EXE", r"D:\Tools\Blender\blender-5.2.2-windows-x64\blender.exe"))
RAW = {"입체": "입체_장면", "도면선": "도면선_원본"}      # 블렌더가 찍은 장면 폴더
FINAL = {"입체": "입체_장면", "도면선": "도면선"}         # 영상이 되는 장면 폴더
PAPER, INK = (250, 249, 245), (24, 28, 34)
FONT = r"C:/Windows/Fonts/malgun.ttf"


def stem(title: str) -> str:
    return re.sub(r"[^0-9A-Za-z가-힣]+", "_", title).strip("_") or "조립분해"


def show(report: dict) -> int:
    bad = 0
    for name, items in report.items():
        bad += bool(items)
        print(f"  {'❌' if items else '✅'} {name}" + (": " + " / ".join(items) if items else ""))
    return bad


def frame_no(plan: dict, t: float) -> int:
    """시각(초) → 장면 번호(1부터)."""
    return min(len(P.frame_times(plan)) - 1, max(0, int(round(t * plan["fps"])))) + 1


# ── 준비 ───────────────────────────────────────────────────

def prepare(plan_path: Path, out: Path | None = None) -> tuple[dict, dict, Path, dict]:
    plan = P.load(plan_path)
    base = plan_path.parent
    errs = P.validate(plan, base)
    if plan.get("shot") not in camera.PRESETS:
        errs.append(f"shot(연출)은 {list(camera.PRESETS)} 중 하나")
    if errs:
        raise SystemExit("❌ 계획을 고칠 것\n  - " + "\n  - ".join(errs))
    facts = P.fetch_facts(plan, base)
    keys = camera.camera_keys(plan, facts)
    report = {
        "부품 수": P.check_count(plan, facts),
        "되감기(조립 자리로 돌아옴)": P.check_return(plan),
        "부품끼리 파고듦": P.check_collisions(plan, facts),
        "카메라 구간 이음매": camera.check_preset(plan["shot"]),
        "화면 잘림": camera.check_framing(plan, facts, keys),
        "카메라 튐·급한 줌": camera.check_motion(keys, plan["fps"]),
    }
    out = out or Path.home() / "Downloads" / f"조립분해_{stem(plan['title'])}_{datetime.now():%m%d_%H%M}"
    out.mkdir(parents=True, exist_ok=True)
    times = P.frame_times(plan)
    offs = [P.offsets_at(plan, t) for t in times]
    rest = P.union([P.aabb(f) for f in facts["parts"].values()])
    diag = math.dist(rest[0], rest[1])
    scene = {
        "title": plan["title"], "glb": str((base / plan["glb"]).resolve()), "ratio": plan["ratio"],
        "fps": plan["fps"], "frames": len(times), "scale": 1.0 / diag, "diag_mm": diag,
        "floor_mm": rest[0][2], "rest_center_mm": [(rest[0][i] + rest[1][i]) / 2 for i in range(3)],
        "parts": facts["parts"], "offsets": {lab: [o[lab] for o in offs] for lab in facts["parts"]},
        "camera": keys, "timeline": P.timeline(plan), "shot": plan["shot"],
    }
    (out / "_장면키.json").write_text(json.dumps(scene, ensure_ascii=False), encoding="utf-8")
    if plan_path.resolve() != (out / "조립계획.json").resolve():
        shutil.copy2(plan_path, out / "조립계획.json")
    step = (base / plan["step"]).resolve()
    step.with_name(step.name + ".js").write_text(P.viewer_js(plan), encoding="utf-8")
    (out / "검사_준비.json").write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"준비 — 「{plan['title']}」 {P.duration(plan):.1f}초 · {len(times)}장면 · 연출 {plan['shot']} · {plan['ratio']}")
    show(report)
    print(f"  CAD 뷰어 확인용 애니메이션 → {step.name}.js  (cad-viewer 로 열어 돌려 본다)")
    return plan, facts, out, report


# ── 촬영·가공 ──────────────────────────────────────────────

def run_blender(out: Path, mode: str, draft: bool, extra: list[str] | None = None) -> list[str]:
    cmd = [str(BLENDER), "--background", "--factory-startup", "--python", str(HERE / "blender_scene.py"), "--",
           str(out / "_장면키.json"), str(out), mode] + (["초안"] if draft else []) + (extra or [])
    started = time.time()
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=4 * 3600)
    lines = [ln for ln in (r.stdout + "\n" + r.stderr).splitlines() if "[조립분해]" in ln or "Error" in ln]
    print(f"  블렌더 {mode}: {time.time() - started:.0f}초 · 종료코드 {r.returncode}")
    for ln in lines[-5:]:
        print("    ", ln)
    if r.returncode != 0 or not any("렌더 끝" in ln for ln in lines):
        return [f"블렌더 {mode} 렌더 실패(종료코드 {r.returncode}) — " + " | ".join(lines[-3:])]
    return []


def line_frames(src: Path, dst: Path) -> int:
    """법선 매트캡 장면 → 경계 검출 → 종이색 바탕에 먹선. 선 굵기는 해상도에 비례(1920 폭 = 3px)."""
    import cv2
    import numpy as np
    from PIL import Image
    dst.mkdir(parents=True, exist_ok=True)
    count = 0
    for png in sorted(src.glob("*.png")):
        img = np.asarray(Image.open(png).convert("RGB"))
        edges = np.zeros(img.shape[:2], np.uint8)
        for ch in range(3):                                   # 색 채널마다 — 면 방향 차이를 다 잡는다
            edges = np.maximum(edges, cv2.Canny(img[:, :, ch], 30, 90))
        size = max(2, round(max(img.shape[:2]) / 640))
        edges = cv2.dilate(edges, np.ones((size, size), np.uint8))
        paper = np.empty_like(img)
        paper[:] = PAPER
        paper[edges > 0] = INK
        Image.fromarray(paper).save(dst / png.name)
        count += 1
    return count


def blank_check(folder: Path, mode: str) -> list[str]:
    import numpy as np
    from PIL import Image
    files = sorted(folder.glob("*.png"))
    bad = []
    for f in files[:: max(1, len(files) // 6)]:
        a = np.asarray(Image.open(f).convert("L"), dtype=np.float32)
        if mode == "입체" and (a > 60).mean() < 0.01:
            bad.append(f"{f.name} 부품이 거의 안 보인다(너무 어둡다)")
        if mode == "도면선" and (a < 128).mean() < 0.002:
            bad.append(f"{f.name} 선이 거의 없다")
    return bad


def cross_check(out: Path, mode: str, plan: dict, facts: dict, keys: list[dict]) -> tuple[list[str], float]:
    """블렌더가 계산한 화면 위치 ↔ camera.py 투영. 같아야 잘림 검사를 믿는다."""
    path = out / f"_블렌더투영_{mode}.json"
    if not path.exists():
        return [f"블렌더 투영 기록이 없다 — {path.name}"], -1.0
    worst = 0.0
    for row in json.loads(path.read_text(encoding="utf-8")):
        key = keys[row["i"]]
        boxes = P.boxes_at(plan, facts, key["t"])
        for lab, got in row["parts"].items():
            pts = [camera.project(key, pt, plan["ratio"]) for pt in camera._corners(boxes[lab])]
            ours = [min(p[0] for p in pts), max(p[0] for p in pts), min(p[1] for p in pts), max(p[1] for p in pts)]
            worst = max(worst, max(abs(a - b) for a, b in zip(ours, got)))
    return ([] if worst < 0.01 else [f"블렌더 투영과 계산 투영이 {worst:.3f}(화면 비율)만큼 다르다"]), round(worst, 5)


def grid(rows: list[tuple[str, list[tuple[str, Path]]]], ratio: str, dst: Path, cell: int = 320) -> Path:
    """행마다 (이름, [(설명, 그림)]) — 한 장으로 모은다."""
    from PIL import Image, ImageDraw, ImageFont
    cw, ch = (cell, cell * 9 // 16) if ratio == "16:9" else (cell * 9 // 16, cell)
    cols = max(len(cells) for _, cells in rows)
    font = ImageFont.truetype(FONT, 15 if cell <= 320 else 22)
    top = 24 if cell <= 320 else 34
    sheet = Image.new("RGB", (cw * cols, (ch + top) * len(rows)), "white")
    draw = ImageDraw.Draw(sheet)
    for r, (label, cells) in enumerate(rows):
        y = r * (ch + top)
        for c, (caption, path) in enumerate(cells):
            draw.text((c * cw + 6, y + 3), f"{label} · {caption}", font=font, fill=(30, 30, 30))
            if path.exists():
                im = Image.open(path).convert("RGB")
                im.thumbnail((cw, ch))
                sheet.paste(im, (c * cw + (cw - im.width) // 2, y + top))
    sheet.save(dst)
    return dst


def contact_sheet(out: Path, plan: dict, modes: list[str]) -> Path:
    picks = [("처음", 0.0)] + [(P.PHASE_KO[ph], (a + b) / 2) for ph, a, b in P.timeline(plan)] \
        + [("끝", (len(P.frame_times(plan)) - 1) / plan["fps"])]
    rows = [(mode, [(f"{name} {t:.1f}초", out / FINAL[mode] / f"{frame_no(plan, t):04d}.png") for name, t in picks])
            for mode in modes]
    return grid(rows, plan["ratio"], out / "검수격자.png")


# ── 렌더 · 미리보기 ────────────────────────────────────────

def preview(plan_path: Path, modes: list[str], seconds: list[float], draft: bool, out: Path | None) -> int:
    """고른 시각의 장면만 사진으로 — 전체 렌더 전에 조명·색·구도를 본다."""
    plan, _, out, report = prepare(plan_path, out)
    frames = sorted({frame_no(plan, t) for t in seconds})
    issues = []
    for mode in modes:
        issues += run_blender(out, mode, draft, ["장면=" + ",".join(map(str, frames))])
        if mode == "도면선" and not issues:
            line_frames(out / "미리보기" / "도면선_원본", out / "미리보기" / "도면선")
    rows = [(mode, [(f"{(f - 1) / plan['fps']:.1f}초", out / "미리보기" / mode / f"{f:04d}.png") for f in frames])
            for mode in modes]
    sheet = grid(rows, plan["ratio"], out / "미리보기.png", cell=640)
    for e in issues:
        print("  ❌", e)
    print(f"  🖼 미리보기: {sheet}")
    return 1 if issues or any(report.values()) else 0


def render(plan_path: Path, modes: list[str], draft: bool, force: bool, out: Path | None) -> int:
    plan, facts, out, report = prepare(plan_path, out)
    if any(report.values()) and not force:
        print("⛔ 준비 검사에 걸린 것이 있어 렌더하지 않았다 — 계획을 고치거나 --강행")
        return 1
    keys = json.loads((out / "_장면키.json").read_text(encoding="utf-8"))["camera"]
    result, info, done = {}, {}, []
    for mode in modes:
        issues = run_blender(out, mode, draft)
        if not issues and mode == "도면선":
            print(f"  도면선 경계 검출: {line_frames(out / RAW[mode], out / FINAL[mode])}장")
        if not issues:
            folder = out / FINAL[mode]
            got = len(list(folder.glob("*.png")))
            if got != len(keys):
                issues.append(f"장면 수 {got} ≠ 계획 {len(keys)}")
            issues += blank_check(folder, mode)
            mp4 = out / f"{mode}.mp4"
            issues += media.encode(folder, mp4, plan["fps"])
            secs = media.seconds(mp4) if mp4.exists() else 0.0
            if abs(secs - len(keys) / plan["fps"]) > 1.5 / plan["fps"]:
                issues.append(f"영상 길이 {secs:.2f}초 ≠ 계획 {len(keys) / plan['fps']:.2f}초")
            cc, worst = cross_check(out, mode, plan, facts, keys)
            issues += cc
            info[mode] = {"영상": str(mp4), "초": round(secs, 3), "투영차_최대": worst}
            done.append(mode)
        result[f"{mode} 렌더·영상"] = issues
    sheet = contact_sheet(out, plan, done) if done else None
    (out / "검사.json").write_text(json.dumps({"준비": report, "렌더": result, "정보": info}, ensure_ascii=False,
                                            indent=1), encoding="utf-8")
    print("렌더 결과")
    bad = show(result)
    for mode, v in info.items():
        print(f"  🎬 {mode}: {v['영상']} ({v['초']}초 · 블렌더 투영차 {v['투영차_최대']})")
    if sheet:
        print(f"  🖼 검수 격자: {sheet}  ← 눈으로 본다(숫자만으로 끝내지 않는다)")
    return 1 if bad else 0


# ── 명령줄 ─────────────────────────────────────────────────

def main() -> int:
    ap = argparse.ArgumentParser(description="조립분해 — 계획 → 입체·도면선 영상 → Flow 화풍")
    sub = ap.add_subparsers(dest="명령", required=True)
    a = sub.add_parser("준비", help="부품 정보·장면키·검사만")
    a.add_argument("계획")
    a.add_argument("--출력")
    b = sub.add_parser("렌더", help="블렌더 렌더 → 영상 → 검사")
    b.add_argument("계획")
    b.add_argument("--모드", default="둘다", choices=["둘다", "입체", "도면선"])
    b.add_argument("--초안", action="store_true", help="절반 해상도·적은 샘플(빨리 확인)")
    b.add_argument("--미리보기", help="이 시각(초)의 장면만 사진으로 — 예: 0,5.2,10.2")
    b.add_argument("--강행", action="store_true", help="준비 검사에 걸려도 렌더")
    b.add_argument("--출력")
    c = sub.add_parser("플로우", help="입체 영상 → Flow 화풍 편집 패키지")
    c.add_argument("출력폴더")
    c.add_argument("--화풍", default="통통그림체3")
    d = sub.add_parser("플로우검사", help="Flow 에서 받은 클립이 원본 움직임을 따르나")
    d.add_argument("출력폴더")
    args = ap.parse_args()
    if args.명령 == "준비":
        prepare(Path(args.계획).resolve(), Path(args.출력) if args.출력 else None)
        return 0
    if args.명령 == "렌더":
        modes = ["입체", "도면선"] if args.모드 == "둘다" else [args.모드]
        out = Path(args.출력) if args.출력 else None
        if args.미리보기:
            return preview(Path(args.계획).resolve(), modes, [float(x) for x in args.미리보기.split(",")],
                           args.초안, out)
        return render(Path(args.계획).resolve(), modes, args.초안, args.강행, out)
    import flow_pack
    if args.명령 == "플로우":
        return flow_pack.package(Path(args.출력폴더), args.화풍)
    return flow_pack.check(Path(args.출력폴더))


if __name__ == "__main__":
    raise SystemExit(main())
