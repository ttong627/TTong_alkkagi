# -*- coding: utf-8 -*-
"""조립분해 계획(정본) — 부품 정보 · 분해 순서 · 시간표 → 매 장면 부품 위치.

비유: 무용 동작표. 누가(부품) 언제(시간) 어디로(이동) 가는지를 한 장에 적어 두면
블렌더(입체·도면선)와 CAD 뷰어가 **같은 표**를 보고 움직인다. 위치 수식은 이 파일 한 곳에만 있다.

계획 파일(조립계획.json) 모양은 SKILL.md 2절.
"""
from __future__ import annotations

import json
import os
import subprocess
from itertools import combinations
from pathlib import Path

CAD_PY = Path(os.environ.get("CAD_PY", r"D:\Tools\cad_venv\Scripts\python.exe"))
PHASE_KO = {"intro": "등장", "explode": "분해", "hold": "멈춤", "assemble": "조립", "outro": "마무리"}
FLOWS = {
    "분해후조립": ("intro", "explode", "hold", "assemble", "outro"),
    "분해만": ("intro", "explode", "hold"),
    "조립만": ("hold", "assemble", "outro"),
}
DEFAULT_TIMING = {"intro": 1.5, "explode": 3.0, "hold": 1.5, "assemble": 3.0, "outro": 1.5}
LEVEL = {"intro": 0.0, "hold": 1.0, "outro": 0.0}      # 이 구간의 분해 정도(0=조립 · 1=다 벌어짐)
FPS_OK = (24, 25, 30)
MAX_SECONDS = 60
VIEWER_RATE = 12                                        # CAD 뷰어 애니메이션 표 — 초당 12칸


# ── 계획 읽기·검사 ─────────────────────────────────────────

def load(path: Path) -> dict:
    plan = json.loads(Path(path).read_text(encoding="utf-8"))
    return {
        "ratio": "16:9", "fps": 24, "flow": "분해후조립", "stagger": 0.35, "shot": "시네마",
        **plan,
        "timing": {**DEFAULT_TIMING, **plan.get("timing", {})},
    }


def validate(plan: dict, base: Path) -> list[str]:
    """고칠 것 목록. 빈 목록이어야 다음 단계로 간다."""
    errs: list[str] = []
    for key in ("title", "step", "glb"):
        if not plan.get(key):
            errs.append(f"{key} 가 비었다")
        elif key != "title" and not (base / plan[key]).exists():
            errs.append(f"{key} 파일이 없다 — {base / plan[key]}")
    if plan["ratio"] not in ("16:9", "9:16"):
        errs.append("ratio 는 16:9 또는 9:16")
    if plan["fps"] not in FPS_OK:
        errs.append(f"fps 는 {FPS_OK} 중 하나")
    if plan["flow"] not in FLOWS:
        errs.append(f"flow 는 {list(FLOWS)} 중 하나")
    if not 0 <= plan["stagger"] < 1:
        errs.append("stagger(부품이 겹쳐 움직이는 정도)는 0 이상 1 미만")
    labels = [p.get("label") for p in plan.get("parts", [])]
    if not labels:
        errs.append("parts 가 비었다")
    elif not all(labels) or len(set(labels)) != len(labels):
        errs.append(f"parts 의 label 이 비었거나 겹친다 — {labels}")
    if not plan.get("steps"):
        errs.append("steps(분해 순서)가 비었다")
    for i, st in enumerate(plan.get("steps", []), 1):
        unknown = [x for x in st.get("parts", []) if x not in labels]
        if not st.get("parts") or unknown:
            errs.append(f"steps {i}: 부품이 없거나 parts 에 없는 이름 {unknown}")
        move = st.get("move")
        if not (isinstance(move, list) and len(move) == 3 and all(isinstance(v, (int, float)) for v in move)):
            errs.append(f"steps {i}: move 는 [x, y, z] mm 숫자 셋")
        elif not any(move):
            errs.append(f"steps {i}: move 가 0 — 움직이지 않는 단계")
    if plan["flow"] in FLOWS:
        for ph in FLOWS[plan["flow"]]:
            if not isinstance(plan["timing"].get(ph), (int, float)) or plan["timing"][ph] <= 0:
                errs.append(f"timing.{ph}({PHASE_KO[ph]}) 는 0보다 큰 초")
        if not errs and duration(plan) > MAX_SECONDS:
            errs.append(f"전체 {duration(plan):.1f}초 — {MAX_SECONDS}초 이하로")
    return errs


# ── 시간표 ─────────────────────────────────────────────────

def timeline(plan: dict) -> list[tuple[str, float, float]]:
    out, t = [], 0.0
    for ph in FLOWS[plan["flow"]]:
        d = float(plan["timing"][ph])
        out.append((ph, t, t + d))
        t += d
    return out


