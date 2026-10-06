# -*- coding: utf-8 -*-
"""영화 느낌 자동 연출 — 매 장면 카메라 위치 · 겨냥점 · 렌즈 · 초점.

비유: 촬영 감독의 콘티. 구간(등장·분해·멈춤·조립·마무리)이 끝날 때 카메라가
「어느 방향에서 · 얼마나 높이 · 얼마나 가까이」 있을지를 표로 정해 두고, 그 사이를
**끊김 없는 곡선**(속도가 이어지는 단조 3차 보간)으로 잇는다 — 구간마다 멈췄다 가는 기계 느낌이 없다.
부품이 벌어지면 **미리** 물러서고(앞을 내다본 최대 크기), 줌은 부드럽게만 바뀐다.

전부 순수 계산이라 블렌더 없이 검사한다: 잘림(안전 영역) · 카메라 속도 · 급한 줌.
"""
from __future__ import annotations

import math

from plan import FLOWS, boxes_at, duration, frame_times, phase_at, timeline, union

SENSOR = 36.0                 # 블렌더 기본 센서 폭(mm) — 긴 변 기준
SAFE = (0.05, 0.95)           # 안전 영역: 화면 가장자리 5% 안쪽
FIT = 0.9                     # 거리 1.0 = 부품 전체(구)가 짧은 변의 90% 안에 들어가는 거리
MARGIN = 0.02                 # 만들 때는 안전 영역보다 조금 더 안쪽을 노린다(부드럽게 이으며 생기는 오차 몫)
LEAD = 0.6                    # 부품이 벌어지기 몇 초 전부터 물러서나
SMOOTH = 0.8                  # 거리·겨냥점 부드럽게(초)
MAX_TURN = 40.0               # 초당 최대 회전(도)
MAX_ZOOM = 0.6                # 초당 최대 거리 변화 비율

# 구간마다 (방위각 시작·끝, 높이각 시작·끝, 거리배수 시작·끝) — 구간의 끝은 다음 구간의 시작과 같아야 한다
PRESETS = {
    "시네마": {   # 원테이크: 천천히 돌며 등장 → 벌어지는 동안 크레인 업 → 멈춰 보여줌 → 내려오며 밀고 들어가 로우앵글
        "lens": 50, "fstop": 2.8,
        "intro": {"az": (-70, -50), "el": (14, 18), "dist": (1.15, 1.0)},
        "explode": {"az": (-50, -25), "el": (18, 30), "dist": (1.0, 1.0)},
        "hold": {"az": (-25, -5), "el": (30, 30), "dist": (1.0, 0.95)},
        "assemble": {"az": (-5, 20), "el": (30, 16), "dist": (0.95, 1.0)},
        "outro": {"az": (20, 30), "el": (16, 9), "dist": (1.0, 0.93)},
    },
    "제품광고": {  # 망원·얕은 심도·낮은 앵글·넓게 도는 궤도
        "lens": 85, "fstop": 2.0,
        "intro": {"az": (-95, -60), "el": (8, 12), "dist": (1.25, 1.0)},
        "explode": {"az": (-60, -15), "el": (12, 26), "dist": (1.0, 1.0)},
        "hold": {"az": (-15, 15), "el": (26, 24), "dist": (1.0, 0.94)},
        "assemble": {"az": (15, 50), "el": (24, 10), "dist": (0.94, 1.0)},
        "outro": {"az": (50, 62), "el": (10, 7), "dist": (1.0, 0.92)},
    },
    "설명": {      # 교육용: 거의 고정된 3/4 시점 · 깊은 심도 · 아주 느린 밀기
        "lens": 35, "fstop": 11.0,
        "intro": {"az": (-42, -40), "el": (28, 28), "dist": (1.04, 1.0)},
        "explode": {"az": (-40, -36), "el": (28, 30), "dist": (1.0, 1.0)},
        "hold": {"az": (-36, -34), "el": (30, 30), "dist": (1.0, 1.0)},
        "assemble": {"az": (-34, -36), "el": (30, 28), "dist": (1.0, 1.0)},
        "outro": {"az": (-36, -38), "el": (28, 28), "dist": (1.0, 0.97)},
    },
}


# ── 곡선 ───────────────────────────────────────────────────

def pchip(xs: list[float], ys: list[float], x: float) -> float:
    """단조 3차 보간(Fritsch–Carlson). 넘치지 않고 속도가 이어진다. 양 끝 속도 0 = 부드러운 출발·도착."""
    n = len(xs)
    if x <= xs[0]:
        return ys[0]
    if x >= xs[-1]:
        return ys[-1]
    h = [xs[i + 1] - xs[i] for i in range(n - 1)]
    d = [(ys[i + 1] - ys[i]) / h[i] for i in range(n - 1)]
    m = [0.0] * n
    for i in range(1, n - 1):
        if d[i - 1] * d[i] > 0:
            w1, w2 = 2 * h[i] + h[i - 1], h[i] + 2 * h[i - 1]
            m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])
    k = max(i for i in range(n - 1) if xs[i] <= x)
    s = (x - xs[k]) / h[k]
    h00, h10 = 2 * s ** 3 - 3 * s ** 2 + 1, s ** 3 - 2 * s ** 2 + s
    h01, h11 = -2 * s ** 3 + 3 * s ** 2, s ** 3 - s ** 2
    return h00 * ys[k] + h10 * h[k] * m[k] + h01 * ys[k + 1] + h11 * h[k] * m[k + 1]


