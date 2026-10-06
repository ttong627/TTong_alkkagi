# -*- coding: utf-8 -*-
"""받은 Flow 클립이 기준(배경·첫 프레임·캐릭터)에서 흔들렸는지 **숫자로** 잰다.

받을 것 없이 로컬(OpenCV·scikit-image)로만 돈다. 클립마다 10%·50%·90% 프레임을 뽑아:
  bg     배경 기준 그림과 색 분포 상관(HSV 히스토그램)   장소·조명이 바뀌었나
  first  첫 프레임 그림과 구조 유사도(SSIM)               시작이 기준대로 붙었나
  cast   캐릭터 기준 그림과 특징점 대조(ORB 좋은 짝 비율) 인물이 바뀌었나 — 참고치
  hold   클립 앞(10%)·뒤(90%) 색 분포 상관               클립 중간에 딴 장면으로 갔나

★숫자는 문지기 보조다. 캐릭터 얼굴 동일성은 그림 모델 없이 완벽히 못 잰다 → 낮은 컷을 **눈으로** 본다.

★★실측 보정 (2026-09-15 · 도미 Flow 클립 6개 ↔ 원본 그림, 같은 컷 vs 다른 컷)
  bg    같은 컷 평균 0.56·최소 0.36 / 다른 컷 평균 0.22·최대 0.69  → 큰 이탈만 잡는다 · 기준 0.35
  hold  같은 컷 최소 0.44 (카메라·빛이 움직이는 컷)                → 기준 0.35
  first 같은 컷 평균 0.30 / 다른 컷 최대 0.36 — **겹친다** → 판정에 안 쓰고 참고로만 찍는다
  cast  같은 컷 평균 0.03 / 다른 컷 평균 0.01 — **약하다(손그림 인물은 특징점이 안 잡힌다)** → 참고로만
  ⇒ 인물 동일성을 숫자로 판정하려면 그림 이해 모델(CLIP 등, 가중치 약 600MB 다운로드)이 필요하다 — 형 허락 후

사용:  python flow_similarity.py <flow_story 패키지 폴더>
       (07_받은클립/S01.mp4 … 와 story.json 을 읽는다)
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from skimage.metrics import structural_similarity

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

FRACS = (0.1, 0.5, 0.9)
TH = {"bg": 0.35, "hold": 0.35}   # 실측으로 가르는 것만 판정 — first·cast 는 참고치(위 머리말)


def load_image(path: Path) -> np.ndarray:
    """한글 경로도 되게 PIL 로 연다(cv2.imread 는 한글 경로에서 실패한다)."""
    return cv2.cvtColor(np.asarray(Image.open(path).convert("RGB")), cv2.COLOR_RGB2BGR)


def hist_corr(a: np.ndarray, b: np.ndarray) -> float:
    def h(img):
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        hist = cv2.calcHist([hsv], [0, 1], None, [50, 60], [0, 180, 0, 256])
        return cv2.normalize(hist, hist).flatten()
    return float(cv2.compareHist(h(a), h(b), cv2.HISTCMP_CORREL))


def ssim(a: np.ndarray, b: np.ndarray) -> float:
    g = [cv2.cvtColor(cv2.resize(x, (256, 256)), cv2.COLOR_BGR2GRAY) for x in (a, b)]
    return float(structural_similarity(g[0], g[1], data_range=255))


def orb_ratio(frame: np.ndarray, ref: np.ndarray) -> float:
    """기준 그림 특징점 중 프레임에서 확실히 짝을 찾은 비율(0~1). 특징점이 없으면 0."""
    orb = cv2.ORB_create(nfeatures=1500)
    k1, d1 = orb.detectAndCompute(cv2.cvtColor(ref, cv2.COLOR_BGR2GRAY), None)
    k2, d2 = orb.detectAndCompute(cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY), None)
    if d1 is None or d2 is None or len(k1) < 8 or len(k2) < 2:
        return 0.0
    pairs = cv2.BFMatcher(cv2.NORM_HAMMING).knnMatch(d1, d2, k=2)
    good = [p[0] for p in pairs if len(p) == 2 and p[0].distance < 0.75 * p[1].distance]
    return len(good) / len(k1)


def _ffmpeg() -> str:
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def clip_frames(clip: Path, fracs: tuple[float, ...] = FRACS) -> list[np.ndarray]:
    ff = _ffmpeg()
    info = subprocess.run([ff, "-i", str(clip), "-hide_banner"], capture_output=True, text=True,
                          encoding="utf-8", errors="ignore").stderr
    m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", info)
    total = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3)) if m else 0.0
    frames = []
    with tempfile.TemporaryDirectory() as tmp:
        for i, f in enumerate(fracs):
            png = Path(tmp) / f"f{i}.png"
            subprocess.run([ff, "-y", "-loglevel", "error", "-ss", f"{total * f:.2f}", "-i", str(clip),
                            "-frames:v", "1", str(png)], capture_output=True)
            if png.exists() and png.stat().st_size:
                frames.append(load_image(png))
    return frames


def score(frames: list[np.ndarray], bg: list[Path], first: Path | None,
          cast: dict[str, list[Path]]) -> dict:
    r: dict = {}
    if not frames:
        return {"error": "프레임을 못 뽑았다"}
    if bg:
        refs = [load_image(p) for p in bg]
        r["bg"] = round(float(np.mean([max(hist_corr(f, x) for x in refs) for f in frames])), 3)
    if first:
        r["first"] = round(ssim(frames[0], load_image(first)), 3)
    for name, paths in cast.items():
        refs = [load_image(p) for p in paths]
        r[f"cast:{name}"] = round(max(orb_ratio(f, x) for f in frames for x in refs), 3)
    if len(frames) >= 2:
        r["hold"] = round(hist_corr(frames[0], frames[-1]), 3)
    return r


def flags(r: dict, th: dict = TH) -> list[str]:
    out = []
    for k, v in r.items():
        base = k.split(":")[0]
        if base in th and v < th[base]:
            out.append(f"{k} {v} < {th[base]}")
    return out


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    pkg = Path(sys.argv[1])
    story = json.loads((pkg / "story.json").read_text(encoding="utf-8"))
    cast = {c["id"]: c for c in story["cast"]}
    locs = {loc["id"]: loc for loc in story["locations"]}
    report, bad = {}, 0
    for s in story["shots"]:
        clip = next((pkg / "07_받은클립" / f"{s['id']}{ext}" for ext in (".mp4", ".mov", ".webm")
                     if (pkg / "07_받은클립" / f"{s['id']}{ext}").exists()), None)
        if clip is None:
            print(f"  ·  {s['id']} 클립 없음")
            continue
        r = score(clip_frames(clip),
                  [Path(p) for p in locs[s["location"]]["refs"]] if s.get("location") else [],
                  Path(s["start_frame"]) if s.get("start_frame") else None,
                  {cast[c]["flow_name"]: [Path(p) for p in cast[c]["refs"]] for c in s.get("cast", [])})
        f = flags(r)
        bad += bool(f)
        report[s["id"]] = {**r, "flags": f}
        print(f"  {'❌' if f else '✅'} {s['id']} {r}" + (f"  ← {f}" if f else ""))
    (pkg / "_유사도.json").write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"→ 흔들린 컷 {bad}개 — 숫자는 보조다. 낮은 컷은 눈으로 본다")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
