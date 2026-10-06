# -*- coding: utf-8 -*-
"""셜록 전용 Gemini 호출 — gemini-3.8-flash 고정 (형 지시 2026-09-13 「셜록 버전을 3.8 플래시로」).

왜 CLI 가 아니라 API 직접 호출인가:
  @google/gemini-cli 0.58.0 · 0.59.0 · 0.60.0-preview · 0.61.0-nightly 모두 모델 목록에 gemini-3.8-flash 가 없고
  resolveModel() 이 모르는 flash 이름을 gemini-3.5-flash 로 바꿔 부른다(`-m gemini-3.8-flash` 를 줘도
  `gemini -o json` stats.models = gemini-3.5-flash, 2026-09-13 실측). API 로 직접 부르면 modelVersion 이 3.8 로 온다.

위치: ~/.claude/agents/sherlock_ask.py — claude-config 저장소로 PC 간 동기화된다(셜록 정의 sherlock.md 옆).

쓰는 법:
  python C:/Users/ttong/.claude/agents/sherlock_ask.py --prompt-file 물음.txt [--context 파일 ...]
  echo "물음" | python C:/Users/ttong/.claude/agents/sherlock_ask.py [--context 파일 ...]

출력: 답은 stdout(UTF-8), 사용 모델·키 번호·토큰 수는 stderr. 키 값은 절대 출력하지 않는다.
종료코드: 0 성공 · 2 입력 오류 · 3 다른 모델이 답함(받지 않음) · 4 키·네트워크 실패 · 5 빈 답·차단
"""
import argparse
import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

MODEL = "gemini-3.8-flash"
# 판번호 변형(-001)·미리보기(-preview…)만 같은 모델로 본다 — flash-lite 같은 다른 모델은 받지 않는다(제시 2026-09-13)
SERVED_MODEL_RE = re.compile(r"gemini-3\.8-flash(-\d{3}|-preview[\w-]*)?")
ENV_FILE = Path(r"D:\Gemma4\.env")
URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
TIMEOUT_S = 300
MAX_CHARS = 1_500_000  # 입력 상한 — 넘으면 잘라 보내지 않고 멈춘다(조용히 빠진 맥락으로 판정하지 않게)
NETWORK_FAILURE = 0    # 시간초과·연결 실패 — 키 문제가 아니므로 다른 키로 같은 입력을 다시 보내지 않는다(대기·과금 반복 방지)
RETRY_NEXT_KEY_STATUS = {403, 429, 500, 502, 503, 504}
RETRY_NEXT_KEY_REASONS = {"API_KEY_INVALID", "API_KEY_EXPIRED"}  # 키 무효·만료는 403 이 아니라 400 으로 온다


def load_keys() -> list[str]:
    try:
        lines = ENV_FILE.read_text(encoding="utf-8").splitlines()
    except OSError as e:
        raise SystemExit(f"[셜록] 키 파일을 못 읽음: {type(e).__name__}")
    keys = [ln.split("=", 1)[1].strip().strip('"').strip("'")
            for ln in lines if ln.startswith("GEMINI_API_KEY_") and "=" in ln]
    return [k for k in keys if k]


def read_stdin() -> str:
    # 파이프 입력은 Windows 에서 cp949 로 읽혀 한글이 깨진다 → 바이트로 받아 UTF-8 우선 해석
    raw = sys.stdin.buffer.read()
    try:
        return raw.decode("utf-8-sig")  # BOM 이 붙어 오면 첫 글자에 U+FEFF 가 남는다
    except UnicodeDecodeError:
        return raw.decode("cp949", errors="replace")


def build_prompt(args: argparse.Namespace) -> str:
    question = Path(args.prompt_file).read_text(encoding="utf-8-sig") if args.prompt_file else read_stdin()
    parts = [question.strip()]
    for path in args.context or []:
        p = Path(path)
        parts.append(f"\n\n===== 파일: {p} =====\n{p.read_text(encoding='utf-8-sig', errors='replace')}")
    return "".join(parts)


def call(key: str, prompt: str) -> tuple[int, dict]:
    body = json.dumps({"contents": [{"role": "user", "parts": [{"text": prompt}]}]}).encode("utf-8")
    req = urllib.request.Request(URL, data=body, method="POST",
                                 headers={"Content-Type": "application/json", "x-goog-api-key": key})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_S) as res:
            return res.status, json.loads(res.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode("utf-8"))
        except (ValueError, OSError):
            return e.code, {}
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        return NETWORK_FAILURE, {"error": {"status": "NETWORK", "message": type(e).__name__}}