def waypoints(plan: dict, key: str) -> tuple[list[float], list[float]]:
    """(시각들, 값들) — 첫 구간의 시작 + 구간마다 끝."""
    preset = PRESETS[plan["shot"]]
    tl = timeline(plan)
    xs, ys = [tl[0][1]], [float(preset[tl[0][0]][key][0])]
    for ph, _, b in tl:
        xs.append(b)
        ys.append(float(preset[ph][key][1]))
    return xs, ys


def _smooth(values: list[float], radius: int) -> list[float]:
    if radius <= 0:
        return list(values)
    n = len(values)
    return [sum(values[max(0, i - radius):min(n, i + radius + 1)]) / (min(n, i + radius + 1) - max(0, i - radius))
            for i in range(n)]


# ── 렌즈·투영 ──────────────────────────────────────────────

def half_fov(lens: float, ratio: str) -> tuple[float, float]:
    """(가로 반각, 세로 반각) 라디안 — 블렌더 센서 맞춤 AUTO(긴 변에 36mm)."""
    long_half, short_half = math.atan(SENSOR / 2 / lens), math.atan(SENSOR / 2 * 9 / 16 / lens)
    return (long_half, short_half) if ratio == "16:9" else (short_half, long_half)


def direction(az: float, el: float) -> list[float]:
    """방위각 0 = 정면(-Y 쪽에서 +Y 를 본다) · 높이각은 바닥에서 위로."""
    a, e = math.radians(az), math.radians(el)
    return [math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)]


def _norm(v: list[float]) -> list[float]:
    n = math.sqrt(sum(x * x for x in v)) or 1.0
    return [x / n for x in v]


def _cross(a: list[float], b: list[float]) -> list[float]:
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def project(key: dict, point: list[float], ratio: str) -> tuple[float, float, float]:
    """(가로 0~1, 세로 0~1 위에서부터, 깊이). 블렌더 트랙 카메라(수평 유지)와 같은 투영."""
    pos, tgt = key["pos"], key["target"]
    f = _norm([tgt[i] - pos[i] for i in range(3)])
    r = _norm(_cross(f, [0.0, 0.0, 1.0]))
    u = _cross(r, f)
    v = [point[i] - pos[i] for i in range(3)]
    x, y, z = (sum(v[i] * r[i] for i in range(3)), sum(v[i] * u[i] for i in range(3)), sum(v[i] * f[i] for i in range(3)))
    hx, hy = half_fov(key["lens"], ratio)
    if z <= 1e-9:
        return -1.0, -1.0, z
    return (x / (z * math.tan(hx)) + 1) / 2, (1 - y / (z * math.tan(hy))) / 2, z


# ── 카메라 키 ──────────────────────────────────────────────

def camera_keys(plan: dict, facts: dict) -> list[dict]:
    """장면마다 {t, phase, pos, target, lens, focus, fstop} (mm)."""
    preset = PRESETS[plan["shot"]]
    lens = float(preset["lens"])
    times = frame_times(plan)
    fps = plan["fps"]
    boxes = [list(boxes_at(plan, facts, t).values()) for t in times]
    unions = [union(b) for b in boxes]
    radius = [math.dist(u[0], u[1]) / 2 for u in unions]
    centers = [[(u[0][i] + u[1][i]) / 2 for i in range(3)] for u in unions]
    win = int(SMOOTH * fps / 2)
    ctr = [list(c) for c in zip(*[_smooth([c[k] for c in centers], win) for k in range(3)])]
    fit = 1.0 / (math.sin(min(half_fov(lens, plan["ratio"]))) * FIT)
    curves = {k: waypoints(plan, k) for k in ("az", "el", "dist")}
    angles = [(pchip(*curves["az"], t), min(pchip(*curves["el"], t), 80.0)) for t in times]
    planned = [radius[i] * fit * pchip(*curves["dist"], t) for i, t in enumerate(times)]
    # ★자동 구도 보장 — 연출이 밀고 들어가도 부품 모서리가 안전 영역을 넘으면 딱 그만큼만 물러선다
    need = [required_distance(boxes[i], ctr[i], direction(*angles[i]), lens, plan["ratio"], planned[i])
            for i in range(len(times))]
    wish = [max(a, b) for a, b in zip(planned, need)]
    lead = max(1, int(LEAD * fps))
    ahead = [max(wish[i:i + lead + 1]) for i in range(len(wish))]   # 벌어지기 전에 미리 물러선다
    dist = [max(a, b) for a, b in zip(_smooth(ahead, win), need)]
    keys = []
    for i, t in enumerate(times):
        dirv = direction(*angles[i])
        keys.append({"t": round(t, 4), "phase": phase_at(plan, t)[0], "az": angles[i][0], "el": angles[i][1],
                     "pos": [ctr[i][k] + dirv[k] * dist[i] for k in range(3)], "target": ctr[i],
                     "lens": lens, "focus": dist[i], "fstop": float(preset["fstop"])})
    return keys


