# 셜록 Antigravity 경로(agents/sherlock_ag.py) 점검 — 실제 IDE·크레딧 없이 흉내 응답으로 시험한다.
# 실행: python C:/Users/ttong/.claude/agents/sherlock_ag_check.py
# ★대상 경로는 PATH 한 곳만 바꾸면 전부 따라간다(되돌리기 시험용 사본은 SHERLOCK_AG_PATH 로 — 제시 2026-09-13).
import importlib.util
import os
import subprocess
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass

PATH = os.environ.get("SHERLOCK_AG_PATH", r"C:\Users\ttong\.claude\agents\sherlock_ag.py")
spec = importlib.util.spec_from_file_location("sag", PATH)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

WANT = "MODEL_PLACEHOLDER_M318"
STATUS = {"userStatus": {"planStatus": {"availablePromptCredits": 500}, "cascadeModelConfigData": {"clientModelConfigs": [
    {"label": "Gemini 3.8 Flash (High)", "modelOrAlias": {"model": "MODEL_PLACEHOLDER_M318"}, "quotaInfo": {"remainingFraction": 0.75}},
    {"label": "Gemini 3.8 Flash (Medium)", "modelOrAlias": {"model": "MODEL_PLACEHOLDER_M319"}},
    {"label": "Gemini 3.8 Flash Lite (High)", "modelOrAlias": {"model": "MODEL_X_LITE"}},
    {"label": "Gemini 3.7 Flash (High)", "modelOrAlias": {"model": "MODEL_PLACEHOLDER_M298"}}]}}}


def planner(text, model=WANT, status="CORTEX_STEP_STATUS_DONE", stop="STOP_REASON_STOP_PATTERN"):
    return {"type": "CORTEX_STEP_TYPE_PLANNER_RESPONSE", "status": status,
            "plannerResponse": {"response": text, "modifiedResponse": text, "stopReason": stop},
            "metadata": {"generatorModel": model}}


BASE = [{"type": "CORTEX_STEP_TYPE_USER_INPUT", "status": "CORTEX_STEP_STATUS_DONE"},
        {"type": "CORTEX_STEP_TYPE_CONVERSATION_HISTORY", "status": "CORTEX_STEP_STATUS_DONE"}]
TOOL = {"type": "CORTEX_STEP_TYPE_RUN_COMMAND", "status": "CORTEX_STEP_STATUS_RUNNING"}
checks = []


def check(name, ok, detail=""):
    checks.append((name, bool(ok), detail))


# 1 워크스페이스 거르기 — 형 프로젝트 폴더·접두어 함정·--enable_lsp 없음은 버린다
lines = [
    "11\t\"ls.exe\" --enable_lsp --csrf_token AAA --workspace_id file_i_3A_ttong_project_yyplus",
    "12\t\"ls.exe\" --enable_lsp --csrf_token BBB --workspace_id file_d_3A_sherlock_ws2",
    "13\t\"ls.exe\" --csrf_token CCC --workspace_id file_d_3A_sherlock_ws",
    "14\t\"ls.exe\" --enable_lsp --csrf_token DDD --workspace_id file_d_3A_sherlock_ws --app_data_dir x",
    "garbage line",
]
got = m.parse_candidates(lines)
check("sherlock_ws 서버만 고름(프로젝트·접두어·lsp 없음 제외)", got == [(14, "DDD")], str([p for p, _ in got]))

# 2 모델 이름으로 enum·할당량 찾기
check("라벨로 3.8 Flash High enum", m.resolve_model(STATUS, "high") == "MODEL_PLACEHOLDER_M318")
check("Medium enum", m.resolve_model(STATUS, "medium") == "MODEL_PLACEHOLDER_M319")
check("목록에 없으면 None(Low)", m.resolve_model(STATUS, "low") is None)
dup = {"a": [{"label": "Gemini 3.8 Flash (High)", "modelOrAlias": {"model": "M1"}},
             {"label": "Gemini 3.8 Flash (High)", "modelOrAlias": {"model": "M2"}}]}
check("같은 라벨이 둘이면 None", m.resolve_model(dup, "high") is None)
check("할당량 remainingFraction 읽기", m.quota_fraction(STATUS, "high") == 0.75 and m.quota_fraction(STATUS, "medium") is None)

