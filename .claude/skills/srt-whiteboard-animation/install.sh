#!/usr/bin/env bash
# srt-whiteboard-animation-ko 설치 스크립트 — macOS / Linux
# 사용법: 저장소(또는 압축 해제) 폴더에서  bash install.sh   (덮어쓰기: bash install.sh --force)
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude/skills/srt-whiteboard-animation"

[ -f "$SRC/SKILL.md" ] || { echo "[!] SKILL.md를 찾을 수 없습니다. 저장소 루트에서 실행하세요."; exit 1; }

if [ "$SRC" = "$DEST" ]; then
  echo "[ok] 이미 스킬 디렉터리 안에 있습니다. 환경 준비만 진행합니다."
else
  if [ -d "$DEST" ]; then
    if [ "${1:-}" != "--force" ]; then
      echo "[!] 이미 설치되어 있습니다: $DEST"
      echo "    덮어쓰려면:  bash install.sh --force"
      exit 1
    fi
    echo "[..] 기존 설치 제거 중 (가상환경 포함)"
    rm -rf "$DEST"
  fi
  mkdir -p "$HOME/.claude/skills"
  echo "[..] 스킬 복사 중: $DEST"
  mkdir -p "$DEST"
  (cd "$SRC" && tar cf - --exclude=.git --exclude=.venv --exclude='__pycache__' .) | tar xf - -C "$DEST"
fi

echo "[..] Python 가상환경 준비 중 (몇 분 걸릴 수 있습니다)"
PY="$(command -v python3 || command -v python || true)"
if [ -z "$PY" ]; then
  echo "[!] Python을 찾을 수 없습니다. Python 3.10+ 설치 후 아래를 직접 실행하세요:"
  echo "    python3 \"$DEST/scripts/prepare_env.py\""
  exit 0
fi
"$PY" "$DEST/scripts/prepare_env.py" || {
  echo "[!] 가상환경 준비 실패. 나중에 다시 실행하세요:  python3 \"$DEST/scripts/prepare_env.py\""
  exit 1
}

echo ""
echo "[ok] 설치 완료! Claude Code를 재시작하면 스킬이 자동 인식됩니다."
echo "     사용: SRT 파일과 함께 '자막으로 화이트보드 애니메이션 만들어줘' 라고 요청하세요."
