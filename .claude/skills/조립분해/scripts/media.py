# -*- coding: utf-8 -*-
"""영상 도구 한 곳 — ffmpeg 찾기 · 길이 재기 · 장면→영상 · 자르기 · 잇기.

ffmpeg 는 기존 파이썬(Python311)의 imageio_ffmpeg 안에 있는 것을 쓴다(PATH 에 없다).
★ffmpeg 는 실패해도 파일을 남기거나 종료코드 0 일 수 있다 → 결과 파일과 길이를 **다시 잰다**.
"""
from __future__ import annotations

import re
import subprocess
from pathlib import Path


def ffmpeg() -> str:
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def _run(args: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run([ffmpeg(), "-y", "-loglevel", "error", *args], capture_output=True, text=True,
                          encoding="utf-8", errors="replace")


def seconds(video: Path) -> float:
    info = subprocess.run([ffmpeg(), "-i", str(video), "-hide_banner"], capture_output=True, text=True,
                          encoding="utf-8", errors="ignore").stderr
    m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", info)
    return int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3)) if m else 0.0


def encode(frames: Path, mp4: Path, fps: int) -> list[str]:
    """0001.png … → H.264 영상(소리 없음 — 소리는 편집 단계에서 붙인다)."""
    r = _run(["-framerate", str(fps), "-i", str(frames / "%04d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p",
              "-crf", "17", "-preset", "slow", "-movflags", "+faststart", str(mp4)])
    if r.returncode != 0 or not mp4.exists() or seconds(mp4) <= 0:
        return [f"영상 만들기 실패 {mp4.name} — {r.stderr.strip()[-300:]}"]
    return []


def cut(src: Path, start: float, end: float, dst: Path) -> list[str]:
    """정확히 자르려고 다시 인코딩한다(-c copy 는 키프레임에서만 잘린다)."""
    dst.parent.mkdir(parents=True, exist_ok=True)
    r = _run(["-ss", f"{start:.3f}", "-i", str(src), "-t", f"{end - start:.3f}", "-c:v", "libx264",
              "-pix_fmt", "yuv420p", "-crf", "16", "-an", str(dst)])
    if r.returncode != 0 or not dst.exists() or abs(seconds(dst) - (end - start)) > 0.15:
        return [f"자르기 실패 {dst.name} — 길이 {seconds(dst) if dst.exists() else 0:.2f}초 · {r.stderr.strip()[-200:]}"]
    return []


def join(clips: list[Path], dst: Path, size: tuple[int, int], fps: int) -> list[str]:
    """받은 조각들을 원본 크기·프레임으로 맞춰 하나로 잇는다."""
    w, h = size
    chains = "".join(f"[{i}:v]scale={w}:{h},setsar=1,fps={fps}[v{i}];" for i in range(len(clips)))
    concat = "".join(f"[v{i}]" for i in range(len(clips))) + f"concat=n={len(clips)}:v=1:a=0[v]"
    args = [x for c in clips for x in ("-i", str(c))]
    r = _run([*args, "-filter_complex", chains + concat, "-map", "[v]", "-c:v", "libx264", "-pix_fmt", "yuv420p",
              "-crf", "17", str(dst)])
    if r.returncode != 0 or not dst.exists() or seconds(dst) <= 0:
        return [f"잇기 실패 — {r.stderr.strip()[-300:]}"]
    return []
