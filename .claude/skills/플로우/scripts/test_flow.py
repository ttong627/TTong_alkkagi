# -*- coding: utf-8 -*-
"""/플로우 — 패키지·변환기·유사도 검사. Flow·코덱스를 부르지 않는다."""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import adapters as ad  # noqa: E402
import flow_similarity as fs  # noqa: E402
import flow_story as st  # noqa: E402


def test_imports_the_copies_next_to_this_test():
    for m in (ad, fs, st):
        assert Path(m.__file__).resolve().parent == HERE


def _img(p, color=(200, 180, 150), shapes=True):
    im = Image.new("RGB", (320, 180), color)
    if shapes:
        d = ImageDraw.Draw(im)
        for i in range(12):
            d.rectangle([10 + i * 25, 20 + (i % 3) * 40, 30 + i * 25, 60 + (i % 3) * 40], fill=(20 * i % 255, 40, 90))
    p.parent.mkdir(parents=True, exist_ok=True)
    im.save(p)
    return p


def _story(tmp):
    _img(tmp / "refs" / "tong.png")
    _img(tmp / "refs" / "office.png", (230, 230, 220))
    return {
        "title": "시험", "ratio": "9:16", "model": "Omni Flash 1.1", "style": None,
        "cast": [{"id": "tong", "flow_name": "통통", "refs": ["refs/tong.png"], "voice": "낮은 남성",
                  "policy_note": "an adult man"}],
        "locations": [{"id": "office", "flow_name": "사무실", "refs": ["refs/office.png"]}],
        "shots": [{"id": "S01", "duration": 8, "cast": ["tong"], "location": "office",
                   "action": "walks to the window and turns toward the viewer",
                   "camera": "slow dolly in", "dialogue": [{"who": "tong", "line": "결재 났어"}]}],
    }


# ── 정본 검사 ──────────────────────────────────────────

def test_valid_story_has_no_errors(tmp_path):
    assert st.validate(st.load(_write(tmp_path, _story(tmp_path))), tmp_path) == []


def _write(tmp, story):
    p = tmp / "story.json"
    p.write_text(json.dumps(story, ensure_ascii=False), encoding="utf-8")
    return p


def test_duration_must_fit_model_with_ingredients(tmp_path):
    s = _story(tmp_path)
    s["model"] = "Veo 3.1 Fast"
    s["shots"][0]["duration"] = 6                     # Veo Fast 재료는 8초만
    assert any("8" in e for e in st.validate(s, tmp_path))


def test_quality_model_cannot_use_references(tmp_path):
    s = _story(tmp_path)
    s["model"] = "Veo 3.1 Quality"
    assert any("재료" in e for e in st.validate(s, tmp_path))


def test_missing_ref_and_unknown_cast_are_reported(tmp_path):
    s = _story(tmp_path)
    s["cast"][0]["refs"] = ["refs/없음.png"]
    s["shots"][0]["cast"] = ["tong", "ghost"]
    errs = st.validate(s, tmp_path)
    assert any("없다" in e for e in errs) and any("ghost" in e for e in errs)


def test_flow_name_cannot_have_spaces(tmp_path):
    s = _story(tmp_path)
    s["cast"][0]["flow_name"] = "통통 이"
    assert any("띄어쓰기" in e for e in st.validate(s, tmp_path))


# ── 금지어 · 프롬프트 ───────────────────────────────────

def test_gate_blocks_even_negations():
    bad, _ = st.gate("She does not cry. Pixar style.")
    assert len(bad) == 2


def test_gate_warns_on_appearance_and_age():
    _, warn = st.gate("@통통 in his fifties with grey hair")
    assert len(warn) == 2


def test_prompt_uses_tags_and_passes_gate(tmp_path):
    s = _story(tmp_path)
    p = st.build_prompt(s["shots"][0], s)
    assert "@통통 (an adult man)" in p and "@사무실" in p and '"결재 났어"' in p
    assert "9:16" in p and "no on-screen text" in p
    assert st.gate(p)[0] == []                       # 우리 틀 자체가 막히면 안 된다


# ── 패키지 ─────────────────────────────────────────────

def test_package_writes_every_part(tmp_path):
    s = _story(tmp_path)
    out = tmp_path / "pkg"
    r = st.package(s, tmp_path, out)
    assert r["ok"], r
    for rel in ("00_먼저읽기.md", "01_Agent지침.md", "02_캐릭터/통통/기준1.png", "02_캐릭터/통통/설명.txt",
                "03_배경/사무실/기준1.png", "04_장면/S01.txt", "05_Agent_일괄요청.md",
                "06_스토리보드표.md", "07_받은클립", "story.json",
                "08_스토리보드스튜디오/원고.md", "08_스토리보드스튜디오/화풍_커스텀.txt"):
        assert (out / rel).exists(), rel
    saved = json.loads((out / "story.json").read_text(encoding="utf-8"))
    assert Path(saved["cast"][0]["refs"][0]).is_absolute()   # 유사도 검사가 어디서든 찾게


