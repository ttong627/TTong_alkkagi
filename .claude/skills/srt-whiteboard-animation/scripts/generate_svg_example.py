# -*- coding: utf-8 -*-
"""Phase A — 설날 아침 장면의 벡터(SVG) 소스 생성기.

annotation.json 의 element id 와 1:1 로 대응하는 <g id="..."> 그룹을 가진
SVG 를 출력한다. 각 그룹은:
  - class="stroke" : 펜이 따라 그릴 윤곽 path (compile_hyperframes.py 가
                     stroke-dashoffset 리빌 + 펜 추적에 사용)
  - class="fill"   : 잉크 단계 후 서서히 나타날 채색 도형

사용법:
  <ENV_PY> scripts/generate_svg_example.py [출력.svg]
"""
import math
import sys
from pathlib import Path

INK = "#3E3832"

P = []  # SVG 조각 누적


def path(d, cls="stroke", stroke=INK, width=5, fill="none", extra=""):
    if cls == "stroke":
        P.append(f'<path class="stroke" d="{d}" fill="none" stroke="{stroke}" '
                 f'stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round" {extra}/>')
    else:
        P.append(f'<path class="fill" d="{d}" fill="{fill}" stroke="none" {extra}/>')


def q(p0, p1, p2):
    return f"M {p0[0]:.0f} {p0[1]:.0f} Q {p1[0]:.0f} {p1[1]:.0f} {p2[0]:.0f} {p2[1]:.0f}"


def poly(pts, close=False):
    d = f"M {pts[0][0]:.0f} {pts[0][1]:.0f} " + " ".join(f"L {x:.0f} {y:.0f}" for x, y in pts[1:])
    return d + (" Z" if close else "")


def circle_path(cx, cy, r):
    return (f"M {cx - r:.0f} {cy:.0f} "
            f"A {r:.0f} {r:.0f} 0 1 1 {cx + r:.0f} {cy:.0f} "
            f"A {r:.0f} {r:.0f} 0 1 1 {cx - r:.0f} {cy:.0f} Z")


def scallop(cx, cy, rx, ry, bumps):
    pts = []
    for i in range(bumps * 10 + 1):
        a = 2 * math.pi * i / (bumps * 10)
        wob = 1.0 + 0.11 * math.sin(a * bumps)
        pts.append((cx + rx * wob * math.cos(a), cy + ry * wob * math.sin(a)))
    return poly(pts, close=True)


# ══ 1. 초가집 ═══════════════════════════════════════════════════
P.append('<g id="thatched-house">')
path(poly([(110, 838), (700, 838), (700, 884), (110, 884)], close=True), "fill", fill="#C9B896")  # 흙길
path(poly([(160, 660), (160, 830), (520, 830), (520, 660)], close=True), "fill", fill="#EFE3C8")   # 벽
path("M 112 668 Q 340 470 568 668 Z", "fill", fill="#D9A96A")                                      # 지붕
path("M 130 668 Q 340 590 550 668 Z", "fill", fill="#C08F4F")                                      # 지붕 음영
path(poly([(300, 698), (300, 830), (386, 830), (386, 698)], close=True), "fill", fill="#F7F0DC")   # 문
path(poly([(206, 700), (206, 762), (276, 762), (276, 700)], close=True), "fill", fill="#F7F0DC")   # 창
path(poly([(444, 606), (444, 522), (486, 522), (486, 612)], close=True), "fill", fill="#8B6238")   # 굴뚝
for jx, jw, jh in ((580, 44, 74), (628, 52, 84), (678, 38, 66)):                                   # 장독
    path(poly([(jx - jw / 2, 790), (jx - jw / 2 - 7, 790 + jh / 3), (jx - jw / 2 + 4, 790 + jh),
               (jx + jw / 2 - 4, 790 + jh), (jx + jw / 2 + 7, 790 + jh / 3), (jx + jw / 2, 790)],
              close=True), "fill", fill="#7A5233")
