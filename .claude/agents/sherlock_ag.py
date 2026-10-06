# -*- coding: utf-8 -*-
"""셜록 기본 경로 — Antigravity IDE 구독으로 Gemini 3.8 Flash 를 부른다(유료 API 키 없음, 과금 0원).

형 지시(2026-09-13): 「셜록 버전을 3.8 플래시로」 + 「유료 키 사용은 기본적으로 금지」
형 결정(2026-09-13): 셜록 전용 빈 폴더 D:\\sherlock_ws 를 Antigravity IDE 에 열어 두고 그 폴더의 언어서버에만 붙는다.

왜 폴더를 가두나: Cascade 는 대화창이 아니라 파일을 고치고 명령을 실행할 수 있는 에이전트다.
  형 프로젝트 폴더(yyplus·wellshare-logis-web 등)의 언어서버에 붙으면 검증 중에 그 파일을 건드릴 수 있다.
  ⚠️빈 폴더도 완전한 벽은 아니다 — 워크스페이스 밖 접근은 Antigravity 설정(allowAgentAccessNonWorkspaceFiles 등)에
  달렸다(제시 2026-09-13). 그래서 **도구 단계가 보이는 즉시 대화를 취소**한다(exit 8).

쓰는 법:
  python C:/Users/ttong/.claude/agents/sherlock_ag.py --prompt-file 물음.txt [--context 파일 ...] [--level high|medium|low] [--open]
  (--open: sherlock_ws 가 안 열려 있으면 Antigravity IDE 새 창으로 연다)

출력: 답은 stdout(UTF-8). stderr 에 모델 라벨·enum·걸린 초·할당량(remainingFraction)·경고. 연결 토큰은 절대 출력하지 않는다.
종료코드: 0 성공 · 2 입력 오류 · 3 다른 모델이 답함 · 4 서버 없음·모델 목록 없음·대화 못 엶·전달 실패·오류 단계 ·
          5 빈 답·끊긴 답 · 7 시간초과(취소) · 8 도구 단계(취소)

2026-09-13 실측: 「Gemini 3.8 Flash (High)」= MODEL_PLACEHOLDER_M318, 6~8초 답, 단계 USER_INPUT→CONVERSATION_HISTORY→
  PLANNER_RESPONSE→CHECKPOINT. CHECKPOINT 의 modelUsage 는 다른 모델(M50)이 요약 → 답 판정은 PLANNER_RESPONSE 만 본다.
  정상 답 stopReason = STOP_REASON_STOP_PATTERN. 취소된 대화의 답 단계도 DONE 으로 남고 stopReason 만
  STOP_REASON_CLIENT_STREAM_ERROR(제시 실측, 1271자에서 끊김) → stopReason 으로 끊긴 답을 거른다.
  CancelCascadeInvocation {"cascadeId"} → 1~2초 안에 IDLE, 틀린 필드는 HTTP 500(제시 실측).
  프롬프트 크레딧 숫자는 줄지 않는다 — 실제 계량은 모델 설정의 quotaInfo.remainingFraction(High/Medium/Low 공유).
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

WS_ID = "file_d_3A_sherlock_ws"
WS_DIR = Path(r"D:\sherlock_ws")
IDE_CMD = r"C:\Users\ttong\AppData\Local\Programs\Antigravity IDE\bin\antigravity-ide.cmd"
SVC = "exa.language_server_pb.LanguageServerService"
PLANNER = "CORTEX_STEP_TYPE_PLANNER_RESPONSE"
DONE = "CORTEX_STEP_STATUS_DONE"
IDLE = "CASCADE_RUN_STATUS_IDLE"
NORMAL_STOP = "STOP_REASON_STOP_PATTERN"
BENIGN_STEPS = {"CORTEX_STEP_TYPE_USER_INPUT", "CORTEX_STEP_TYPE_CONVERSATION_HISTORY", PLANNER,
                "CORTEX_STEP_TYPE_CHECKPOINT"}
LEVELS = {"high": "High", "medium": "Medium", "low": "Low"}
POLL_S = 1  # 도구 단계를 본 뒤 취소까지 걸리는 최대 시간 — 짧을수록 에이전트가 덜 돈다(제시 2026-09-13)
TIMEOUT_S = 600
MAX_CHARS = 1_000_000
PREAMBLE = ("너는 셜록, 코드·작업 검증자다. ⛔도구를 쓰지 않는다 — 파일을 읽거나 만들거나 고치지 않고, "
            "명령을 실행하지 않고, 웹을 찾지 않는다. 아래 글로 받은 내용만 보고 한국어로 답한다.\n\n")


class NotReady(RuntimeError):
    """sherlock_ws 언어서버를 못 찾음."""


# ── 순수 함수 (sherlock_ag_check.py 가 시험한다) ─────────────────────────────
def parse_candidates(lines: list[str]) -> list[tuple[int, str]]:
    """프로세스 목록 줄(pid\\t명령줄)에서 **sherlock_ws 워크스페이스**의 언어서버만 (pid, 토큰)."""
    out = []
    for ln in lines:
        if "\t" not in ln:
            continue
        pid, cmd = ln.split("\t", 1)
        if not pid.strip().isdigit():
            continue
        ws = re.search(r"--workspace_id\s+(\S+)", cmd)
        tok = re.search(r"--csrf_token\s+(\S+)", cmd)
        if ws and tok and ws.group(1) == WS_ID and "--enable_lsp" in cmd:
            out.append((int(pid), tok.group(1)))
    return out


def _model_configs(status: dict, level: str) -> list[dict]:
    want = f"Gemini 3.8 Flash ({LEVELS[level]})"
    found: list[dict] = []

    def walk(o):
        if isinstance(o, dict):
            if o.get("label") == want:
                found.append(o)
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)

    walk(status)
    return found


def resolve_model(status: dict, level: str) -> str | None:
    """GetUserStatus 의 모델 설정에서 라벨 `Gemini 3.8 Flash (High)` 의 enum. 없거나 둘 이상이면 None."""
    enums = []
    for cfg in _model_configs(status, level):
        m = cfg.get("modelOrAlias")
        if isinstance(m, dict) and m.get("model"):
            enums.append(m["model"])
    return enums[0] if len(set(enums)) == 1 else None


def quota_fraction(status: dict, level: str) -> float | None:
    """그 라벨의 quotaInfo.remainingFraction — 실제 할당량 계량(프롬프트 크레딧 숫자는 줄지 않는다)."""
    for cfg in _model_configs(status, level):
        frac = (cfg.get("quotaInfo") or {}).get("remainingFraction")
        if isinstance(frac, (int, float)):
            return float(frac)
    return None


def tool_steps(steps: list[dict]) -> list[str]:
    return sorted({str(s.get("type", "?")) for s in steps if s.get("type") not in BENIGN_STEPS})


def summarize(steps: list[dict], want_model: str) -> tuple[int, str, list[str]]:
    """궤적 단계 → (종료코드, 답, 알림들)."""
    notes: list[str] = []
    for s in steps:
        em = s.get("errorMessage")
        if em:
            short = ((em.get("error") or {}).get("shortError") or "")[:200] if isinstance(em, dict) else ""
            return 4, "", [f"오류 단계: {short or '(내용 없음)'}"]
    others = tool_steps(steps)
    if others:
        return 8, "", ["⛔에이전트가 도구 단계를 썼다: " + ", ".join(t.replace("CORTEX_STEP_TYPE_", "") for t in others)]
    planners = [s for s in steps if s.get("type") == PLANNER and s.get("status") == DONE]
    if not planners:
        return 5, "", notes + ["답 단계 없음"]
    models = sorted({str((s.get("metadata") or {}).get("generatorModel") or "(표시 없음)") for s in planners})
    if models != [want_model]:
        return 3, "", notes + [f"⛔다른 모델이 답함: {models} (기대 {want_model})"]
    last = planners[-1].get("plannerResponse") or {}
    text = str(last.get("modifiedResponse") or last.get("response") or "").strip()
    if not text:
        return 5, "", notes + [f"빈 답 · stopReason={last.get('stopReason') or '-'}"]
    stop = last.get("stopReason")
    if stop not in (None, "", NORMAL_STOP):
        # 취소·스트림 끊김·길이 초과로 끊긴 반쪽 답을 판정으로 쓰지 않는다(제시 실측: CLIENT_STREAM_ERROR 1271자)
        return 5, "", notes + [f"⛔답이 끊김 · stopReason={stop} · {len(text)}자까지 옴"]
    return 0, text, notes


# ── 연결 ────────────────────────────────────────────────────────────────────
def _powershell(cmd: str) -> str:
    r = subprocess.run(["powershell", "-NoProfile", "-Command", cmd], capture_output=True, text=True,
                       encoding="utf-8", errors="replace", timeout=60)
    return r.stdout or ""


def rpc(base: str, hdr: dict, method: str, body: dict | None = None) -> dict:
    req = urllib.request.Request(f"{base}/{method}", data=json.dumps(body or {}).encode("utf-8"), headers=hdr)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as e:
        return {"_err": f"HTTP {e.code}"}
    except (urllib.error.URLError, TimeoutError, OSError, ValueError) as e:
        return {"_err": type(e).__name__}


def find_server() -> tuple[str, dict]:
    lines = _powershell("Get-CimInstance Win32_Process -Filter \"Name like 'language_server%'\" | "
                        "ForEach-Object { \"$($_.ProcessId)`t$($_.CommandLine)\" }").splitlines()
    for pid, tok in parse_candidates(lines):
        ports = _powershell("Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | "
                            f"Where-Object {{ $_.OwningProcess -eq {pid} }} | ForEach-Object {{ $_.LocalPort }}").split()
        for port in ports:
            if not port.isdigit():
                continue
            base = f"http://127.0.0.1:{port}/{SVC}"
            hdr = {"Content-Type": "application/json", "x-codeium-csrf-token": tok}
            if "_err" not in rpc(base, hdr, "GetLocalUserInfo"):
                return base, hdr
    raise NotReady("Antigravity IDE 에 D:\\sherlock_ws 가 열려 있지 않다(또는 언어서버 준비 전) — --open 으로 열 수 있다")


def open_workspace(wait_s: int = 90) -> None:
    subprocess.Popen(["cmd", "/c", IDE_CMD, str(WS_DIR)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(3)
    deadline = time.monotonic() + wait_s
    while time.monotonic() < deadline:
        try:
            find_server()
            return
        except NotReady:
            time.sleep(3)


def wait_for_answer(base: str, hdr: dict, cid: str, timeout_s: int,
                    sleep=time.sleep, clock=time.monotonic) -> tuple[list[dict], str]:
    """(단계들, 상태) — 상태: done(IDLE+답/오류) · tool(도구 단계를 본 즉시) · timeout.

    ★상태를 **먼저** 읽고 단계를 **나중에** 읽는다 — 단계 먼저면 그 사이에 도구가 돌고 끝난 뒤
      IDLE 만 보고 done 으로 끝낼 수 있다(제시 2026-09-13).
    """
    deadline = clock() + timeout_s
    steps: list[dict] = []
    while clock() < deadline:
        sleep(POLL_S)
        status = rpc(base, hdr, "GetCascadeTrajectory", {"cascadeId": cid}).get("status", "")
        steps = rpc(base, hdr, "GetCascadeTrajectorySteps", {"cascadeId": cid}).get("steps") or []
        if tool_steps(steps):
            return steps, "tool"
        finished = any(s.get("type") == PLANNER and s.get("status") == DONE for s in steps) or \
            any(s.get("errorMessage") for s in steps)
        if status == IDLE and finished:
            return steps, "done"
    return steps, "timeout"


def cancel(base: str, hdr: dict, cid: str) -> bool:
    """대화를 멈춘다 — 시간초과·도구 단계 뒤에 서버에서 계속 돌며 할당량을 쓰지 않게."""
    return "_err" not in rpc(base, hdr, "CancelCascadeInvocation", {"cascadeId": cid})


# ── 입력 ────────────────────────────────────────────────────────────────────
def read_stdin() -> str:
    raw = sys.stdin.buffer.read()
    try:
        return raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        return raw.decode("cp949", errors="replace")


def build_prompt(args: argparse.Namespace) -> str:
    question = Path(args.prompt_file).read_text(encoding="utf-8-sig") if args.prompt_file else read_stdin()
    parts = [question.strip()]
    for path in args.context or []:
        p = Path(path)
        parts.append(f"\n\n===== 파일: {p} =====\n{p.read_text(encoding='utf-8-sig', errors='replace')}")
    return "".join(parts)


def ws_files() -> set[str]:
    try:
        return {str(p.relative_to(WS_DIR)) for p in WS_DIR.rglob("*")}
    except OSError:
        return set()


def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except (AttributeError, ValueError):
            pass

    ap = argparse.ArgumentParser(description="셜록 — Antigravity 구독 Gemini 3.8 Flash")
    ap.add_argument("--prompt-file")
    ap.add_argument("--context", nargs="*")
    ap.add_argument("--level", choices=sorted(LEVELS), default="high")
    ap.add_argument("--open", action="store_true", help="sherlock_ws 가 안 열려 있으면 IDE 새 창으로 연다")
    ap.add_argument("--timeout", type=int, default=TIMEOUT_S)
    args = ap.parse_args()

    try:
        question = build_prompt(args)
    except OSError as e:
        print(f"[셜록] 입력 파일을 못 읽음: {e.filename} ({type(e).__name__})", file=sys.stderr)
        return 2
    if not question.strip():
        print("[셜록] 물음이 비어 있음", file=sys.stderr)
        return 2
    if len(question) > MAX_CHARS:
        print(f"[셜록] 입력이 너무 큼({len(question):,}자 > {MAX_CHARS:,}) — 맥락을 줄여 다시", file=sys.stderr)
        return 2

    try:
        base, hdr = find_server()
    except NotReady as e:
        if not args.open:
            print(f"[셜록] ⛔{e}", file=sys.stderr)
            return 4
        open_workspace()
        try:
            base, hdr = find_server()
        except NotReady as e2:
            print(f"[셜록] ⛔{e2}", file=sys.stderr)
            return 4

    status = rpc(base, hdr, "GetUserStatus")
    model = resolve_model(status, args.level)
    if not model:
        print(f"[셜록] ⛔구독 모델 목록에 「Gemini 3.8 Flash ({LEVELS[args.level]})」가 없거나 둘 이상", file=sys.stderr)
        return 4
    label = f"Gemini 3.8 Flash ({LEVELS[args.level]})"
    quota_before, before_files, started = quota_fraction(status, args.level), ws_files(), time.monotonic()

    cid = rpc(base, hdr, "StartCascade", {"source": "CORTEX_TRAJECTORY_SOURCE_CLI"}).get("cascadeId")
    if not cid:
        print("[셜록] ⛔대화를 못 열었다(StartCascade)", file=sys.stderr)
        return 4
    sent = rpc(base, hdr, "SendUserCascadeMessage", {
        "cascadeId": cid, "items": [{"text": PREAMBLE + question}],
        "cascadeConfig": {"plannerConfig": {"planModel": model, "requestedModel": {"model": model}}}})
    if "_err" in sent:
        print(f"[셜록] ⛔전달 실패 {sent['_err']}", file=sys.stderr)
        return 4

    steps, state = wait_for_answer(base, hdr, cid, args.timeout)
    elapsed = int(time.monotonic() - started)
    notes: list[str] = []
    if state in ("timeout", "tool"):
        stopped = cancel(base, hdr, cid)
        notes.append("대화 취소 완료" if stopped else "⛔대화 취소 실패 — 형에게 알리고 IDE 의 sherlock_ws 창에서 직접 멈출 것")
    if state == "timeout":
        code, text = 7, ""
        notes.insert(0, f"⛔시간초과 {elapsed}초 — 단계 {len(steps)}개")
    else:
        code, text, more = summarize(steps, model)
        notes = more + notes
    new_files = sorted(ws_files() - before_files)
    if new_files:
        notes.append(f"⚠️sherlock_ws 에 새 파일: {new_files[:10]}")
    if code == 0:
        print(text)
    for n in notes:
        print(f"[셜록] {n}", file=sys.stderr)
    quota_after = quota_fraction(rpc(base, hdr, "GetUserStatus"), args.level)
    print(f"[셜록] model={label}/{model} · 워크스페이스 sherlock_ws · {elapsed}초 · "
          f"할당량 remainingFraction {quota_before}→{quota_after}", file=sys.stderr)
    return code


if __name__ == "__main__":
    sys.exit(main())
