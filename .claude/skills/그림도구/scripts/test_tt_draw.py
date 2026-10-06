# -*- coding: utf-8 -*-
"""그리기 도구 배관 — 실제로 그림을 뽑지 않는다(코덱스·안티그라비티를 부르지 않는다)."""
import json
import sys
import types
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import tt_draw as td  # noqa: E402


def test_imports_the_copy_next_to_this_test():
    assert Path(td.__file__).resolve().parent == HERE


def test_prompt_puts_scene_first_then_fixed_style():
    p = td.build_prompt("  a boat  ", {"prompt": "STYLE BLOCK"})
    assert p == "a boat\n\nSTYLE BLOCK"


def test_prompt_module_calls_the_canonical_style(monkeypatch):
    """통통그림체0 은 folk_style.py 가 정본이다 — 문구를 복사하지 않고 그 build() 를 부른다."""
    fake = types.SimpleNamespace(build=lambda scene: f"CANON|{scene}")
    monkeypatch.setitem(sys.modules, "fake_canon_style", fake)
    assert td.build_prompt(" boat ", {"prompt_module": "fake_canon_style"}) == "CANON|boat"


def test_prompt_attr_takes_one_line_from_the_canonical_module(monkeypatch):
    """통통그림체3 은 자활 정본 _jahwal_char.LOOK 한 줄만 쓴다 — 복사하지 않는다."""
    fake = types.SimpleNamespace(LOOK="Stylized 3D LOOK")
    monkeypatch.setitem(sys.modules, "fake_look_style", fake)
    style = {"prompt_module": "fake_look_style", "prompt_attr": "LOOK"}
    assert td.build_prompt("boss", style) == "boss\n\nStylized 3D LOOK"


def test_codex_args_keep_message_before_images(tmp_path):
    """-i 는 여러 값을 받는다 — 글이 뒤에 오면 그림 파일로 먹힌다."""
    ref = tmp_path / "ref.png"
    args = td.codex_args("scene", [ref], "16:9")
    i = args.index("exec")
    assert args[i + 1] == "--skip-git-repo-check"
    assert "scene" in args[i + 2]
    assert args[i + 3:] == ["-i", str(ref)]


def test_codex_without_refs_has_no_image_flag():
    assert "-i" not in td.codex_args("scene", [], "1:1")


def test_ref_note_is_per_style(tmp_path):
    """기준 그림에서 무엇을 따를지는 그림체마다 다르다 — 수묵 문구가 코드에 박히면 안 된다."""
    msg = td.codex_args("scene", [tmp_path / "r.png"], "16:9", "인물 입체감·민화 배경")[-3]
    assert "인물 입체감·민화 배경" in msg and "먹 번짐" not in msg


def test_draw_codex_copies_the_newest_generated_image(tmp_path, monkeypatch):
    gen = tmp_path / "generated"
    monkeypatch.setattr(td, "CODEX_IMAGES", gen)

    def fake_run(args, **kw):
        (gen / "s1").mkdir(parents=True)
        Image.new("RGB", (8, 8), (240, 235, 220)).save(gen / "s1" / "exec-1.png")
        return types.SimpleNamespace(returncode=0, stdout="done", stderr="")

    monkeypatch.setattr(td.subprocess, "run", fake_run)
    out = td.draw_codex("scene", [], "16:9", tmp_path / "out" / "통통그림체1_01")
    assert out == tmp_path / "out" / "통통그림체1_01.png" and out.exists()


def test_printed_path_wins_over_a_newer_file(tmp_path, monkeypatch):
    """동시에 뽑을 때 — 코덱스가 찍은 경로가 남의 더 새 파일보다 우선이다."""
    gen = tmp_path / "generated"
    (gen / "mine").mkdir(parents=True)
    (gen / "other").mkdir(parents=True)
    mine = gen / "mine" / "exec-a.png"
    Image.new("RGB", (8, 8)).save(mine)
    Image.new("RGB", (8, 8)).save(gen / "other" / "exec-b.png")   # 나중에 생긴 남의 그림
    monkeypatch.setattr(td, "CODEX_IMAGES", gen)
    assert td.printed_image(f"작업 끝\n{mine}\n", 0.0) == mine


BASE_STYLES = ["통통그림체0", "통통그림체1", "통통그림체2", "통통그림체3"]   # 형 기본 화풍 네 개 (2026-09-15)


def test_all_four_base_styles_are_registered_and_whole():
    """형의 기본 화풍 네 개가 **하나도 빠지지 않고**, 문구·기준 그림·숫자 범위를 다 갖췄는지."""
    for name in BASE_STYLES:
        sdir = HERE.parent / "styles" / name
        style = json.loads((sdir / "style.json").read_text(encoding="utf-8"))
        assert style["name"] == name
        assert set(style["ranges"]) == {"paper", "sat", "ink", "color"}, name
        assert style.get("prompt") or style.get("prompt_module"), f"{name} 문구 정본이 없다"
        assert style["refs"], f"{name} 기준 그림이 없다"
        for r in style["refs"]:
            assert (sdir / r).exists(), f"{name} 기준 그림 없음: {r}"


def test_canonical_modules_are_not_copied():
    """정본이 따로 있는 그림체(0·3)는 문구를 json 에 복사하지 않는다 — 두 벌이 되면 어긋난다."""
    for name, mod in (("통통그림체0", "folk_style"), ("통통그림체3", "_jahwal_char")):
        style = json.loads((HERE.parent / "styles" / name / "style.json").read_text(encoding="utf-8"))
        assert style["prompt_module"] == mod and "prompt" not in style


def test_style_one_prompt_blocks_text():
    style = json.loads((HERE.parent / "styles" / "통통그림체1" / "style.json").read_text(encoding="utf-8"))
    assert "no lettering" in style["prompt"]
