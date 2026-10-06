# 설치 안내

SRT 자막을 화이트보드 손그림 애니메이션(MP4)으로 만들어 주는 Claude Code 스킬(한국어 버전)입니다.

## 요구 사항

- Claude Code (CLI 또는 데스크톱 앱)
- Python 3.10 이상 (`python --version`으로 확인)
- 인터넷 연결 (최초 1회, 의존성 설치용 — opencv-python, numpy, av, Pillow)

## 방법 1: git clone (권장)

```bash
git clone https://github.com/mintorain/srt-whiteboard-animation-v2.git ~/.claude/skills/srt-whiteboard-animation
python ~/.claude/skills/srt-whiteboard-animation/scripts/prepare_env.py
```

Windows PowerShell:

```powershell
git clone https://github.com/mintorain/srt-whiteboard-animation-v2.git "$HOME\.claude\skills\srt-whiteboard-animation"
python "$HOME\.claude\skills\srt-whiteboard-animation\scripts\prepare_env.py"
```

## 방법 2: ZIP 다운로드 + 설치 스크립트

GitHub에서 "Code → Download ZIP"으로 받아 압축을 푼 뒤, 푼 폴더에서:

**Windows:**
```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

**macOS / Linux:**
```bash
bash install.sh
```

이미 설치돼 있으면 중단합니다. 덮어쓰려면 `-Force`(Windows) 또는 `--force`(macOS/Linux)를 붙이세요.

## 설치 확인

```bash
python ~/.claude/skills/srt-whiteboard-animation/scripts/prepare_env.py --check
```

마지막 줄에 `ENV_PY=<경로>`가 나오면 정상입니다. 이후 Claude Code를 재시작하면 스킬이 자동 인식됩니다.

## 사용법

Claude Code에서 SRT 파일을 제공하며 이렇게 요청하세요:

> 이 자막으로 화이트보드 애니메이션 만들어줘

스킬이 자동 트리거되어 분장 제시 → 선화 생성 → 영역 주석 → 브라우저 미리보기 조정 → MP4 렌더링 순서로, 각 단계마다 확인을 받으며 진행합니다.

## 참고

- H.264 인코딩은 PyAV로 처리하므로 시스템 ffmpeg 설치가 필요 없습니다.
- 영역 검사 이미지의 한글 라벨은 Windows(맑은 고딕)·macOS(Apple SD Gothic)·Linux(나눔고딕/Noto CJK) 시스템 폰트를 자동 탐색합니다. Linux에서 한글이 깨지면 `fonts-nanum` 또는 `fonts-noto-cjk` 패키지를 설치하세요.
- 미리보기 편집대의 저장 기능(원본 파일에 직접 기록)은 Chrome/Edge가 필요합니다.
