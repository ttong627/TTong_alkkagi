# -*- coding: utf-8 -*-
"""그림체 숫자 검사 — 먹 그림은 통과하고, 총천연색은 걸리는지 잠근다."""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import style_check as sc  # noqa: E402

INK_RANGES = {"paper": [0.35, 1.0], "sat": [0.0, 0.22], "ink": [0.002, 0.30], "color": [0.0, 30.0]}


def test_imports_the_copy_next_to_this_test():
    assert Path(sc.__file__).resolve().parent == HERE


def _ink_painting(p):
    im = Image.new("RGB", (800, 450), (238, 232, 218))          # 한지 빛 종이
    d = ImageDraw.Draw(im)
    for i in range(12):                                          # 붓 획
        d.line([(60 + i * 55, 380), (120 + i * 50, 90)], fill=(25, 25, 25), width=9)
    d.ellipse([600, 60, 640, 100], fill=(190, 70, 50))           # 붉은 점 하나
    im.save(p)
    return p


def _full_color(p):
    x = np.linspace(0, 1, 800)
    rgb = np.stack([np.tile(x, (450, 1)), np.tile(x[::-1], (450, 1)),
                    np.full((450, 800), 0.9)], axis=-1)
    Image.fromarray((rgb * 255).astype("uint8")).save(p)
    return p


def test_ink_painting_passes(tmp_path):
    m = sc.metrics(_ink_painting(tmp_path / "ink.png"))
    assert sc.judge(m, INK_RANGES) == [], m


def test_full_color_image_is_caught(tmp_path):
    m = sc.metrics(_full_color(tmp_path / "color.png"))
    off = sc.judge(m, INK_RANGES)
    assert any(o.startswith(("sat", "color", "paper")) for o in off), m


def test_judge_names_the_metric_and_range():
    off = sc.judge({"paper": 0.1, "sat": 0.1, "ink": 0.01, "color": 5.0}, INK_RANGES)
    assert off == ["paper 0.1 (기준 0.35~1.0)"]