def test_manuscript_lists_place_cast_action_and_lines(tmp_path):
    """Storyboard Studio Script 탭 원고 — 이름이 flow_name 그대로여야 Assets 에서 기준 그림으로 바꿔 끼운다."""
    text = st.manuscript(_story(tmp_path))
    for piece in ("## 장면 1 (S01 · 8초)", "장소: 사무실", "등장: 통통", "행동: walks to the window",
                  "카메라: slow dolly in", '통통: "결재 났어"'):
        assert piece in text, piece


def test_manuscript_prints_detail_fields_when_present(tmp_path):
    """형 지시 09-16 — 이미지 설명·스토리·시간·등장인물·배경을 상세히. 칸이 없으면 옛 원고 그대로."""
    s = _story(tmp_path)
    s["cast_notes"] = [{"name": "통통", "look": "은회색 곱슬머리", "voice": "낮은 남성"}]
    s["place_notes"] = [{"name": "사무실", "look": "창이 큰 방"}]
    s["shots"][0].update({"time": "00:03.0 ~ 00:10.5", "story": "결재 소식", "scene": "통통이 창가로 걸어간다",
                          "people": ["통통 — 은회색 곱슬머리"], "place": "사무실 — 창이 큰 방",
                          "narration": ["결재가 났습니다."], "sound": "lower_third", "transition": "컷",
                          "keep": ["same 3D render", "통통 — big curly grey hair"]})
    text = st.manuscript(s)
    assert "고정: same 3D render" in text and "고정: 통통 — big curly grey hair" in text
    for piece in ("- 인물 통통: 은회색 곱슬머리 · 목소리 낮은 남성", "- 장소 사무실: 창이 큰 방", "시간: 00:03.0 ~ 00:10.5",
                  "이야기: 결재 소식", "배경 모습: 사무실 — 창이 큰 방", "인물 모습: 통통 — 은회색 곱슬머리",
                  "그림: 통통이 창가로 걸어간다", '나레이션: "결재가 났습니다."', "소리: lower_third", "전환: 컷"):
        assert piece in text, piece
    assert "행동:" not in text                                  # 그림 설명이 있으면 영어 행동은 장면 프롬프트에만
    assert "시간:" not in st.manuscript(_story(tmp_path))


def test_prompt_adds_off_screen_voiceover_lines(tmp_path):
    s = _story(tmp_path)
    shot = {**s["shots"][0], "dialogue": [], "voiceover": ["결재가 났습니다.", "내일부터 시작합니다."]}
    p = st.build_prompt(shot, s)
    assert 'nobody in the shot speaks or moves their lips: "결재가 났습니다." "내일부터 시작합니다."' in p
    assert st.gate(p)[0] == []


def test_prompt_puts_voice_line_right_before_dialogue(tmp_path):
    s = _story(tmp_path)
    s["shots"][0]["voice"] = "His voice is a low baritone"
    p = st.build_prompt(s["shots"][0], s)
    assert 'His voice is a low baritone.\n@통통 says in Korean: "결재 났어"' in p
    assert "His voice" not in st.manuscript(s)


def test_style_extra_reaches_manuscript_agent_and_custom_style(tmp_path):
    """형 09-16 — 조연이 실사로 샜다. 인물 화풍 한 줄을 원고·Agent 지침·화풍 커스텀 세 곳에 같이 넣는다."""
    s = {**_story(tmp_path), "style_extra": "Stylized 3D animated characters, not photorealistic."}
    assert "화풍: Stylized 3D animated characters" in st.manuscript(s)
    assert "Every character: Stylized 3D animated" in st.agent_instructions(s, "", "")
    assert "style_extra" not in st.manuscript(_story(tmp_path)) and "화풍:" not in st.manuscript(_story(tmp_path))


def test_readme_warns_autofill_and_save_story(tmp_path):
    readme = st._readme(_story(tmp_path), 1, 1)
    assert "Autofill" in readme and "딴사람" in readme and "Save story" in readme


def test_package_refuses_blocked_prompt(tmp_path):
    s = _story(tmp_path)
    s["shots"][0]["action"] = "hugs his daughter"
    r = st.package(s, tmp_path, tmp_path / "pkg")
    assert not r["ok"] and "S01" in r["blocked"] and not (tmp_path / "pkg").exists()


