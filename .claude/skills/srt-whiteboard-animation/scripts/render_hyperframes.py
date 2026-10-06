# -*- coding: utf-8 -*-
"""Phase C — HyperFrames 렌더 어댑터.

compile_hyperframes.py 가 만든 컴포지션 HTML 을 HyperFrames CLI 로
결정론적 MP4 로 렌더링한다. Node.js 22+ 와 인터넷(최초 1회, npx 패키지·
헤드리스 Chrome)이 필요하며, 없으면 기존 Python 렌더러
(render_stream_whiteboard.py) 사용을 안내하고 종료한다.

동작:
  1. node 버전 확인 (22 미만/없음 → 폴백 안내)
  2. 프로젝트 디렉터리 준비 (`npx hyperframes init --example blank`, 캐시 재사용)
  3. HTML 을 프로젝트 index.html 로 복사
  4. `npx hyperframes render` 실행
  5. 산출 MP4 를 출력 경로로 복사

사용법:
  python scripts/render_hyperframes.py <컴포지션.html> <출력.mp4>
         [--project <디렉터리>] [--hyperframes-version 0.8.11]
"""
import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

FALLBACK_MSG = (
    "[안내] HyperFrames 렌더를 사용할 수 없는 환경입니다. 기존 Python 렌더러로 렌더링하세요:\n"
    "  <ENV_PY> scripts/render_stream_whiteboard.py <이미지> <주석> <출력.mp4>"
)


def run(cmd: list[str], cwd: Path | None = None, timeout: int = 1800) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(cwd) if cwd else None, capture_output=True,
                          text=True, encoding="utf-8", errors="replace",
                          timeout=timeout, shell=(sys.platform == "win32"))


def check_node() -> bool:
    try:
        res = run(["node", "--version"], timeout=30)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False
    m = re.match(r"v(\d+)", res.stdout.strip())
    if not m:
        return False
    major = int(m.group(1))
    if major < 22:
        print(f"[err] Node.js 22+ 필요 (현재 {res.stdout.strip()})", file=sys.stderr)
        return False
    return True


def ensure_project(project: Path, version: str) -> bool:
    if (project / "package.json").exists():
        print(f"[ok] 기존 프로젝트 재사용: {project}")
        return True
    project.parent.mkdir(parents=True, exist_ok=True)
    print(f"[..] HyperFrames 프로젝트 생성: {project}")
    res = run(["npx", "-y", f"hyperframes@{version}", "init", project.name, "--example", "blank"],
              cwd=project.parent, timeout=600)
    if not (project / "package.json").exists():
        print(f"[err] init 실패:\n{(res.stderr or res.stdout).strip()[:800]}", file=sys.stderr)
        return False
    return True


def main() -> None:
    ap = argparse.ArgumentParser(description="HyperFrames 컴포지션 HTML → MP4 렌더")
    ap.add_argument("html", help="compile_hyperframes.py 산출 HTML")
    ap.add_argument("output", help="출력 MP4 경로")
    ap.add_argument("--project", default=None,
                    help="HyperFrames 프로젝트 디렉터리 (기본: 임시 폴더에 캐시)")
    ap.add_argument("--hyperframes-version", default="0.8.11",
                    help="사용할 hyperframes 버전 (기본 0.8.11)")
    args = ap.parse_args()

    html = Path(args.html).resolve()
    output = Path(args.output).resolve()
    if not html.exists():
        print(f"[err] HTML 파일이 없습니다: {html}", file=sys.stderr)
        sys.exit(1)

    if not check_node():
        print(FALLBACK_MSG, file=sys.stderr)
        sys.exit(2)

    project = Path(args.project).resolve() if args.project else \
        Path(tempfile.gettempdir()) / "srt-whiteboard-hyperframes-project"
    if not ensure_project(project, args.hyperframes_version):
        print(FALLBACK_MSG, file=sys.stderr)
        sys.exit(2)

    shutil.copyfile(html, project / "index.html")

    print("[..] HyperFrames 렌더 중 (프레임 시킹 캡처 — 수 분 걸릴 수 있습니다)")
    before = {p: p.stat().st_mtime for p in project.rglob("*.mp4")}
    res = run(["npx", "-y", f"hyperframes@{args.hyperframes_version}", "render"],
              cwd=project, timeout=3600)
    if res.returncode != 0:
        print(f"[err] 렌더 실패 (exit {res.returncode}):\n{(res.stderr or res.stdout).strip()[:1200]}",
              file=sys.stderr)
        print(FALLBACK_MSG, file=sys.stderr)
        sys.exit(1)

    candidates = [p for p in project.rglob("*.mp4")
                  if p not in before or p.stat().st_mtime > before[p]]
    if not candidates:
        candidates = list(project.rglob("*.mp4"))
    if not candidates:
        print("[err] 렌더는 성공했지만 산출 MP4 를 찾지 못했습니다. "
              f"프로젝트 폴더를 확인하세요: {project}", file=sys.stderr)
        sys.exit(1)
    newest = max(candidates, key=lambda p: p.stat().st_mtime)
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(newest, output)
    size_mb = output.stat().st_size / 1024 / 1024
    print(f"[ok] HyperFrames 렌더 완료 ({size_mb:.2f} MB, 원본: {newest.name})")
    print(f"OUTPUT={output}")


if __name__ == "__main__":
    main()
