# -*- coding: utf-8 -*-
"""렌더링된 MP4에 SRT 자막을 번인(burn-in)한다.

시스템 ffmpeg(libass 포함 빌드)가 필요하다. 자막을 화면에 새겨 넣으므로
어떤 플레이어에서든 항상 자막이 보인다.

사용법:
  <ENV_PY> scripts/burn_subtitles.py <입력.mp4> <자막.srt> <출력.mp4>
  옵션: --font-size 21 --margin 26 --font "Malgun Gothic"
"""
import argparse
import shutil
import subprocess
import sys
from pathlib import Path


def main() -> None:
    ap = argparse.ArgumentParser(description="MP4에 SRT 자막 번인 (ffmpeg 필요)")
    ap.add_argument("video", help="입력 MP4 경로")
    ap.add_argument("srt", help="SRT 자막 경로")
    ap.add_argument("output", help="출력 MP4 경로")
    ap.add_argument("--font", default="Malgun Gothic", help="자막 폰트 이름 (기본: Malgun Gothic)")
    ap.add_argument("--font-size", type=int, default=21, help="자막 크기 (기본 21)")
    ap.add_argument("--margin", type=int, default=26, help="하단 여백 px (기본 26)")
    ap.add_argument("--text-color", default="262320", help="글자색 RRGGBB (기본 진회색)")
    ap.add_argument("--outline-color", default="F5EBD7", help="외곽선색 RRGGBB (기본 종이색)")
    ap.add_argument("--outline", type=float, default=2.5, help="외곽선 두께 (기본 2.5)")
    args = ap.parse_args()

    if shutil.which("ffmpeg") is None:
        print("[err] ffmpeg를 찾을 수 없습니다. https://ffmpeg.org 에서 full 빌드를 설치하세요.", file=sys.stderr)
        sys.exit(1)

    video = Path(args.video).resolve()
    srt = Path(args.srt).resolve()
    output = Path(args.output).resolve()
    for p, name in ((video, "입력 영상"), (srt, "자막")):
        if not p.exists():
            print(f"[err] {name} 파일이 없습니다: {p}", file=sys.stderr)
            sys.exit(1)

    def ass_color(rrggbb: str) -> str:
        """RRGGBB → libass &H00BBGGRR."""
        r, g, b = rrggbb[0:2], rrggbb[2:4], rrggbb[4:6]
        return f"&H00{b}{g}{r}".upper()

    style = (
        f"FontName={args.font},Bold=1,FontSize={args.font_size},"
        f"PrimaryColour={ass_color(args.text_color)},"
        f"OutlineColour={ass_color(args.outline_color)},"
        f"BorderStyle=1,Outline={args.outline},Shadow=0,MarginV={args.margin}"
    )
    # 필터 인자 경로 이스케이프 문제를 피하려고 SRT가 있는 폴더에서 상대 이름으로 실행
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", str(video),
        "-vf", f"subtitles={srt.name}:force_style='{style}'",
        "-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p",
        "-movflags", "+faststart",
        str(output),
    ]
    res = subprocess.run(cmd, cwd=str(srt.parent), capture_output=True, text=True)
    if res.returncode != 0:
        print(f"[err] ffmpeg 실패:\n{res.stderr.strip()[:800]}", file=sys.stderr)
        sys.exit(1)
    size_mb = output.stat().st_size / 1024 / 1024
    print(f"[ok] 자막 번인 완료 ({size_mb:.2f} MB)")
    print(f"OUTPUT={output}")


if __name__ == "__main__":
    main()