# ── 변환기 ─────────────────────────────────────────────

MD = """# 스토리보드

| # | 타임코드 | 지속 | 샷/앵글 | 카메라 무브 | 화면 설명(액션) | 조명·색감 | 사운드 | 대사/자막 | 세계관 연결 | 전환 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 0:00–0:03 | 3초 | 와이드 | 슬로우 푸시인 | 창가로 걸어간다 | 아침 햇살 | 새소리 | "결재 났어" | 사무실 | 컷 |
| 2 | 0:03–0:12 | 9초 | 미디엄 | 고정 | 고개를 돌린다 | 역광 | - | - | 사무실 | 디졸브 |

다음 표
"""


def test_markdown_table_becomes_shots():
    shots = ad.from_markdown(MD)
    assert [s["id"] for s in shots] == ["S01", "S02"]
    assert shots[0]["duration"] == 4 and shots[0]["source_seconds"] == 3.0
    assert shots[1]["duration"] == 10
    assert shots[0]["dialogue"] == [{"who": None, "line": "결재 났어"}] and shots[1]["dialogue"] == []
    assert "슬로우 푸시인" in shots[0]["camera"]


def test_folk_board_takes_only_highlights(tmp_path):
    cuts = [[1, 2, "c01", "설명", "a river", "평온", "in", 1, 1, None],
            [3, 4, "c02", "설명", "the king smiles", "긴장", "in", 1, 5, None]]
    script = [("해설", "옛날에", "", 0.3), ("해설", "강이", "", 0.3),
              ("왕", "그러면 보지 못하게 하라", "", 0.3), ("해설", "끝", "", 0.3)]
    shots = ad.from_folk_board(cuts, script, 4)
    assert [s["id"] for s in shots] == ["c02"]
    assert shots[0]["dialogue"] == [{"who": None, "role": "왕", "line": "그러면 보지 못하게 하라"}]


def test_folk_board_also_takes_cuts_with_video(tmp_path):
    """실측: 도미 보드는 등급 칸이 전부 1 — 하이라이트는 video/ 파일 이름으로 표시돼 있다."""
    cuts = [[1, 1, "c01", "설명", "a river", "평온", "in", 1, 1, None],
            [2, 2, "c02", "설명", "a hall", "평온", "in", 1, 1, None]]
    script = [("해설", "옛날에", "", 0.3), ("해설", "궁에서", "", 0.3)]
    (tmp_path / "video").mkdir()
    (tmp_path / "video" / "c02.mp4").write_bytes(b"")
    assert [s["id"] for s in ad.from_folk_board(cuts, script, 4, None, tmp_path / "video")] == ["c02"]


# ── 유사도 ─────────────────────────────────────────────

def test_similarity_same_image_is_high_and_different_is_low(tmp_path):
    """★단색에 가까운 그림 둘은 무늬가 달라도 SSIM 이 0.66 으로 높다(실측) — 다른 그림은 **무늬가 달라야** 한다."""
    a = fs.load_image(_img(tmp_path / "a.png"))
    rng = np.random.default_rng(7)
    noise = Image.fromarray(rng.integers(0, 255, (180, 320, 3), dtype=np.uint8))
    noise.save(tmp_path / "b.png")
    b = fs.load_image(tmp_path / "b.png")
    assert fs.hist_corr(a, a) > 0.99 and fs.ssim(a, a) > 0.99
    assert fs.hist_corr(a, b) < 0.5 and fs.ssim(a, b) < 0.5


def test_orb_handles_blank_image(tmp_path):
    blank = np.full((180, 320, 3), 128, np.uint8)
    a = fs.load_image(_img(tmp_path / "a.png"))
    assert fs.orb_ratio(blank, a) == 0.0
    assert fs.orb_ratio(a, a) > 0.5


def test_flags_only_on_calibrated_metrics():
    """배경·흔들림만 판정한다. 인물(ORB)·첫 프레임(SSIM)은 실측에서 같은 컷/다른 컷이 겹쳐 참고치다."""
    r = {"bg": 0.1, "hold": 0.9, "cast:통통": 0.0, "first": 0.0}
    assert fs.flags(r) == ["bg 0.1 < 0.35"]


def test_timing_line_uses_she_for_female_speaker():
    """형 10-05 — 할머니·깡여사 대사 장면이 「He speaks」로 나가던 것."""
    assert st.timing_line(8, ["안녕하세요."], True, she=True).count("She speaks") == 1
    assert "she closes her mouth" in st.timing_line(8, ["안녕하세요."], True, she=True)
    assert "He speaks" in st.timing_line(8, ["안녕하세요."], True)
