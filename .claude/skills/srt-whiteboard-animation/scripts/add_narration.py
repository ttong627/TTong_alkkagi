# -*- coding: utf-8 -*-
"""SRT 자막을 한국어 TTS 내레이션으로 합성해 영상에 입힌다.

Microsoft Edge 신경망 음성(edge-tts, 무료·네트워크 필요)으로 각 자막을
읽고, 자막 타임코드에 맞춰 오디오 트랙을 만들어 영상에 먹싱한다.
영상 스트림은 재인코딩하지 않는다(-c:v copy). 시스템 ffmpeg 필요.

사용법:
  <ENV_PY> scripts/add_narration.py <영상.mp4> <자막.srt> <출력.mp4>
  옵션: --voice ko-KR-SunHiNeural | ko-KR-InJoonNeural (남성) 등
        --rate +0%  말속도 (예: +10%, -5%)
        --fit       자막 구간보다 긴 클립을 최대 1.35배까지 빠르게 맞춤
"""
import argparse
import asyncio
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

TIME_RE = re.compile(r"(\d{2}):(\d{2}):(\d{2})[,.](\d{3})")


def parse_srt(path: Path) -> list[dict]:
    cues = []
    block: list[str] = []
    for line in path.read_text(encoding="utf-8-sig").splitlines() + [""]:
        if line.strip():
            block.append(line.strip())
            continue
        if len(block) >= 2:
            times = TIME_RE.findall(block[1] if "-->" in block[1] else block[0])
            if len(times) >= 2:
                def ms(t):
                    return (int(t[0]) * 3600 + int(t[1]) * 60 + int(t[2])) * 1000 + int(t[3])
                text_lines = block[2:] if "-->" in block[1] else block[1:]
                text = " ".join(text_lines).strip()
                if text:
                    cues.append({"startMs": ms(times[0]), "endMs": ms(times[1]), "text": text})
        block = []
    return cues


def ffprobe_duration(path: Path) -> float:
    res = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                          "-of", "csv=p=0", str(path)], capture_output=True, text=True)
    try:
        return float(res.stdout.strip())
    except ValueError:
        return 0.0


async def tts_all(cues: list[dict], voice: str, rate: str, tmp: Path) -> list[Path]:
    import edge_tts
    outs = []
    for i, cue in enumerate(cues):
        out = tmp / f"cue{i:03d}.mp3"
        await edge_tts.Communicate(cue["text"], voice, rate=rate).save(str(out))
        outs.append(out)
    return outs


def main() -> None:
    ap = argparse.ArgumentParser(description="SRT 기반 TTS 내레이션을 영상에 합성")
    ap.add_argument("video", help="입력 MP4")
    ap.add_argument("srt", help="자막 SRT (내레이션 대본)")
    ap.add_argument("output", help="출력 MP4")
    ap.add_argument("--voice", default="ko-KR-SunHiNeural",
                    help="edge-tts 음성 (기본 ko-KR-SunHiNeural, 남성: ko-KR-InJoonNeural)")
    ap.add_argument("--rate", default="+0%", help="말속도 (예: +10%%)")
    ap.add_argument("--fit", action="store_true",
                    help="자막 구간보다 긴 클립을 최대 1.35배 빠르게 맞춤")
    ap.add_argument("--gain-db", type=float, default=0.0, help="내레이션 볼륨 보정 dB")
    args = ap.parse_args()

    if shutil.which("ffmpeg") is None:
        print("[err] ffmpeg를 찾을 수 없습니다.", file=sys.stderr)
        sys.exit(1)
    try:
        import edge_tts  # noqa: F401
    except ImportError:
        print("[err] edge-tts 가 없습니다. 설치: <ENV_PY> -m pip install edge-tts", file=sys.stderr)
        sys.exit(1)

    video = Path(args.video).resolve()
    srt = Path(args.srt).resolve()
    output = Path(args.output).resolve()
    cues = parse_srt(srt)
    if not cues:
        print("[err] SRT 에서 자막을 읽지 못했습니다.", file=sys.stderr)
        sys.exit(1)
    print(f"[..] TTS 합성: {len(cues)}개 자막, 음성 {args.voice}")

    with tempfile.TemporaryDirectory(prefix="narration_") as td:
        tmp = Path(td)
        try:
            clips = asyncio.run(tts_all(cues, args.voice, args.rate, tmp))
        except Exception as e:  # 네트워크 실패 등
            print(f"[err] TTS 합성 실패 (네트워크 필요): {e}", file=sys.stderr)
            sys.exit(1)

        # 자막 구간 대비 길이 점검 (+선택적 속도 맞춤)
        for i, (cue, clip) in enumerate(zip(cues, clips)):
            dur = ffprobe_duration(clip)
            limit = (cues[i + 1]["startMs"] if i + 1 < len(cues) else cue["endMs"] + 1500) / 1000 \
                - cue["startMs"] / 1000 - 0.05
            if dur > limit:
                if args.fit:
                    tempo = min(1.35, dur / limit)
                    fitted = tmp / f"fit{i:03d}.mp3"
                    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(clip),
                                    "-filter:a", f"atempo={tempo:.3f}", str(fitted)], check=True)
                    clips[i] = fitted
                    dur = ffprobe_duration(fitted)
                if dur > limit + 0.3:
                    print(f"[warn] 자막 {i + 1} 내레이션({dur:.1f}s)이 구간({limit:.1f}s)보다 깁니다. "
                          "--fit 또는 자막 시간 조정을 권장.")

        # 각 클립을 시작 시각으로 지연 후 믹스, 영상 길이에 패딩
        inputs: list[str] = ["-i", str(video)]
        filters = []
        for i, (cue, clip) in enumerate(zip(cues, clips)):
            inputs += ["-i", str(clip)]
            d = cue["startMs"]
            filters.append(f"[{i + 1}:a]adelay={d}|{d}[a{i}]")
        mix_in = "".join(f"[a{i}]" for i in range(len(clips)))
        gain = f",volume={args.gain_db}dB" if args.gain_db else ""
        filters.append(f"{mix_in}amix=inputs={len(clips)}:normalize=0{gain},apad[aout]")
        cmd = ["ffmpeg", "-y", "-loglevel", "error", *inputs,
               "-filter_complex", ";".join(filters),
               "-map", "0:v", "-map", "[aout]",
               "-c:v", "copy", "-c:a", "aac", "-b:a", "160k",
               "-shortest", str(output)]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            print(f"[err] ffmpeg 먹싱 실패:\n{res.stderr.strip()[:800]}", file=sys.stderr)
            sys.exit(1)

    size_mb = output.stat().st_size / 1024 / 1024
    print(f"[ok] 내레이션 합성 완료 ({size_mb:.2f} MB)")
    print(f"OUTPUT={output}")


if __name__ == "__main__":
    main()