def should_try_next_key(status: int, data: dict) -> bool:
    if status in RETRY_NEXT_KEY_STATUS:
        return True
    if status == 400:
        details = (data.get("error") or {}).get("details") or []
        return any(isinstance(d, dict) and d.get("reason") in RETRY_NEXT_KEY_REASONS for d in details)
    return False


def report_success(data: dict, idx: int) -> int:
    served = str(data.get("modelVersion") or "")
    if not SERVED_MODEL_RE.fullmatch(served):
        print(f"[셜록] ⛔다른 모델이 답함: {served or '(표시 없음)'} — 받지 않음", file=sys.stderr)
        return 3
    cands = data.get("candidates") or []
    first = cands[0] if cands else {}
    text = "".join(p.get("text", "") for p in (first.get("content") or {}).get("parts", []))
    finish = first.get("finishReason") or ""
    if not text.strip():
        block = (data.get("promptFeedback") or {}).get("blockReason") or "-"
        print(f"[셜록] ⛔빈 답 — candidates={len(cands)} · blockReason={block} · finishReason={finish or '-'}", file=sys.stderr)
        return 5
    usage = data.get("usageMetadata") or {}
    print(text)
    if finish and finish != "STOP":
        print(f"[셜록] ⚠️답이 끝까지 오지 않았을 수 있음 — finishReason={finish}", file=sys.stderr)
    print(f"[셜록] model={served} · key#{idx} · 입력 {usage.get('promptTokenCount', '?')} / "
          f"출력 {usage.get('candidatesTokenCount', '?')} / 합계 {usage.get('totalTokenCount', '?')} 토큰",
          file=sys.stderr)
    return 0


def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")  # 답에 「—」 같은 글자가 있으면 cp949 출력에서 죽는다
        except (AttributeError, ValueError):
            pass

    # ⛔형 규칙(2026-09-13): 「유료 키 사용은 기본적으로 금지」. GEMINI_API_KEY_* 는 AI Studio 선불 크레딧·결제 한도가 붙은 유료 키다.
    #   구독(AI Ultra) 로그인으로 도는 Antigravity CLI(agy) 경로가 기본이고, 이 스크립트는 형이 그 자리에서 허락했을 때만 돈다.
    import os  # noqa: PLC0415
    if os.environ.get("SHERLOCK_ALLOW_PAID_API_KEY") != "1":
        print("[셜록] ⛔유료 API 키 사용 금지(형 규칙) — 구독 로그인 경로(agy)를 쓴다. "
              "형이 허락한 경우에만 SHERLOCK_ALLOW_PAID_API_KEY=1", file=sys.stderr)
        return 6

    ap = argparse.ArgumentParser(description="셜록 전용 gemini-3.8-flash 호출")
    ap.add_argument("--prompt-file")
    ap.add_argument("--context", nargs="*")
    args = ap.parse_args()

    try:
        prompt = build_prompt(args)
    except OSError as e:
        print(f"[셜록] 입력 파일을 못 읽음: {e.filename} ({type(e).__name__})", file=sys.stderr)
        return 2
    if not prompt.strip():
        print("[셜록] 물음이 비어 있음", file=sys.stderr)
        return 2
    if len(prompt) > MAX_CHARS:
        print(f"[셜록] 입력이 너무 큼({len(prompt):,}자 > {MAX_CHARS:,}) — 맥락을 줄여 다시", file=sys.stderr)
        return 2

    keys = load_keys()
    if not keys:
        print("[셜록] GEMINI_API_KEY_* 가 없음", file=sys.stderr)
        return 4

    for idx, key in enumerate(keys, start=1):
        status, data = call(key, prompt)
        if status == 200:
            return report_success(data, idx)
        err = data.get("error") or {}
        if status == NETWORK_FAILURE:
            print(f"[셜록] 네트워크·시간초과({err.get('message', '')}) — 다른 키로 다시 보내지 않음", file=sys.stderr)
            return 4
        print(f"[셜록] key#{idx} 실패 HTTP {status} {err.get('status', '')}", file=sys.stderr)
        if not should_try_next_key(status, data):
            return 4
    print("[셜록] 모든 키 실패", file=sys.stderr)
    return 4


if __name__ == "__main__":
    sys.exit(main())
