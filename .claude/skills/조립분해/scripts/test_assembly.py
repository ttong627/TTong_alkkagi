# -*- coding: utf-8 -*-
"""조립분해 스킬 검사 — 계획 수식 · 카메라 연출 (블렌더·cadgen 없이 도는 순수 계산).

실행: python -m pytest test_assembly.py -q
"""
import json
import re
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))    # ★다른 경로의 같은 이름 모듈보다 먼저

import camera  # noqa: E402
import flow_pack  # noqa: E402
import plan as P  # noqa: E402

FACTS = {"leafCount": 3, "parts": {
    "base": {"occurrence": "o1.1", "center": [0, 0, 5], "size": [60, 60, 10]},
    "middle": {"occurrence": "o1.2", "center": [0, 0, 18], "size": [44, 44, 16]},
    "lid": {"occurrence": "o1.3", "center": [0, 0, 29], "size": [60, 60, 6]},
}}
STEPS = [{"parts": ["lid"], "move": [0, 0, 40]}, {"parts": ["middle"], "move": [0, 0, 22]}]


def make(tmp_path: Path, **kw) -> dict:
    raw = {"title": "3단 받침", "step": "a.step", "glb": "a.glb",
           "parts": [{"label": "base"}, {"label": "middle"}, {"label": "lid"}], "steps": STEPS, **kw}
    path = tmp_path / "조립계획.json"
    path.write_text(json.dumps(raw, ensure_ascii=False), encoding="utf-8")
    return P.load(path)


def close(a, b, tol=1e-6):
    return all(abs(x - y) <= tol for x, y in zip(a, b))


# ── 계획 ───────────────────────────────────────────────────

@pytest.mark.parametrize("n", [1, 2, 3, 5])
@pytest.mark.parametrize("k", [0.0, 0.35, 0.8])
def test_windows_cover_whole_phase(n, k):
    w = P.windows(n, k)
    assert w[0][0] == pytest.approx(0.0) and w[-1][1] == pytest.approx(1.0)
    assert all(w[i][0] < w[i + 1][0] for i in range(n - 1))


def test_offsets_rest_full_rest(tmp_path):
    p = make(tmp_path)
    assert all(v == [0, 0, 0] for v in P.offsets_at(p, 0.0).values())
    hold_mid = 1.5 + 3.0 + 0.75
    off = P.offsets_at(p, hold_mid)
    assert off["lid"] == [0, 0, 40] and off["middle"] == [0, 0, 22] and off["base"] == [0, 0, 0]
    assert all(close(v, [0, 0, 0]) for v in P.offsets_at(p, P.duration(p)).values())


def test_assemble_is_exact_reverse_of_explode(tmp_path):
    p = make(tmp_path)
    for i in range(21):
        q = i / 20
        a = P.offsets_at(p, 1.5 + 3.0 * q)            # 분해 q 지점
        b = P.offsets_at(p, 6.0 + 3.0 * (1 - q))      # 조립의 같은 모습
        assert all(close(a[x], b[x]) for x in a), q


def test_stagger_last_out_goes_in_first(tmp_path):
    p = make(tmp_path)
    early_ex = P.step_levels(p, 1.5 + 0.6)           # 분해 초반: 뚜껑이 먼저 나간다
    assert early_ex[0] > early_ex[1]
    early_as = P.step_levels(p, 6.0 + 0.6)           # 조립 초반: 나중에 나간 가운데가 먼저 들어간다
    assert early_as[1] < early_as[0]


def test_validate_catches_mistakes(tmp_path):
    p = make(tmp_path, ratio="4:3", steps=[{"parts": ["cap"], "move": [0, 0, 0]}])
    errs = " / ".join(P.validate(p, tmp_path))
    for word in ("step 파일이 없다", "ratio", "없는 이름", "move 가 0"):
        assert word in errs


def test_validate_ok_when_files_exist(tmp_path):
    (tmp_path / "a.step").write_text("x")
    (tmp_path / "a.glb").write_text("x")
    assert P.validate(make(tmp_path), tmp_path) == []


@pytest.mark.parametrize("flow", list(P.FLOWS))
def test_return_to_assembled(tmp_path, flow):
    assert P.check_return(make(tmp_path, flow=flow)) == []


def test_return_catches_unfinished(tmp_path):
    p = make(tmp_path)
    p["timing"]["assemble"] = 3.0
    bad = {**p, "flow": "분해후조립"}
    bad_levels = P.LEVEL.copy()
    try:
        P.LEVEL["outro"] = 1.0                        # 일부러 끝을 벌어진 채로
        assert P.check_return(bad)
    finally:
        P.LEVEL.update(bad_levels)