def duration(plan: dict) -> float:
    return timeline(plan)[-1][2]


def frame_times(plan: dict) -> list[float]:
    return [i / plan["fps"] for i in range(int(round(duration(plan) * plan["fps"])))]


def phase_at(plan: dict, t: float) -> tuple[str, float]:
    """(구간, 구간 안 진행 0~1)."""
    tl = timeline(plan)
    for ph, a, b in tl:
        if t < b:
            return ph, max(0.0, (t - a) / (b - a))
    return tl[-1][0], 1.0


# ── 움직임 (정본 수식) ──────────────────────────────────────

def smoother(x: float) -> float:
    """부드러운 가속·감속(시작·끝에서 속도와 가속도가 0)."""
    x = min(1.0, max(0.0, x))
    return x * x * x * (x * (x * 6 - 15) + 10)


def windows(n: int, overlap: float) -> list[tuple[float, float]]:
    """단계마다 움직이는 구간(0~1 안). overlap 만큼 앞 단계와 겹쳐 출발한다 — 기계적인 차례차례를 피한다."""
    if n <= 1:
        return [(0.0, 1.0)]
    w = 1.0 / (n - (n - 1) * overlap)
    return [(i * w * (1 - overlap), i * w * (1 - overlap) + w) for i in range(n)]


def step_levels(plan: dict, t: float) -> list[float]:
    """단계마다 분해 정도 0~1. 조립은 **나중에 빠진 것부터** 들어간다(분해의 정확한 역순)."""
    n = len(plan["steps"])
    win = windows(n, plan["stagger"])
    ph, p = phase_at(plan, t)
    if ph == "explode":
        return [smoother((p - s) / (e - s)) for s, e in win]
    if ph == "assemble":
        return [1.0 - smoother((p - win[n - 1 - i][0]) / (win[n - 1 - i][1] - win[n - 1 - i][0]))
                for i in range(n)]
    return [LEVEL[ph]] * n


def offsets_at(plan: dict, t: float) -> dict[str, list[float]]:
    """부품마다 조립 자리에서 얼마나 옮겨졌나(mm). 한 부품이 여러 단계에 나오면 차례로 더한다."""
    out = {p["label"]: [0.0, 0.0, 0.0] for p in plan["parts"]}
    for level, st in zip(step_levels(plan, t), plan["steps"]):
        for lab in st["parts"]:
            out[lab] = [o + m * level for o, m in zip(out[lab], st["move"])]
    return out


# ── 부품 정보 (cad 스킬의 cadgen 으로 읽는다) ──────────────

def _cadgen(args: list[str], cwd: Path) -> dict:
    env = {**os.environ, "PYTHONUTF8": "1", "CADGEN_DAEMON": "0"}   # ★PYTHONUTF8 없으면 한글 주석에 파싱 실패
    r = subprocess.run([str(CAD_PY), "-m", "cadgen.cli", *args], capture_output=True, text=True,
                       encoding="utf-8", errors="replace", env=env, cwd=str(cwd), timeout=900)
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"cadgen 결과를 못 읽었다(종료코드 {r.returncode}) — {r.stderr.strip()[-600:]}") from exc


def fetch_facts(plan: dict, base: Path) -> dict:
    """{"parts": {label: {occurrence, center, size}}, "leafCount": STEP 부품 수}."""
    step = (base / plan["step"]).resolve()
    labels = [p["label"] for p in plan["parts"]]
    data = _cadgen(["step", "inspect", "refs", str(step), *[f"#{x}" for x in labels], "--facts"], step.parent)
    parts = {}
    for tok in data.get("tokens", []):
        for sel in tok.get("selections") or []:
            if sel.get("status") == "resolved" and sel.get("summary") in labels:
                g = sel["geometryFacts"]
                parts[sel["summary"]] = {"occurrence": sel["normalizedSelector"],
                                         "center": g["center"], "size": g["size"]}
    missing = [x for x in labels if x not in parts]
    if missing:
        raise RuntimeError(f"STEP 에 없는 부품 이름 {missing} — cad 스킬 모델의 .label 과 계획 parts.label 을 맞춘다")
    whole = _cadgen(["step", "inspect", "refs", str(step), "--facts"], step.parent)
    leaf = (whole.get("tokens") or [{}])[0].get("summary", {}).get("leafOccurrenceCount")
    return {"parts": parts, "leafCount": leaf}


def aabb(fact: dict, off: list[float] | tuple = (0.0, 0.0, 0.0)) -> tuple[list[float], list[float]]:
    c, s = fact["center"], fact["size"]
    return [c[i] - s[i] / 2 + off[i] for i in range(3)], [c[i] + s[i] / 2 + off[i] for i in range(3)]


def union(boxes: list[tuple[list[float], list[float]]]) -> tuple[list[float], list[float]]:
    return ([min(b[0][i] for b in boxes) for i in range(3)], [max(b[1][i] for b in boxes) for i in range(3)])