# 3 답 판정
code, text, notes = m.summarize(BASE + [planner("정상 답"), {"type": "CORTEX_STEP_TYPE_CHECKPOINT", "status": "CORTEX_STEP_STATUS_DONE", "metadata": {"generatorModel": "MODEL_PLACEHOLDER_M50"}}], WANT)
check("정상 답 → 0 (체크포인트 다른 모델 무시)", code == 0 and text == "정상 답" and not any("⚠️" in n for n in notes), f"{code} {notes}")
code, _, notes = m.summarize(BASE + [planner("x", model="MODEL_PLACEHOLDER_M298")], WANT)
check("다른 모델 → 3", code == 3, f"{code} {notes}")
code, _, notes = m.summarize(BASE + [planner("x", model=None)], WANT)
check("모델 표시 없음 → 3", code == 3, f"{code}")
code, _, notes = m.summarize(BASE + [planner("   ")], WANT)
check("빈 답 → 5", code == 5, f"{code} {notes}")
code, _, notes = m.summarize(BASE, WANT)
check("답 단계 없음 → 5", code == 5, f"{code}")
code, _, notes = m.summarize(BASE + [planner("141 — 백사십", stop="STOP_REASON_CLIENT_STREAM_ERROR")], WANT)
check("끊긴 답(stopReason≠STOP_PATTERN) → 5", code == 5 and any("끊김" in n for n in notes), f"{code} {notes}")
code, _, notes = m.summarize(BASE + [planner("stopReason 없음", stop=None)], WANT)
check("stopReason 표시 없음 → 0(판정 보류 아님)", code == 0, f"{code} {notes}")
code, _, notes = m.summarize(BASE + [{"type": "CORTEX_STEP_TYPE_ERROR_MESSAGE", "errorMessage": {"error": {"shortError": "quota"}}}], WANT)
check("오류 단계 → 4", code == 4 and "quota" in notes[0], f"{code} {notes}")


# 4 기다리기 — 흉내 서버(단계·상태 순서를 준다)
def fake_rpc(step_seq, status_seq, calls):
    it_steps, it_status = iter(step_seq), iter(status_seq)
    last = {"steps": [], "status": ""}

    def rpc(base, hdr, method, body=None):
        calls.append(method)
        if method == "GetCascadeTrajectorySteps":
            last["steps"] = next(it_steps, last["steps"])
            return {"steps": last["steps"]}
        if method == "GetCascadeTrajectory":
            last["status"] = next(it_status, last["status"])
            return {"status": last["status"]}
        return {}
    return rpc


calls = []
m.rpc = fake_rpc([BASE], ["CASCADE_RUN_STATUS_RUNNING"], calls)
clock = iter(range(0, 10_000, 5))
steps, state = m.wait_for_answer("b", {}, "c", 30, sleep=lambda s: None, clock=lambda: next(clock))
check("계속 RUNNING → timeout", state == "timeout", state)

calls = []
done = BASE + [planner("답")]
m.rpc = fake_rpc([done, done, done], ["CASCADE_RUN_STATUS_RUNNING", "CASCADE_RUN_STATUS_RUNNING", "CASCADE_RUN_STATUS_IDLE"], calls)
clock = iter(range(0, 10_000, 1))
steps, state = m.wait_for_answer("b", {}, "c", 100, sleep=lambda s: None, clock=lambda: next(clock))
check("답 DONE 이어도 RUNNING 이면 계속 기다림 → IDLE 에서 done", state == "done" and calls.count("GetCascadeTrajectory") == 3,
      f"{state} polls={calls.count('GetCascadeTrajectory')}")

calls = []
m.rpc = fake_rpc([BASE + [TOOL]], ["CASCADE_RUN_STATUS_RUNNING"], calls)
clock = iter(range(0, 10_000, 1))
steps, state = m.wait_for_answer("b", {}, "c", 100, sleep=lambda s: None, clock=lambda: next(clock))
check("도구 단계가 보이면 즉시 tool", state == "tool" and calls.count("GetCascadeTrajectorySteps") == 1, f"{state}")

# 도구가 상태 읽기와 단계 읽기 사이에 돌고 끝나도 놓치지 않는다 — 상태를 먼저 읽고 단계를 나중에 읽어야 한다(제시 2026-09-13)
order = []
def ordered_rpc(base, hdr, method, body=None):
    order.append(method)
    if method == "GetCascadeTrajectory":
        return {"status": "CASCADE_RUN_STATUS_IDLE"}
    return {"steps": BASE + [planner("답"), {"type": "CORTEX_STEP_TYPE_WRITE_TO_FILE", "status": "CORTEX_STEP_STATUS_DONE"}]}
m.rpc = ordered_rpc
clock = iter(range(0, 10_000, 1))
steps, state = m.wait_for_answer("b", {}, "c", 100, sleep=lambda s: None, clock=lambda: next(clock))
check("상태 먼저·단계 나중 읽기 + 끝난 도구도 tool", order[:2] == ["GetCascadeTrajectory", "GetCascadeTrajectorySteps"] and state == "tool", f"{order[:2]} {state}")
check("확인 간격 1초 이하", m.POLL_S <= 1, str(m.POLL_S))

