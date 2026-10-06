# -*- coding: utf-8 -*-
"""MP4 → README/미리보기용 GIF 변환 (다운스케일 + 저프레임 + 팔레트 축소).

사용법:
  <ENV_PY> scripts/mp4_to_gif.py <입력.mp4> <출력.gif> [--width 640] [--fps 8]
"""
import argparse
import sys

import cv2
from PIL import Image


def main() -> None:
    ap = argparse.ArgumentParser(description="MP4를 가벼운 GIF로 변환")
    ap.add_argument("src", help="입력 MP4 경로")
    ap.add_argument("dst", help="출력 GIF 경로")
    ap.add_argument("--width", type=int, default=640, help="출력 가로 픽셀 (기본 640)")
    ap.add_argument("--fps", type=int, default=8, help="출력 프레임률 (기본 8)")
    ap.add_argument("--colors", type=int, default=96, help="팔레트 색 수 (기본 96)")
    args = ap.parse_args()

    cap = cv2.VideoCapture(args.src)
    src_fps = cap.get(cv2.CAP_PROP_FPS) or 30
    step = max(1, round(src_fps / args.fps))
    frames = []
    i = 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        if i % step == 0:
            h, w = frame.shape[:2]
            nh = int(h * args.width / w)
            frame = cv2.resize(frame, (args.width, nh), interpolation=cv2.INTER_AREA)
            frames.append(Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)))
        i += 1
    cap.release()

    if not frames:
        print("[err] 프레임을 읽지 못했습니다. 입력 MP4를 확인하세요.", file=sys.stderr)
        sys.exit(1)

    frames = [f.quantize(colors=args.colors, method=Image.MEDIANCUT) for f in frames]
    duration = int(1000 * step / src_fps)
    frames[0].save(args.dst, save_all=True, append_images=frames[1:],
                   duration=duration, loop=0, optimize=True)
    print(f"[ok] GIF 저장: {args.dst} ({len(frames)}프레임, {duration}ms/프레임)")
    print(f"OUTPUT={args.dst}")


if __name__ == "__main__":
    main()