def boxes_at(plan: dict, facts: dict, t: float) -> dict[str, tuple[list[float], list[float]]]:
    off = offsets_at(plan, t)
    return {lab: aabb(facts["parts"][lab], off[lab]) for lab in off}


# ── 검사 ───────────────────────────────────────────────────

def check_count(plan: dict, facts: dict) -> list[str]:
    if facts.get("leafCount") != len(plan["parts"]):
        return [f"부품 수가 다르다 — STEP {facts.get('leafCount')}개 · 계획 {len(plan['parts'])}개 "
                "(계획에 없는 부품은 영상에서 제자리에 남는다)"]
    return []


def check_return(plan: dict, tol: float = 1e-6) -> list[str]:
    """되감기 — 조립 상태로 끝나야 하는 흐름은 처음·끝 위치가 조립 자리(0)여야 한다."""
    moments = {"분해후조립": (0.0, duration(plan)), "분해만": (0.0,), "조립만": (duration(plan),)}[plan["flow"]]
    bad = [f"{t:.2f}초 {lab} {v}" for t in moments for lab, v in offsets_at(plan, t).items()
           if any(abs(x) > tol for x in v)]
    return [f"조립 자리로 안 돌아온다 — {', '.join(bad)}"] if bad else []


def _overlap(a: tuple, b: tuple) -> float:
    v = 1.0
    for i in range(3):
        v *= max(0.0, min(a[1][i], b[1][i]) - max(a[0][i], b[0][i]))
    return v


def _volume(box: tuple) -> float:
    return (box[1][0] - box[0][0]) * (box[1][1] - box[0][1]) * (box[1][2] - box[0][2])


def check_collisions(plan: dict, facts: dict, rate: int = 12) -> list[str]:
    """부품 상자(AABB)끼리 조립 상태보다 **더** 겹치면 서로 뚫고 지나가는 것.

    ⚠️상자 검사라 거칠다 — 구멍에 박힌 볼트처럼 처음부터 상자가 겹친 부품은 더 파고들어도 못 잡을 수 있다.
    """
    rest = {lab: aabb(f) for lab, f in facts["parts"].items() if lab in {p["label"] for p in plan["parts"]}}
    base = {pair: _overlap(rest[pair[0]], rest[pair[1]]) for pair in combinations(sorted(rest), 2)}
    found: dict[tuple, str] = {}
    steps = int(duration(plan) * rate) + 1
    for k in range(steps):
        t = k / rate
        boxes = boxes_at(plan, facts, t)
        for pair, b0 in base.items():
            if pair in found:
                continue
            tol = 0.02 * min(_volume(rest[pair[0]]), _volume(rest[pair[1]]))
            if _overlap(boxes[pair[0]], boxes[pair[1]]) > b0 + tol:
                found[pair] = f"{t:.2f}초 {pair[0]}↔{pair[1]} 가 서로 파고든다(이동 방향·거리·순서 확인)"
    return list(found.values())


# ── CAD 뷰어 확인용 애니메이션 ─────────────────────────────

def viewer_js(plan: dict) -> str:
    """`STEP/<이름>.step.js` — 수식을 JS 로 다시 쓰지 않고 **위치 표**를 넣는다(정본은 offsets_at 하나)."""
    total = duration(plan)
    n = int(total * VIEWER_RATE) + 2
    tracks = {}
    for k in range(n):
        for lab, v in offsets_at(plan, min(total, k / VIEWER_RATE)).items():
            tracks.setdefault(lab, []).append([round(x, 3) for x in v])
    moving = {lab: tr for lab, tr in tracks.items() if any(any(x) for x in tr)}
    return (
        f"// 자동 생성 — 조립분해 계획 「{plan['title']}」. 손으로 고치지 말고 계획을 고친 뒤 다시 만든다.\n"
        f"const RATE = {VIEWER_RATE};\n"
        f"const TRACKS = {json.dumps(moving, ensure_ascii=False)};\n"
        "function sample(tr, t) {\n"
        "  const x = t * RATE;\n"
        "  const i = Math.min(tr.length - 2, Math.max(0, Math.floor(x)));\n"
        "  const f = Math.min(1, Math.max(0, x - i));\n"
        "  return [0, 1, 2].map((k) => tr[i][k] + (tr[i + 1][k] - tr[i][k]) * f);\n"
        "}\n"
        "export const clips = {\n"
        f"  assembly: {{\n    label: {json.dumps(plan['title'], ensure_ascii=False)},\n"
        f"    duration: {round(total, 3)},\n    loop: true,\n"
        "    update(t, m) {\n"
        "      for (const [label, tr] of Object.entries(TRACKS)) m.get(label).translate(sample(tr, t));\n"
        "    },\n  },\n};\n"
    )
