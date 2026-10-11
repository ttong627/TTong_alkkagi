#!/usr/bin/env python3
"""재미나이 앱에서 받은 곡(mp4·mp3·wav)을 게임 배경음악(OGG · 이음매 없는 반복)으로 만든다.

  python tool/audio/loop_music.py <받은 파일> <이름>      # → assets/sounds/<이름>.ogg

재미나이 곡은 시작·끝(페이드)이 있는 한 곡이라 그대로 되풀이하면 끊긴다. 그래서
① 곡 안에서 「여기서 저기로 넘어가도 같은 소리」인 두 자리(앞 2~14초 · 뒤 마지막 1~20초 사이)를
   소리 모양(대역별 세기)·크기가 가장 비슷한 곳으로 찾고(3초 창), 표본 단위로 맞춘 뒤
② 그 사이만 잘라 끝 0.25초를 시작 직전 소리와 겹쳐(같은 힘 교차) 이어 붙인다.
③ 음량은 다른 곡과 같게 −18 LUFS, 꼭대기 −1 dBFS 아래.
끝에 이음매 차이·길이·음량을 찍는다(귀로 듣기 전 숫자 확인).
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

import numpy as np

SR = 44100
APP = Path(__file__).resolve().parents[2]
OUT = APP / "assets" / "sounds"
TARGET = -18.0
XF = 0.25


def decode(path: str) -> np.ndarray:
    p = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-vn", "-ac", "2", "-ar", str(SR), "-f", "f32le", "pipe:1"],
        capture_output=True, check=True,
    )
    return np.frombuffer(p.stdout, np.float32).reshape(-1, 2).astype(np.float64)


def features(x: np.ndarray, hop: int = 1024, n: int = 2048) -> tuple[np.ndarray, np.ndarray]:
    mono = x.mean(1)
    frames = (len(mono) - n) // hop
    win = np.hanning(n)
    edges = np.geomspace(60, 16000, 25)
    f = np.fft.rfftfreq(n, 1 / SR)
    idx = [(f >= a) & (f < b) for a, b in zip(edges[:-1], edges[1:])]
    feat = np.zeros((frames, len(idx)))
    rms = np.zeros(frames)
    for k in range(frames):
        seg = mono[k * hop : k * hop + n]
        X = np.abs(np.fft.rfft(seg * win)) ** 2
        feat[k] = [np.log10(X[m].sum() + 1e-12) for m in idx]
        rms[k] = np.sqrt(np.mean(seg ** 2)) + 1e-9
    return feat, rms


def beat_frames(feat: np.ndarray, fr: float) -> float:
    """박 길이(프레임): 소리 변화(스펙트럼 증가분)의 자기상관이 가장 큰 60~180 BPM."""
    flux = np.maximum(0, np.diff(feat, axis=0)).sum(1)
    flux = flux - flux.mean()
    ac = np.correlate(flux, flux, "full")[len(flux) - 1 :]
    lo, hi = int(fr * 60 / 180), int(fr * 60 / 60)
    lag = lo + int(np.argmax(ac[lo:hi]))
    # 이웃 표본으로 소수점까지(포물선).
    a, b, c = ac[lag - 1], ac[lag], ac[lag + 1]
    d = 0.5 * (a - c) / (a - 2 * b + c) if (a - 2 * b + c) != 0 else 0
    return lag + d


def find_loop(x: np.ndarray) -> tuple[int, int, float]:
    hop = 1024
    feat, rms = features(x, hop)
    fr = SR / hop
    beat = beat_frames(feat, fr)
    bar = beat * 4
    print(f"  빠르기 약 {60 * fr / beat:.0f} BPM · 마디 {bar / fr:.2f}초")
    w = int(3 * fr)
    n = len(feat)
    starts = range(int(2 * fr), min(int(14 * fr), n - w))
    ends = range(max(int(n - 20 * fr), int(20 * fr)), n - w - int(1 * fr))
    fz = feat - feat.mean(1, keepdims=True)
    fz /= np.linalg.norm(fz, axis=1, keepdims=True) + 1e-9
    best = (-9.0, 0, 0)
    for i in starts:
        a = fz[i : i + w]
        ra = rms[i : i + w].mean()
        # 반복 길이 = 마디의 정수배(박이 끊기지 않게).
        js = sorted({
            int(round(i + k * bar)) + d
            for k in range(1, int(n / bar) + 1)
            for d in (-1, 0, 1)
        })
        for j in js:
            if j not in ends or j - i < 20 * fr:
                continue
            sim = float((a * fz[j : j + w]).sum(1).mean())
            loud = min(ra, rms[j : j + w].mean()) / max(ra, rms[j : j + w].mean())
            score = sim * loud
            if score > best[0]:
                best = (score, i, j)
    score, i, j = best
    si, sj = i * hop, j * hop
    # 표본 단위로 맞추기: j 둘레 ±20ms 에서 i 와 가장 닮은 자리.
    k = int(0.05 * SR)
    ref = x[si : si + k, 0]
    lag = int(0.02 * SR)
    cands = range(sj - lag, sj + lag)
    corr = [float(np.dot(ref, x[c : c + k, 0])) for c in cands]
    sj = cands[int(np.argmax(corr))]
    return si, sj, score


def make_loop(x: np.ndarray, si: int, sj: int) -> np.ndarray:
    c = int(XF * SR)
    y = x[si:sj].copy()
    t = np.linspace(0, np.pi / 2, c)[:, None]
    # 끝 c 표본: 원래 소리는 줄고, 시작(si) 직전 c 표본이 커진다 → 끝이 곧 si 로 이어진다.
    y[-c:] = y[-c:] * np.cos(t) + x[si - c : si] * np.sin(t)
    return y


def lufs(path: Path) -> tuple[float, float]:
    p = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", "ebur128=peak=true", "-f", "null", "-"],
                       capture_output=True, text=True)
    s = p.stderr[p.stderr.rfind("Summary:"):]
    i = re.search(r"I:\s+(-?[\d.]+)", s)
    pk = re.search(r"Peak:\s+(-?[\d.]+)", s)
    return float(i.group(1)), float(pk.group(1))


def encode(y: np.ndarray, out: Path) -> None:
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "pipe:0",
         "-map_metadata", "-1", "-c:a", "libvorbis", "-q:a", "4", str(out)],
        input=y.astype(np.float32).tobytes(), check=True,
    )


def main(src: str, name: str) -> None:
    x = decode(src)
    si, sj, score = find_loop(x)
    y = make_loop(x, si, sj)
    tmp = OUT / f"{name}.tmp.ogg"
    encode(y, tmp)
    li, _ = lufs(tmp)
    y = y * 10 ** ((TARGET - li) / 20)
    peak = np.max(np.abs(y))
    ceiling = 10 ** (-1 / 20)
    if peak > ceiling:
        y = np.tanh(y / ceiling * 0.98) * ceiling  # 드문 꼭대기만 부드럽게 누른다
    out = OUT / f"{name}.ogg"
    encode(y, out)
    tmp.unlink(missing_ok=True)
    li, pk = lufs(out)
    jump = float(np.max(np.abs(y[-1] - y[0])))
    step = float(np.percentile(np.abs(np.diff(y, axis=0)).max(1), 99))
    print(f"{name}: 원곡 {len(x) / SR:.1f}초 → 반복 {si / SR:.2f}~{sj / SR:.2f}초 ({len(y) / SR:.1f}초 · 닮음 {score:.3f}) · "
          f"{li:.1f} LUFS · 꼭대기 {pk:.1f} dBFS · 이음매 차 {jump:.4f} (곡 안 99% {step:.4f})")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
