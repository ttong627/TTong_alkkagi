# srt-whiteboard-animation-ko 설치 스크립트 — Windows PowerShell
# 사용법: 저장소(또는 압축 해제) 폴더에서  powershell -ExecutionPolicy Bypass -File .\install.ps1
param([switch]$Force)

$ErrorActionPreference = "Stop"
$src = $PSScriptRoot
$destRoot = Join-Path $HOME ".claude\skills"
$dest = Join-Path $destRoot "srt-whiteboard-animation"

if (-not (Test-Path (Join-Path $src "SKILL.md"))) {
    Write-Error "SKILL.md를 찾을 수 없습니다. 저장소 루트에서 실행하세요."; exit 1
}

$srcNorm = (Resolve-Path $src).Path.TrimEnd('\')
$destNorm = if (Test-Path $dest) { (Resolve-Path $dest).Path.TrimEnd('\') } else { $dest.TrimEnd('\') }

if ($srcNorm -ieq $destNorm) {
    Write-Host "[ok] 이미 스킬 디렉터리 안에 있습니다. 환경 준비만 진행합니다."
    $dest = $src
} else {
    if (Test-Path $dest) {
        if (-not $Force) {
            Write-Host "[!] 이미 설치되어 있습니다: $dest"
            Write-Host "    덮어쓰려면:  powershell -ExecutionPolicy Bypass -File .\install.ps1 -Force"
            exit 1
        }
        Write-Host "[..] 기존 설치 제거 중 (가상환경 포함)"
        Remove-Item -Recurse -Force $dest
    }
    New-Item -ItemType Directory -Force $destRoot | Out-Null
    Write-Host "[..] 스킬 복사 중: $dest"
    New-Item -ItemType Directory -Force $dest | Out-Null
    Get-ChildItem $src -Force | Where-Object { $_.Name -notin @(".git", ".venv", "__pycache__") } |
        Copy-Item -Destination $dest -Recurse -Force
}

Write-Host "[..] Python 가상환경 준비 중 (몇 분 걸릴 수 있습니다)"
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) {
    Write-Host "[!] Python을 찾을 수 없습니다. Python 3.10+ 설치 후 아래를 직접 실행하세요:"
    Write-Host "    python `"$dest\scripts\prepare_env.py`""
    exit 0
}
& $python.Source (Join-Path $dest "scripts\prepare_env.py")
if ($LASTEXITCODE -ne 0) {
    Write-Host "[!] 가상환경 준비 실패. 나중에 다시 실행하세요:  python `"$dest\scripts\prepare_env.py`""
    exit 1
}

Write-Host ""
Write-Host "[ok] 설치 완료! Claude Code를 재시작하면 스킬이 자동 인식됩니다."
Write-Host "     사용: SRT 파일과 함께 '자막으로 화이트보드 애니메이션 만들어줘' 라고 요청하세요."