def test_collision_detects_part_passing_through(tmp_path):
    ok = make(tmp_path)
    assert P.check_collisions(ok, FACTS) == []
    wrong = make(tmp_path, steps=[{"parts": ["middle"], "move": [0, 0, 40]}, {"parts": ["lid"], "move": [0, 0, 8]}])
    assert any("middle↔lid" in m or "lid↔middle" in m for m in P.check_collisions(wrong, FACTS))


def test_count_mismatch(tmp_path):
    assert P.check_count(make(tmp_path), {**FACTS, "leafCount": 4})
    assert P.check_count(make(tmp_path), FACTS) == []


def test_viewer_js_uses_same_offsets(tmp_path):
    p = make(tmp_path)
    js = P.viewer_js(p)
    tracks = json.loads(re.search(r"const TRACKS = (\{.*?\});\n", js).group(1))
    assert "base" not in tracks and set(tracks) == {"lid", "middle"}
    for k in (0, 20, 60, 100):
        want = P.offsets_at(p, min(P.duration(p), k / P.VIEWER_RATE))
        assert close(tracks["lid"][k], want["lid"], 1e-3)
    assert "export const clips" in js and "m.get(label).translate" in js


# ── 카메라 ─────────────────────────────────────────────────

@pytest.mark.parametrize("name", list(camera.PRESETS))
def test_preset_seams_are_continuous(name):
    assert camera.check_preset(name) == []


def test_pchip_hits_waypoints_without_overshoot():
    xs, ys = [0, 1, 2, 3], [0, 10, 10, 0]
    assert [camera.pchip(xs, ys, x) for x in xs] == ys
    assert all(-1e-9 <= camera.pchip(xs, ys, i / 50) <= 10 + 1e-9 for i in range(151))   # 소수점 끝자리 오차만 허용


def test_project_target_lands_in_center():
    key = {"pos": [0, -100, 0], "target": [0, 0, 0], "lens": 50}
    x, y, z = camera.project(key, [0, 0, 0], "16:9")
    assert (round(x, 6), round(y, 6)) == (0.5, 0.5) and z == pytest.approx(100)


@pytest.mark.parametrize("shot", list(camera.PRESETS))
@pytest.mark.parametrize("ratio", ["16:9", "9:16"])
def test_every_frame_inside_safe_area_and_smooth(tmp_path, shot, ratio):
    p = make(tmp_path, shot=shot, ratio=ratio)
    keys = camera.camera_keys(p, FACTS)
    assert len(keys) == len(P.frame_times(p))
    assert camera.check_framing(p, FACTS, keys) == []
    assert camera.check_motion(keys, p["fps"]) == []


TIMELINE = [("intro", 0.0, 1.5), ("explode", 1.5, 4.5), ("hold", 4.5, 6.0), ("assemble", 6.0, 9.0), ("outro", 9.0, 10.5)]


# ── Flow 화풍 ──────────────────────────────────────────────

def test_segments_cut_at_phase_bounds_under_10s():
    segs = flow_pack.segments(TIMELINE)
    assert segs == [(0.0, 4.5), (4.5, 10.5)]              # 조각 둘 · 짧은 1.5초 조각을 만들지 않는다
    assert all(b - a <= flow_pack.MAX_EDIT for a, b in segs)


def test_segments_split_one_long_phase():
    segs = flow_pack.segments([("explode", 0.0, 25.0)])
    assert len(segs) == 3 and segs[-1][1] == 25.0 and all(b - a <= 10 + 1e-6 for a, b in segs)


def test_rendering_only_drops_people_sentences():
    text = ("Brushwork: confident strokes that swell and taper. Figures: people are drawn with clean outlines. "
            "Color: thin ochre washes. Faces use a few precise strokes.")
    got = flow_pack.rendering_only(text)
    assert "Brushwork" in got and "ochre" in got and "people" not in got and "Faces" not in got


def test_edit_prompt_keeps_motion_and_passes_gate():
    import flow_story
    prompt, _ = flow_pack.edit_prompt("16:9", "Color: thin ochre washes.", True)
    assert "Keep the camera movement" in prompt and "Do not copy any character" in prompt
    assert flow_story.gate(prompt)[0] == []


def test_edit_prompt_drops_blocked_style_notes():
    prompt, warns = flow_pack.edit_prompt("9:16", "A crying child in the rain.", False)
    assert "crying" not in prompt and warns


def test_camera_backs_off_before_parts_spread(tmp_path):
    p = make(tmp_path, shot="설명")                    # 거리배수가 거의 1 인 연출로 크기 효과만 본다
    keys = camera.camera_keys(p, FACTS)
    at = {round(k["t"], 2): k["focus"] for k in keys}
    assert at[5.25] > at[0.5] * 1.1                  # 다 벌어진 멈춤 구간이 조립 상태보다 멀다
