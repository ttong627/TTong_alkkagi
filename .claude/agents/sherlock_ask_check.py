# 셜록 스크립트(agents/sherlock_ask.py) 점검 — 실제 API 없이 응답을 흉내 내고, 한글은 실제 파이프(기본 cp949)로 시험한다.
# 실행: python C:/Users/ttong/.claude/agents/sherlock_ask_check.py   (흉내 응답이라 과금 없음)
import os, subprocess, sys

try:
    sys.stdout.reconfigure(encoding="utf-8")  # 점검 결과에 한글·「—」가 섞여 cp949 콘솔에서 죽지 않게(제시 2026-09-13)
except (AttributeError, ValueError):
    pass

DRIVER = r'''
import importlib.util, sys
spec = importlib.util.spec_from_file_location("sa", r"C:\Users\ttong\.claude\agents\sherlock_ask.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
scenario = sys.argv[1]; calls = []
m.load_keys = lambda: ["k1", "k2", "k3"]
ok = lambda text, ver="gemini-3.8-flash": (200, {"modelVersion": ver, "candidates": [{"content": {"parts": [{"text": text}]}, "finishReason": "STOP"}]})
def fake(key, prompt):
    calls.append(key)
    if scenario in ("echo", "bom", "no_permission"): return ok(prompt + " — 끝")
    if scenario == "blocked": return 200, {"modelVersion": "gemini-3.8-flash", "promptFeedback": {"blockReason": "SAFETY"}}
    if scenario == "badkey_then_ok":
        if key == "k1": return 400, {"error": {"status": "INVALID_ARGUMENT", "details": [{"reason": "API_KEY_INVALID"}]}}
        return ok("OK", "gemini-3.8-flash-001")
    if scenario == "lite": return ok("x", "gemini-3.8-flash-lite")
    if scenario == "other400": return 400, {"error": {"status": "INVALID_ARGUMENT", "details": [{"reason": "OTHER"}]}}
if scenario == "timeout":
    def boom(*a, **k):
        calls.append("urlopen"); raise TimeoutError()
    m.urllib.request.urlopen = boom
else:
    m.call = fake
sys.argv = ["sherlock_ask.py"]
rc = m.main()
sys.stderr.write("\nCALLS=%d\n" % len(calls))
sys.exit(rc)
'''
base_env = {k: v for k, v in os.environ.items() if k not in ("PYTHONIOENCODING", "PYTHONUTF8", "SHERLOCK_ALLOW_PAID_API_KEY")}


def run(scn, text="물음", allow_paid=True):
    env = dict(base_env, SHERLOCK_ALLOW_PAID_API_KEY="1") if allow_paid else base_env
    r = subprocess.run([sys.executable, "-c", DRIVER, scn], input=text.encode("utf-8"), capture_output=True, env=env, timeout=60)
    return r.returncode, r.stdout.decode("utf-8", "replace"), r.stderr.decode("utf-8", "replace")


def last(err):
    return err.strip().splitlines()[-1] if err.strip() else ""


checks = []
rc, out, err = run("no_permission", allow_paid=False)
checks.append(("유료 키 허락 없음 → exit 6, 호출 0", rc == 6 and "CALLS=0" in err, f"rc={rc} {last(err)}"))
rc, out, err = run("echo", "한국어 물음 — 테스트")
checks.append(("한글 입출력(파이프)", rc == 0 and "한국어 물음 — 테스트 — 끝" in out, f"rc={rc} out={out.strip()[:40]!r}"))
rc, out, err = run("bom", "\ufeff물음")
checks.append(("BOM 붙은 입력 → 첫 글자 안 남음", rc == 0 and out.startswith("물음"), f"rc={rc} out={out[:12]!r}"))
rc, out, err = run("blocked")
checks.append(("차단·빈 답 → exit 5", rc == 5 and "SAFETY" in err and "candidates=0" in err, f"rc={rc}"))
rc, out, err = run("badkey_then_ok")
checks.append(("무효 키 400 → 다음 키, -001 변형 허용", rc == 0 and "CALLS=2" in err and "OK" in out, f"rc={rc} {last(err)}"))
rc, out, err = run("timeout")
checks.append(("시간초과 → 순환 안 함 exit 4", rc == 4 and "CALLS=1" in err, f"rc={rc} {last(err)}"))
rc, out, err = run("lite")
checks.append(("flash-lite → exit 3", rc == 3, f"rc={rc}"))
rc, out, err = run("other400")
checks.append(("다른 400 → 멈춤 exit 4", rc == 4 and "CALLS=1" in err, f"rc={rc}"))
for name, passed, detail in checks:
    print(("PASS " if passed else "FAIL ") + name + " | " + detail)
print(f"{sum(p for _, p, _ in checks)}/{len(checks)} passed")
sys.exit(0 if all(p for _, p, _ in checks) else 1)