# 윤곽 (그리는 순서: 지붕 → 벽 → 문 → 창 → 굴뚝 → 연기 → 장독 → 지면)
path("M 112 668 Q 340 492 568 668", width=6)
path(poly([(112, 668), (568, 668)]), width=5)
path(poly([(160, 660), (160, 830), (520, 830), (520, 660)]), width=5)
path(poly([(300, 698), (300, 830), (386, 830), (386, 698), (300, 698)]), width=4)
path(poly([(343, 700), (343, 828)]), width=3)
path(poly([(206, 700), (206, 762), (276, 762), (276, 700), (206, 700)]), width=4)
path(poly([(241, 700), (241, 762)]), width=3)
path(poly([(444, 606), (444, 522), (486, 522), (486, 612)]), width=5)
path("M 465 508 Q 438 474 468 448 Q 494 428 470 424", width=4, stroke="#B9B2A6")
path("M 483 502 Q 500 472 486 446", width=3, stroke="#B9B2A6")
for jx, jw, jh in ((580, 44, 74), (628, 52, 84), (678, 38, 66)):
    path(poly([(jx - jw / 2, 790), (jx - jw / 2 - 7, 790 + jh / 3), (jx - jw / 2 + 4, 790 + jh),
               (jx + jw / 2 - 4, 790 + jh), (jx + jw / 2 + 7, 790 + jh / 3), (jx + jw / 2, 790),
               (jx - jw / 2, 790)]), width=4)
path(poly([(115, 860), (695, 862)]), width=3)
P.append("</g>")

# ══ 2. 소나무 + 까치 ════════════════════════════════════════════
P.append('<g id="pine-magpie">')
path(poly([(1060, 844), (1540, 844), (1540, 886), (1060, 886)], close=True), "fill", fill="#C9B896")
path("M 1296 858 Q 1246 640 1288 470 Q 1308 400 1266 338 L 1314 342 Q 1356 410 1336 480 Q 1304 650 1350 858 Z",
     "fill", fill="#7A5233")
path(scallop(1262, 252, 152, 80, 10), "fill", fill="#4E7A46")
path(scallop(1452, 350, 96, 58, 8), "fill", fill="#4E7A46")
path(scallop(1116, 322, 80, 47, 7), "fill", fill="#4E7A46")
path(scallop(1218, 228, 66, 34, 5), "fill", fill="#6B9A5B")
# 윤곽
path("M 1296 858 Q 1246 640 1288 470 Q 1308 400 1266 338", width=6)
path("M 1350 858 Q 1304 650 1336 480 Q 1356 410 1314 342", width=6)
path("M 1284 468 Q 1212 444 1150 452", width=5)
path("M 1330 428 Q 1408 398 1462 406", width=5)
path(scallop(1262, 252, 152, 80, 10), width=5)
path(scallop(1452, 350, 96, 58, 8), width=5)
path(scallop(1116, 322, 80, 47, 7), width=4)
# 까치
path(circle_path(1170, 420, 27), "fill", fill="#FAF6EC")
path("M 1146 370 A 15 15 0 1 1 1145 371 Z", "fill", fill="#2E2B29")
path(poly([(1190, 426), (1246, 444), (1242, 454), (1188, 440)], close=True), "fill", fill="#2E2B29")
path("M 1162 410 Q 1186 402 1194 424 L 1172 430 Z", "fill", fill="#4A6FA5")
path(circle_path(1170, 420, 27), width=4)
path(circle_path(1146, 398, 15), width=4)
path(poly([(1133, 396), (1121, 402)]), width=4)
path(poly([(1193, 426), (1242, 446)]), width=4)
path(poly([(1162, 446), (1162, 452)]), width=3)
path(poly([(1176, 446), (1176, 452)]), width=3)
path(poly([(1075, 864), (1530, 862)]), width=3)
P.append("</g>")

# ══ 3. 아이 + 방패연 ════════════════════════════════════════════
cx0, cy0 = 810, 575
P.append('<g id="child-kite">')
path(poly([(cx0 - 52, cy0 + 112), (cx0 - 70, cy0 + 252), (cx0 + 70, cy0 + 252), (cx0 + 52, cy0 + 112)],
          close=True), "fill", fill="#C94F42")   # 치마
path(poly([(cx0 - 44, cy0 + 40), (cx0 - 52, cy0 + 114), (cx0 + 52, cy0 + 114), (cx0 + 44, cy0 + 40)],
          close=True), "fill", fill="#F2C94C")   # 저고리
path(circle_path(cx0, cy0, 38), "fill", fill="#F6D7B8")                              # 얼굴
path(f"M {cx0-38} {cy0-8} A 38 38 0 0 1 {cx0+38} {cy0-8} L {cx0+30} {cy0-24} L {cx0-30} {cy0-24} Z",
     "fill", fill="#2E2B29")                                                          # 머리
