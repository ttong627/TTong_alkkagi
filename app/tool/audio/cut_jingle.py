#!/usr/bin/env python3
"""재미나이 앱에서 받은 곡(mp4)의 앞부분을 짧은 곡(승리·패배·보상 …)으로 자른다.

  python tool/audio/cut_jingle.py <받은 파일> <이름> <초>      # → assets/sounds/<이름>.ogg

① 첫 소리가 나는 자리(앞 무음 건너뜀)부터 <초> 만큼 ② 끝 0.6초를 부드럽게 줄이고(곡이 뚝 끊기지 않게)
③ 다른 짧은 곡과 같게 −16 LUFS · 꼭대기 −1 dBFS 아래 · OGG q4. 읽기·음량·저장은 loop_music.py 것을 쓴다.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from loop_music import OUT, SR, decode, encode, lufs  # noqa: E402

TARGET = -16.0
FADE = 0.6


def main(src: str, name: str, secs: float) -> None:
    x = decode(src)
    env = np.abs(x).max(1)
    start = int(np.argmax(env > 0.02))
    y = x[start : start + int(secs * SR)].copy()
    f = int(FADE * SR)
    y[-f:] *= np.cos(np.linspace(0, np.pi / 2, f))[:, None] ** 2
    y[: int(0.005 * SR)] *= np.linspace(0, 1, int(0.005 * SR))[:, None]
    tmp = OUT / f"{name}.tmp.ogg"
    encode(y, tmp)
    li, _ = lufs(tmp)
    y = y * 10 ** ((TARGET - li) / 20)
    ceiling = 10 ** (-1 / 20)
    if np.max(np.abs(y)) > ceiling:
        y = np.tanh(y / ceiling * 0.98) * ceiling
    out = OUT / f"{name}.ogg"
    encode(y, out)
    tmp.unlink(missing_ok=True)
    li, pk = lufs(out)
    print(f"{name}: 원곡 {len(x) / SR:.1f}초 · {start / SR:.2f}초부터 {len(y) / SR:.1f}초 · {li:.1f} LUFS · 꼭대기 {pk:.1f} dBFS")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2], float(sys.argv[3]))