def _corners(box: tuple) -> list[list[float]]:
    mn, mx = box
    return [[x, y, z] for x in (mn[0], mx[0]) for y in (mn[1], mx[1]) for z in (mn[2], mx[2])]


def inside(boxes: list[tuple], key: dict, ratio: str, margin: float = 0.0) -> bool:
    lo, hi = SAFE[0] + margin, SAFE[1] - margin
    for box in boxes:
        for pt in _corners(box):
            x, y, z = project(key, pt, ratio)
            if z <= 0 or not (lo <= x <= hi and lo <= y <= hi):
                return False
    return True


def required_distance(boxes: list[tuple], target: list[float], dirv: list[float], lens: float,
                      ratio: str, start: float) -> float:
    """이 방향에서 모든 부품 모서리가 안전 영역(+여유) 안에 드는 가장 가까운 거리. start 로 충분하면 0."""
    def key(d: float) -> dict:
        return {"pos": [target[k] + dirv[k] * d for k in range(3)], "target": target, "lens": lens}
    if inside(boxes, key(start), ratio, MARGIN):
        return 0.0
    lo, hi = start, start * 1.25
    for _ in range(40):
        if inside(boxes, key(hi), ratio, MARGIN):
            break
        lo, hi = hi, hi * 1.25
    for _ in range(30):
        mid = (lo + hi) / 2
        lo, hi = (lo, mid) if inside(boxes, key(mid), ratio, MARGIN) else (mid, hi)
    return hi


# ── 검사 ───────────────────────────────────────────────────

def check_preset(name: str) -> list[str]:
    """구간 이음매 — 앞 구간의 끝과 다음 구간의 시작이 같아야 카메라가 튀지 않는다."""
    p = PRESETS[name]
    errs = []
    for flow in FLOWS.values():
        for a, b in zip(flow, flow[1:]):
            for k in ("az", "el", "dist"):
                if p[a][k][1] != p[b][k][0]:
                    errs.append(f"{name}: {a}→{b} {k} 끝 {p[a][k][1]} ≠ 시작 {p[b][k][0]}")
    return sorted(set(errs))


def check_framing(plan: dict, facts: dict, keys: list[dict], limit: int = 5) -> list[str]:
    """장면마다 모든 부품 상자의 모서리 8점이 안전 영역 안에 있나."""
    bad = []
    for key in keys:
        for lab, (mn, mx) in boxes_at(plan, facts, key["t"]).items():
            corners = [[(mn, mx)[a][0], (mn, mx)[b][1], (mn, mx)[c][2]] for a in (0, 1) for b in (0, 1) for c in (0, 1)]
            for pt in corners:
                x, y, z = project(key, pt, plan["ratio"])
                if z <= 0 or not (SAFE[0] <= x <= SAFE[1] and SAFE[0] <= y <= SAFE[1]):
                    bad.append(f"{key['t']:.2f}초 {lab} 가 화면 밖(가로 {x:.2f} · 세로 {y:.2f})")
                    break
    return bad[:limit] + ([f"… 외 {len(bad) - limit}건"] if len(bad) > limit else [])


def check_motion(keys: list[dict], fps: int) -> list[str]:
    """카메라가 튀나 — 초당 회전·거리 변화."""
    bad = []
    for a, b in zip(keys, keys[1:]):
        da = [a["pos"][i] - a["target"][i] for i in range(3)]
        db = [b["pos"][i] - b["target"][i] for i in range(3)]
        cos = sum(x * y for x, y in zip(_norm(da), _norm(db)))
        turn = math.degrees(math.acos(max(-1.0, min(1.0, cos)))) * fps
        zoom = abs(b["focus"] - a["focus"]) / max(a["focus"], 1e-9) * fps
        if turn > MAX_TURN:
            bad.append(f"{b['t']:.2f}초 회전 초당 {turn:.0f}도 > {MAX_TURN:.0f}")
        if zoom > MAX_ZOOM:
            bad.append(f"{b['t']:.2f}초 거리 변화 초당 {zoom:.0%} > {MAX_ZOOM:.0%}")
    return bad[:5] + ([f"… 외 {len(bad) - 5}건"] if len(bad) > 5 else [])