# 5 메인 흐름(흉내 서버) — 한글 파이프·BOM, PREAMBLE, 새 파일 경고, 도구·시간초과 → 취소(요청 내용까지)·exit 8/7, 취소 실패 표시
DRIVER = r'''
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("sag", sys.argv[2])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
scenario = sys.argv[1]; sent = {}; called = []; cancel_body = {}
STATUS = {"userStatus": {"planStatus": {"availablePromptCredits": 500}, "c": [{"label": "Gemini 3.8 Flash (High)", "modelOrAlias": {"model": "MODEL_PLACEHOLDER_M318"}, "quotaInfo": {"remainingFraction": 0.5}}]}}
def rpc(base, hdr, method, body=None):
    called.append(method)
    if method == "GetUserStatus": return STATUS
    if method == "StartCascade": return {"cascadeId": "cid1"}
    if method == "SendUserCascadeMessage":
        sent["text"] = body["items"][0]["text"]; sent["model"] = body["cascadeConfig"]["plannerConfig"]["planModel"]; return {}
    if method == "CancelCascadeInvocation":
        cancel_body.update(body or {})
        return {"_err": "HTTP 500"} if scenario == "cancelfail" else {}
    if method == "GetCascadeTrajectory": return {"status": "CASCADE_RUN_STATUS_RUNNING" if scenario == "timeout" else "CASCADE_RUN_STATUS_IDLE"}
    if method == "GetCascadeTrajectorySteps":
        if scenario == "timeout": return {"steps": []}
        if scenario in ("tool", "cancelfail"): return {"steps": [{"type": "CORTEX_STEP_TYPE_WRITE_TO_FILE", "status": "CORTEX_STEP_STATUS_RUNNING"}]}
        q = sent.get("text", "")[len(m.PREAMBLE):]
        return {"steps": [{"type": "CORTEX_STEP_TYPE_PLANNER_RESPONSE", "status": "CORTEX_STEP_STATUS_DONE",
                           "plannerResponse": {"response": q + " — 끝"}, "metadata": {"generatorModel": sent.get("model")}}]}
    return {}
m.rpc = rpc
m.find_server = lambda: ("http://127.0.0.1:1/x", {"x-codeium-csrf-token": "SECRET-TOKEN-DO-NOT-PRINT"})
m.POLL_S = 0
m.time.sleep = lambda s: None
if scenario == "newfile":
    snaps = iter([set(), {"evil.txt"}])
    m.ws_files = lambda: next(snaps, {"evil.txt"})
sys.argv = ["sherlock_ag.py", "--timeout", "0" if scenario == "timeout" else "5"]
rc = m.main()
sys.stderr.write("\nPREAMBLE_OK=%s CANCEL=%s CANCEL_BODY=%s\n" % (sent.get("text", "").startswith(m.PREAMBLE), "CancelCascadeInvocation" in called, json.dumps(cancel_body)))
sys.exit(rc)
'''
env = {k: v for k, v in os.environ.items() if k not in ("PYTHONIOENCODING", "PYTHONUTF8")}


def run(scn, text="물음"):
    try:
        r = subprocess.run([sys.executable, "-c", DRIVER, scn, PATH], input=text.encode("utf-8"), capture_output=True, env=env, timeout=30)
    except subprocess.TimeoutExpired:
        return -999, "", "DRIVER TIMEOUT(30초) — 기다리기가 끝나지 않는다"
    return r.returncode, r.stdout.decode("utf-8", "replace"), r.stderr.decode("utf-8", "replace")


CID_BODY = 'CANCEL_BODY={"cascadeId": "cid1"}'
rc, out, err = run("ok", "\ufeff한국어 물음 — 테스트")
check("한글 파이프·BOM → 답 온전(UTF-8), 모델·할당량 줄", rc == 0 and out.startswith("한국어 물음 — 테스트 — 끝")
      and "MODEL_PLACEHOLDER_M318" in err and "0.5" in err, f"rc={rc} out={out[:30]!r} err={err[-200:]!r}")
check("보낸 글이 PREAMBLE(도구 금지)로 시작", "PREAMBLE_OK=True" in err, err[-120:])
check("연결 토큰이 출력에 안 나옴", "SECRET-TOKEN" not in out and "SECRET-TOKEN" not in err)
rc, out, err = run("newfile")
check("sherlock_ws 새 파일 → 경고", "새 파일" in err and "evil.txt" in err, f"rc={rc} {err[-160:]!r}")
rc, out, err = run("tool")
check("도구 단계 → 대화 취소(cascadeId 로) + exit 8", rc == 8 and CID_BODY in err and "취소 완료" in err, f"rc={rc} {err[-200:]!r}")
rc, out, err = run("timeout")
check("시간초과 → 대화 취소(cascadeId 로) + exit 7", rc == 7 and CID_BODY in err, f"rc={rc} {err[-200:]!r}")
rc, out, err = run("cancelfail")
check("취소 실패는 「취소 실패」로 드러남(완료로 속이지 않음)", rc == 8 and "취소 실패" in err and "취소 완료" not in err, f"rc={rc} {err[-200:]!r}")

for name, passed, detail in checks:
    print(("PASS " if passed else "FAIL ") + name + (" | " + detail if detail and not passed else ""))
print(f"{sum(p for _, p, _ in checks)}/{len(checks)} passed")
sys.exit(0 if all(p for _, p, _ in checks) else 1)