path(poly([(842, 141), (916, 141), (916, 269), (842, 269)], close=True), "fill", fill="#FAF5E8")  # 연 (852±64 → 788..916? kw=128 kh=158, kx=852 ky=205 → 788..916 x, 126..284 y)
P[-1] = P[-1].replace('d="M 842 141', 'd="M 788 126').replace("916 141", "916 126").replace("916 269", "916 284").replace("842 269", "788 284")
path(poly([(788, 126), (822, 126), (788, 160)], close=True), "fill", fill="#C94F42")
path(poly([(916, 126), (882, 126), (916, 160)], close=True), "fill", fill="#4A6FA5")
path(poly([(916, 284), (882, 284), (916, 250)], close=True), "fill", fill="#E8A33D")
path(poly([(788, 284), (822, 284), (788, 250)], close=True), "fill", fill="#4E7A46")
# 윤곽 (그리는 순서: 연 → 연줄 → 머리 → 몸 → 팔 → 치마)
path(poly([(788, 126), (916, 126), (916, 284), (788, 284), (788, 126)]), width=5)
path(poly([(788, 126), (916, 284)]), width=3)
path(poly([(916, 126), (788, 284)]), width=3)
path(poly([(852, 126), (852, 284)]), width=3)
path(circle_path(852, 205, 25), width=5, stroke="#C94F42")
path("M 846 284 Q 812 415 908 531", width=3)                                          # 연줄
path(circle_path(cx0, cy0, 38), width=4)
path(poly([(cx0 - 44, cy0 + 40), (cx0 - 52, cy0 + 114), (cx0 + 52, cy0 + 114), (cx0 + 44, cy0 + 40), (cx0 - 44, cy0 + 40)]), width=4)
path(f"M {cx0+40} {cy0+54} Q {cx0+84} {cy0+8} {cx0+96} {cy0-40}", width=8)            # 오른팔
path(f"M {cx0-40} {cy0+54} Q {cx0-68} {cy0+92} {cx0-60} {cy0+128}", width=8)          # 왼팔
path(poly([(cx0 + 84, cy0 - 58), (cx0 + 84, cy0 - 28), (cx0 + 112, cy0 - 28), (cx0 + 112, cy0 - 58), (cx0 + 84, cy0 - 58)]), width=3)
path(poly([(cx0 - 52, cy0 + 112), (cx0 - 70, cy0 + 252), (cx0 + 70, cy0 + 252), (cx0 + 52, cy0 + 112)]), width=4)
path(poly([(cx0 - 41, cy0 + 252), (cx0 - 41, cy0 + 268), (cx0 - 8, cy0 + 268)]), width=4)
path(poly([(cx0 + 41, cy0 + 252), (cx0 + 41, cy0 + 268), (cx0 + 60, cy0 + 268)]), width=4)
# 고름 (빨강 포인트)
path(poly([(cx0 - 3, cy0 + 55), (cx0 - 5, cy0 + 100)]), width=5, stroke="#B33C34")
path(poly([(cx0 + 7, cy0 + 55), (cx0 + 9, cy0 + 92)]), width=4, stroke="#B33C34")
P.append("</g>")

# ══ 4. 해 ═══════════════════════════════════════════════════════
P.append('<g id="rising-sun">')
path(circle_path(235, 185, 66), "fill", fill="#E2543F")
path(circle_path(227, 177, 41), "fill", fill="#F0924F")
path(circle_path(235, 185, 66), width=5, stroke="#B23A2C")
for a in range(0, 360, 30):
    x0 = 235 + 78 * math.cos(math.radians(a))
    y0 = 185 + 78 * math.sin(math.radians(a))
    ln = 26 if a % 60 == 0 else 15
    x1 = 235 + (78 + ln) * math.cos(math.radians(a))
    y1 = 185 + (78 + ln) * math.sin(math.radians(a))
    path(poly([(x0, y0), (x1, y1)]), width=4, stroke="#E8A33D")
P.append("</g>")

svg = (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 900" width="1600" height="900">\n'
    '<rect width="1600" height="900" fill="#F5EBD7"/>\n'
    + "\n".join(P)
    + "\n</svg>\n"
)

out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "examples" / "scene-01-seollal.svg"
out.write_text(svg, encoding="utf-8")
print(f"OUTPUT={out}")
