# -*- coding: utf-8 -*-
"""스토리보드 → 구글 Flow 작업 패키지.

캐릭터(@이름) · 배경(@이름) · Agent 지침 · 장면 프롬프트 · 일괄 요청문을 **한 폴더**로 묶는다.
형은 폴더를 열고 순서대로 붙여넣기만 한다(Flow 는 API 가 없는 화면 제품이다).

2026-09-15 공식 도움말로 확인한 Flow 기능 (support.google.com/flow)
- 캐릭터: 그림 1~2장 + 이름 + 목소리 + 설명 → 프롬프트에서 @이름 → 얼굴·옷·목소리 유지
- 재료(Ingredients): 프로젝트에 올린 자산을 @이름으로 부른다 — 배경·소품
- Agent 지침: 프로젝트마다 기준 그림 1장 + 규칙 → 화풍·배경 통일 (Agent 질문은 무료, 생성은 크레딧)
- 모델: 일관성 작업 기본 = Gemini Omni Flash 1.1 (재료 4·6·8·10초 · 360p 초안 반값 · ULTRA 720p 올리기 0크레딧)
  Veo 3.1 Fast·Lite 는 재료가 8초만 · Veo 3.1 Quality 는 재료 불가

금지어는 전부 **실제로 막힌 기록**에서 왔다 (memory feedback-veo-policy-image-first · Flow_캐릭터_활용법.md).
★필터는 부정문도 읽는다 — `does not cry` 의 cry 를 읽는다.

사용:  python flow_story.py <story.json> [--out 받을폴더]
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from datetime import datetime
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

HERE = Path(__file__).resolve().parent
SKILLS = HERE.parent.parent
STYLES = SKILLS / "그림도구" / "styles"
DRAW_SCRIPTS = SKILLS / "그림도구" / "scripts"

MODELS = {
    "Omni Flash 1.1": {"lengths": (4, 6, 8, 10), "ingredients": (4, 6, 8, 10)},
    "Veo 3.1 Fast": {"lengths": (4, 6, 8), "ingredients": (8,)},
    "Veo 3.1 Lite": {"lengths": (4, 6, 8), "ingredients": (8,)},
    "Veo 3.1 Quality": {"lengths": (4, 6, 8), "ingredients": ()},
}
DEFAULT_MODEL = "Omni Flash 1.1"
MAX_REFS = 3          # 한 프롬프트에 붙이는 참조(캐릭터+배경) — Veo 3.1 Ingredients 공식 3장

BLOCK = [
    (r"\b(pixar|disney|marvel|ghibli|dreamworks)\b", "브랜드명 — 서드파티 이권 사유로 거부"),
    (r"lock the character|identity drift|identical person|same person as", "인물 조작 어휘 — 정책 경고"),
    (r"(?<!camera )(?<!lens )\b(do not move at all|stays? completely still|motionless|frozen)\b", "정지 지시 — 죽은 영상"),
    (r"\b(nude|naked|sexy|seductive|lingerie|cleavage)\b", "성적 표현"),
    (r"\b(blood|bloody|gore|corpse|wound|wounded|injured)\b", "상처·폭력"),
    (r"\b(cry|cries|crying|weep|weeps|weeping|sob|sobs|scream|screams|screaming)\b", "울음·비명 — 막힌다(부정문 포함)"),
    (r"\b(touch|touches|touching|embrace|embraces|hug|hugs|kiss|kisses|grab|grabs|reach(es)? out)\b", "접촉 — 막힌다(부정문 포함)"),
    (r"\b(tender|tenderly|gently|softly|sorrow|unconscious|breathing)\b", "막힌 적 있는 낱말 — 안 써도 그림이 한다"),
    (r"\b(child|children|kid|kids|boy|girl|baby|toddler|chibi)\b", "아이로 읽힌다 — young man·young woman·성인 명시로"),
    (r"(울음|울며|흐느|비명|껴안|포옹|입맞춤|시체|피투성이)", "막히는 행위(한국어)"),
]
WARN = [
    (r"\bin (his|her) (twenties|thirties|forties|fifties|sixties)\b|\b\d{2}[- ]year[- ]old\b",
     "나이를 숫자로 — 얼굴이 늙거나 딴사람이 된 적 있다"),
    (r"\b(hair|sunglasses|glasses|wearing)\b", "생김새 재서술 — @캐릭터 그림이 말한다(적으면 글을 따라 새로 그린다)"),
    (r"\b(pull|pulls|pulling|fade|fades)\b", "막힌 적 있는 동작어"),
    (r"(아이|아기|소녀|소년|만지|붙잡|손을 잡)", "아이·접촉으로 읽힐 수 있는 말(한국어)"),
]


# ── 정본 읽기·검사 ─────────────────────────────────────────

def load(path: Path) -> dict:
    story = json.loads(path.read_text(encoding="utf-8"))
    story.setdefault("model", DEFAULT_MODEL)
    story.setdefault("ratio", "16:9")
    story.setdefault("cast", [])
    story.setdefault("locations", [])
    return story


def _ref_paths(item: dict, base: Path) -> list[Path]:
    return [(base / r) if not Path(r).is_absolute() else Path(r) for r in item.get("refs", [])]


def validate(story: dict, base: Path) -> list[str]:
    """고칠 것 목록. 빈 목록이면 패키지를 만들 수 있다."""
    errs: list[str] = []
    if story.get("model") not in MODELS:
        errs.append(f"model 은 {list(MODELS)} 중 하나 — 지금 {story.get('model')!r}")
    if story.get("ratio") not in ("16:9", "9:16"):
        errs.append("ratio 는 16:9 또는 9:16 (Flow 영상은 두 비율뿐)")
    cast = {c.get("id"): c for c in story["cast"]}
    locs = {loc.get("id"): loc for loc in story["locations"]}
    for kind, table, most in (("cast", story["cast"], 2), ("locations", story["locations"], 3)):
        seen = set()
        for it in table:
            name = it.get("flow_name", "")
            if not it.get("id") or it["id"] in seen:
                errs.append(f"{kind}: id 가 없거나 겹친다 — {it.get('id')!r}")
            seen.add(it.get("id"))
            if not name or re.search(r"\s", name):
                errs.append(f"{kind} {it.get('id')}: flow_name 은 띄어쓰기 없이(@{name} 로 부른다)")
            refs = _ref_paths(it, base)
            if not 1 <= len(refs) <= most:
                errs.append(f"{kind} {it.get('id')}: 기준 그림은 1~{most}장 — 지금 {len(refs)}장")
            errs += [f"{kind} {it.get('id')}: 기준 그림이 없다 {r}" for r in refs if not r.exists()]
    lengths = MODELS.get(story.get("model"), MODELS[DEFAULT_MODEL])
    ids = set()
    for s in story.get("shots", []):
        sid = s.get("id")
        if not sid or sid in ids:
            errs.append(f"shot id 가 없거나 겹친다 — {sid!r}")
        ids.add(sid)
        unknown = [c for c in s.get("cast", []) if c not in cast]
        if unknown:
            errs.append(f"{sid}: 대장에 없는 출연 {unknown}")
        if s.get("location") and s["location"] not in locs:
            errs.append(f"{sid}: 대장에 없는 배경 {s['location']!r}")
        uses_refs = bool(s.get("cast") or s.get("location"))
        allowed = lengths["ingredients"] if uses_refs else lengths["lengths"]
        if s.get("duration") not in allowed:
            errs.append(f"{sid}: {story.get('model')} 는 {'재료 쓸 때 ' if uses_refs else ''}"
                        f"{list(allowed)}초만 — 지금 {s.get('duration')}")
        if not s.get("action"):
            errs.append(f"{sid}: action(무엇이 일어나나)이 비었다")
        if s.get("start_frame") and not (base / s["start_frame"]).exists():
            errs.append(f"{sid}: 첫 프레임 그림이 없다 {s['start_frame']}")
    if not story.get("shots"):
        errs.append("shots 가 비었다")
    return errs


def gate(text: str) -> tuple[list[str], list[str]]:
    low = text.lower()
    bad = [f"{why} ← 「{m.group(0)}」" for pat, why in BLOCK for m in [re.search(pat, low)] if m]
    warn = [f"{why} ← 「{m.group(0)}」" for pat, why in WARN for m in [re.search(pat, low)] if m]
    return bad, warn


# ── 프롬프트 ───────────────────────────────────────────────

# ── 길이·초 진행표 — 형 확정 2026-09-20 「영상길이도 프롬프트에 다 넣었어?」 ─────────
CPS = 5.7             # 한국어 초당 글자(나레이션 실측값)
GAP = 0.3             # 문장 사이 쉼
LEAD = 0.5            # 말 시작 전 여유


def _said_chars(text: str) -> int:
    return len(re.sub(r"[^가-힣0-9A-Za-z]", "", text))


def speech_spans(lines: list[str], total: float) -> list[tuple[float, float]]:
    """문장마다 (시작, 끝) 초 — 클립에 다 못 담으면 앞뒤 여유를 줄인다."""
    need = sum(_said_chars(x) / CPS for x in lines) + GAP * (len(lines) - 1)
    clock = LEAD if need + LEAD + 0.3 <= total else max(0.2, (total - need) / 2)
    out = []
    for x in lines:
        end = clock + _said_chars(x) / CPS
        out.append((round(clock, 1), round(end, 1)))
        clock = end + GAP
    return out


def timing_line(total: int, lines: list[str], lipsync: bool, she: bool = False) -> str:
    """길이와 말하는 구간 — 한 문장으로 짧게(긴 지시문은 연기·화질을 밀어낸다 · 형 09-20).

    she = 말하는 인물이 여자(형 10-05 할머니·깡여사 대사 장면 — 「He speaks」로 나가던 것)."""
    spans = speech_spans(lines, total)
    he, his = ("she", "her") if she else ("he", "his")
    who = f"{he.capitalize()} speaks" if lipsync else "The narrator reads"
    tail = (f"{he} closes {his} mouth and holds {his} pose while the camera finishes its move" if lipsync else
            "the shot simply finishes the movement")
    return (f"This clip is exactly {total} seconds. {who} the single Korean sentence below once, starting at "
            f"{spans[0][0]:.1f}s and ending by {spans[-1][1]:.1f}s. Nothing else is said — no second sentence, no "
            f"filler, no repeated words; for the last seconds {tail}.")


def _shot_speech(shot: dict) -> tuple[list[str], bool]:
    if shot.get("voiceover"):
        return [str(x) for x in shot["voiceover"]], False
    line = " ".join(d["line"] for d in shot.get("dialogue", []))
    return [s.strip() for s in re.split(r"(?<=[.?!])\s+", line) if s.strip()], True


def build_prompt(shot: dict, story: dict) -> str:
    """장면 한 컷. 생김새는 적지 않는다 — @캐릭터·@배경 그림이 말한다."""
    cast = {c["id"]: c for c in story["cast"]}
    locs = {loc["id"]: loc for loc in story["locations"]}
    tags = []
    for cid in shot.get("cast", []):
        c = cast[cid]
        tags.append(f"@{c['flow_name']}" + (f" ({c['policy_note']})" if c.get("policy_note") else ""))
    parts = [(" and ".join(tags) + " — " if tags else "") + shot["action"].strip().rstrip(".") + "."]
    said, lipsync = _shot_speech(shot)                 # 길이·초 진행표는 동작 바로 밑(형 확정 09-20)
    if shot.get("duration"):
        she = shot["action"].lstrip().startswith("She ")
        parts.append(timing_line(shot["duration"], said, lipsync, she) if said
                     else f"This clip is exactly {shot['duration']} seconds.")
    if shot.get("body"):                               # 인물 크기가 장면마다 커지던 것(형 09-20)
        parts.append(shot["body"].strip().rstrip(".") + ".")
    if shot.get("silent"):                             # 소리를 다른 클립에서 가져오는 장면
        parts.append("No speech in this clip — only the movement and the room sound.")
    if shot.get("camera"):
        parts.append(f"Camera: {shot['camera'].strip().rstrip('.')}.")
    # ★형 09-21 실측: 「Setting: @자활스튜디오.」 의 @태그를 Flow 가 **벽에 글자로 그렸다**(받은 영상 1).
    #   배경은 아래 Background 한 줄과 첫 프레임 그림이 잡는다 — 프롬프트 글에는 @배경 태그를 쓰지 않는다.
    if shot.get("background") or (shot.get("location") and locs[shot["location"]].get("background")):
        bg = shot.get("background") or locs[shot["location"]]["background"]     # 같은 장소는 늘 같은 문단
        parts.append(f"Background: {bg.strip().rstrip('.')}.")
    if shot.get("light"):
        parts.append(f"Light and color: {shot['light'].strip().rstrip('.')}.")
    if shot.get("voice"):                              # 목소리는 대사 바로 앞 한 줄 — 원고(스토리보드)에는 안 쓴다
        parts.append(shot["voice"].strip().rstrip(".") + ".")
    for d in shot.get("dialogue", []):
        who = f"@{cast[d['who']]['flow_name']}" if d.get("who") in cast else "The speaker"
        parts.append(f'{who} says in Korean: "{d["line"].strip()}"')
    if shot.get("voiceover"):                          # 화면 밖 목소리 — 소리를 영상에서 쓴다(뉴스 09-16)
        parts.append("Off-screen voice-over in Korean — nobody in the shot speaks or moves their lips: "
                     + " ".join(f'"{line.strip()}"' for line in shot["voiceover"]))
    if shot.get("pronounce"):                          # 이름을 잘못 읽던 것(형 09-20 「툭툭」)
        parts.append("Pronounce these Korean words exactly: " + " · ".join(shot["pronounce"]) + ".")
    parts.append("Keep the look of the project style reference and every @reference as uploaded.")
    parts.append(f"{story['ratio']} frame. No subtitles, no captions, no on-screen text.")
    return "\n".join(parts)


# ── 화풍(그림도구) 연결 ────────────────────────────────────

def style_bits(name: str | None) -> tuple[str, str, Path | None]:
    """(화풍 이름, 화풍 문구, 기준 그림 1장). 그림도구 styles 의 정본을 그대로 쓴다."""
    if not name:
        return "", "", None
    sdir = STYLES / name
    style = json.loads((sdir / "style.json").read_text(encoding="utf-8"))
    refs = [(sdir / r) if not Path(r).is_absolute() else Path(r) for r in style.get("refs", [])]
    text = style.get("prompt", "")
    if not text and style.get("prompt_module"):
        sys.path.insert(0, str(DRAW_SCRIPTS))
        import tt_draw                                   # 정본 모듈을 부르는 길은 한 벌만 둔다
        text = tt_draw.build_prompt("", style).strip()
    return style.get("title", name), text, next((r for r in refs if r.exists()), None)


def agent_instructions(story: dict, title: str, text: str) -> str:
    lines = [
        f"Project: {story['title']}.",
        f"Visual style for every image and video in this project: {title or 'see the attached reference'}. "
        "Follow the attached style reference image for rendering, brushwork, color and lighting.",
        "Characters always come from their @character references. Keep each character's design, "
        "costume and proportions as shown in those references. Do not redesign them.",
        "Backgrounds come from their @location references whenever a shot names one.",
        f"Aspect ratio {story['ratio']}. Never add subtitles, captions, logos or any on-screen text.",
        "Ask before generating anything that uses credits.",
    ]
    if text:
        lines.append("Style notes: " + re.sub(r"\s+", " ", text)[:1500])
    if story.get("style_extra"):                       # 인물까지 같은 화풍으로 — 화풍 글만 주면 조연이 실사로 샜다(09-16)
        lines.append("Every character: " + story["style_extra"])
    return "\n".join(lines)


# ── Storyboard Studio 원고 ─────────────────────────────────

def manuscript(story: dict) -> str:
    """Script 탭에 붙일 원고 — 장면마다 장소·등장인물·행동·대사를 따로 줄로 적어 Flow 가 나누기 쉽게.

    ★인물·장소 이름은 **flow_name 그대로** — Assets 탭에서 우리 기준 그림으로 바꿔 끼울 때 이름이 맞아야 한다.
    """
    cast = {c["id"]: c["flow_name"] for c in story["cast"]}
    locs = {loc["id"]: loc["flow_name"] for loc in story["locations"]}
    out = [f"# {story['title']}", ""]
    if story.get("style_extra"):
        out += [f"화풍: {story['style_extra']}", ""]
    if story["cast"]:
        out.append("등장인물: " + ", ".join(c["flow_name"] + (f" — {c['info']}" if c.get("info") else "")
                                         + (f" · 목소리 {c['voice']}" if c.get("voice") else "")
                                         for c in story["cast"]))
    if story["locations"]:
        out.append("장소: " + ", ".join(loc["flow_name"] for loc in story["locations"]))
    # ★형 지시(2026-09-16) — 스토리보드에는 이미지 설명·스토리·시간·등장인물·배경을 상세히. 칸이 있으면 적는다
    out += [f"- 인물 {c['name']}: {c['look']}" + (f" · 목소리 {c['voice']}" if c.get("voice") else "")
            for c in story.get("cast_notes", [])]
    out += [f"- 장소 {p['name']}: {p['look']}" for p in story.get("place_notes", [])]
    for n, s in enumerate(story["shots"], 1):
        out += ["", f"## 장면 {n} ({s['id']} · {s['duration']}초)"]
        out += [f"{label}: {s[key]}" for key, label in (("time", "시간"), ("story", "이야기")) if s.get(key)]
        if s.get("location"):
            out.append(f"장소: {locs[s['location']]}")
        if s.get("place"):
            out.append(f"배경 모습: {s['place']}")
        if s.get("cast"):
            out.append("등장: " + ", ".join(cast[c] for c in s["cast"]))
        out += [f"인물 모습: {p}" for p in s.get("people", [])]
        # ★한국어 그림 설명이 있으면 영어 행동 문장은 장면 프롬프트(04_장면)에만 — 원고가 두 벌로 길어진다
        if s.get("scene"):
            out.append(f"그림: {s['scene']}")
        else:
            out.append(f"행동: {s['action'].strip()}")
        out += [f"고정: {k}" for k in s.get("keep", [])]      # 장면마다 화풍·인물 고정 표식 — 그림이 달라지지 않게(09-16)
        if s.get("camera"):
            out.append(f"카메라: {s['camera'].strip()}")
        if s.get("light"):
            out.append(f"빛: {s['light'].strip()}")
        for d in s.get("dialogue", []):
            who = cast.get(d.get("who")) or d.get("role") or "화자"
            out.append(f'{who}: "{d["line"].strip()}"')
        out += [f'나레이션: "{line}"' for line in s.get("narration", [])]
        out += [f"{label}: {s[key]}" for key, label in (("sound", "소리"), ("transition", "전환")) if s.get(key)]
    return "\n".join(out) + "\n"


# ── 패키지 ─────────────────────────────────────────────────

def _copy(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def _readme(story: dict, n_char: int, n_loc: int) -> str:
    return f"""# {story['title']} — Flow 작업 순서

만든 때 {datetime.now():%Y-%m-%d %H:%M} · 장면 {len(story['shots'])}개 · 캐릭터 {n_char} · 배경 {n_loc}

## 경로 A — Storyboard Studio (대본에서 그림까지 한 번에)
1. flow.google.com → 새 프로젝트 「{story['title']}」 → **도구** → **Storyboard Studio**
2. 화풍: 프리셋 대신 **커스텀** → `08_스토리보드스튜디오/화풍_커스텀.txt` 붙여넣기(+ `01_화풍기준` 그림)
3. **Script 탭**: `08_스토리보드스튜디오/원고.md` 붙여넣기 → 장면·대사·행동이 제대로 나뉘었는지 한 번 본다
4. **Assets 탭 — 캐릭터**: ⛔Autofill 로 생긴 인물 그림은 **새로 그린 딴사람**이다
   → `02_캐릭터/<이름>/기준*.png` 로 **그림을 교체**하고 이름을 폴더 이름과 맞춘다
   장소는 `03_배경/<이름>/` 이 있으면 그 그림으로 교체
5. **⋯ → Save story** — ⛔안 누르고 끝내면 만든 그림·자산이 사라질 수 있다. 탭을 넘길 때마다 누른다
6. **Storyboard 탭**: Autofill scene → 장면 그림 확인(컷 수 조절) → 다시 **Save story**
7. **영상**: 모든 미디어 → 장면 그림을 프롬프트에 추가 → **Agent** 켜기 →
   `04_장면/S01.txt` 붙여넣기(@캐릭터·@배경이 들어 있다) → Generate
8. 아래 경로 B 의 8·9 단계(받은 클립 검사 · 720p 올리기)

## 경로 B — 직접 (캐릭터 @ · Agent 지침)
1. flow.google.com → **새 프로젝트** 이름 「{story['title']}」
2. 프롬프트 칸 → 모델 **{story['model']}** · 비율 **{story['ratio']}** · 해상도 **360p(초안, 크레딧 절반)**
3. **Agent 지침**: 프롬프트 칸 아래 Agent Instructions → Add instruction →
   `01_화풍기준.png` 올리고 `01_Agent지침.md` 내용을 붙여넣기 → Done
4. **캐릭터**: 왼쪽 Characters → New Character → `02_캐릭터/<이름>/` 그림 1~2장 올리기 →
   이름은 **폴더 이름 그대로**(프롬프트의 @이름) → 목소리 선택 → `설명.txt` 붙이기 → Done
5. **배경**: `03_배경/<이름>/` 그림을 올리고 자산 이름을 **폴더 이름 그대로** 바꾼다(@이름으로 부른다)
6. (선택) **첫 프레임 그림**: Agent 켜고 `05_Agent_일괄요청.md` 붙여넣기 — 생성 전 확인이 뜨면 크레딧을 보고 누른다
7. **장면**: `04_장면/S01.txt` … 를 차례로 붙여넣고 Video Ingredients 로 Generate
   (첫 프레임 그림이 있는 장면은 Video Frames 에 그 그림을 넣어도 된다)
8. 받은 영상 이름을 **장면 번호 그대로**(예 `S01.mp4`) → `07_받은클립/` 에 넣고
   `python flow_similarity.py "{{이 폴더}}"` 로 흔들린 컷을 찾는다
9. 마음에 드는 360p 만 **720p 올리기(ULTRA 0크레딧)**

## 같이 쓰면 좋은 Flow 공식 도구 (프로젝트 → 도구 · 제작 Google)
- **Style Writer** — 무드보드 → 화풍 문구 (통통그림체 기준 그림을 넣어 커스텀 화풍 문구를 뽑는다)
- **Scene Explorer · Shot Explorer** — 한 장소를 다른 각도로 → 배경이 컷마다 달라지지 않게
- **Story Sketch** — 정한 화풍으로 스토리보드 · **Stringout Creator** — 클립 이어 붙이기

⛔생김새를 프롬프트에 다시 적지 않는다 · ⛔다른 캐릭터 그림으로 바꿔 올리지 않는다(그 컷만 딴사람)
⛔Storyboard Studio 는 **프로젝트 안 「도구」에서 연다(제작 Google)**. 검색에 걸리는 공유 링크 판은
  「다른 사용자가 만든 앱」 경고가 뜨고 링크 가진 사람이 데이터를 볼 수 있다 — 그 판에는 대본을 넣지 않는다
"""


def package(story: dict, base: Path, out: Path) -> dict:
    errs = validate(story, base)
    prompts = {s["id"]: build_prompt(s, story) for s in story.get("shots", [])} if not errs else {}
    blocked, warned = {}, {}
    for sid, p in prompts.items():
        bad, warn = gate(p)
        if bad:
            blocked[sid] = bad
        if warn:
            warned[sid] = warn
    if errs or blocked:
        return {"ok": False, "errors": errs, "blocked": blocked, "warnings": warned}

    out.mkdir(parents=True, exist_ok=True)
    title, text, style_ref = style_bits(story.get("style"))
    (out / "01_Agent지침.md").write_text(agent_instructions(story, title, text), encoding="utf-8")
    if style_ref:
        _copy(style_ref, out / f"01_화풍기준{style_ref.suffix.lower()}")
    for kind, folder in (("cast", "02_캐릭터"), ("locations", "03_배경")):
        for it in story[kind]:
            d = out / folder / it["flow_name"]
            for i, r in enumerate(_ref_paths(it, base), 1):
                _copy(r, d / f"기준{i}{r.suffix.lower()}")
            info = [f"이름: {it['flow_name']}"] + ([f"목소리: {it['voice']}"] if it.get("voice") else []) \
                   + ([f"설명: {it['info']}"] if it.get("info") else [])
            (d / "설명.txt").write_text("\n".join(info) + "\n", encoding="utf-8")
    scenes = out / "04_장면"
    scenes.mkdir(exist_ok=True)
    for s in story["shots"]:
        (scenes / f"{s['id']}.txt").write_text(prompts[s["id"]] + "\n", encoding="utf-8")
        if s.get("start_frame"):
            src = base / s["start_frame"]
            _copy(src, scenes / f"{s['id']}_첫프레임{src.suffix.lower()}")
    cast = {c["id"]: c for c in story["cast"]}
    locs = {loc["id"]: loc for loc in story["locations"]}

    def tags(s: dict) -> str:
        t = [f"@{cast[c]['flow_name']}" for c in s.get("cast", [])]
        return " ".join(t + ([f"@{locs[s['location']]['flow_name']}"] if s.get("location") else []))

    batch = [f"아래 {len(story['shots'])}개 장면의 **첫 프레임 그림**을 한 장씩 만들어 주세요.",
             f"- 이미지 모델 Nano Banana Pro · 비율 {story['ratio']} · 화면에 글자 없음",
             "- 인물은 @캐릭터 참조, 배경은 @배경 참조를 그대로 쓰세요",
             f"- 그림 이름을 장면 번호(S01…)로 바꾸고 「{story['title']} 첫프레임」 컬렉션에 넣어 주세요",
             "- 생성 전에 확인을 받아 주세요", ""]
    batch += [f"{s['id']} — {tags(s)} : {s['action'].strip()}" for s in story["shots"]]
    (out / "05_Agent_일괄요청.md").write_text("\n".join(batch) + "\n", encoding="utf-8")
    table = ["| 번호 | 길이 | 참조 | 무엇이 일어나나 | 카메라 | 대사 |", "|---|---|---|---|---|---|"]
    for s in story["shots"]:
        lines = " / ".join(d["line"] for d in s.get("dialogue", []))
        table.append(f"| {s['id']} | {s['duration']}초 | {tags(s)} | {s['action'].strip()} | "
                     f"{s.get('camera', '')} | {lines} |")
    (out / "06_스토리보드표.md").write_text("\n".join(table) + "\n", encoding="utf-8")
    studio = out / "08_스토리보드스튜디오"
    studio.mkdir(exist_ok=True)
    (studio / "원고.md").write_text(manuscript(story), encoding="utf-8")
    flat = re.sub(r"[ \t]+", " ", text).strip()          # ★3.11 은 f-string 안 역슬래시를 못 쓴다 — 밖에서 계산
    extra = ("\n\n" + story["style_extra"]) if story.get("style_extra") else ""
    (studio / "화풍_커스텀.txt").write_text(
        (title + "\n\n" + flat + extra + "\n") if text else
        "화풍 정본이 지정되지 않았다 — story.json 의 style 에 통통그림체 이름을 적는다\n", encoding="utf-8")
    (out / "07_받은클립").mkdir(exist_ok=True)
    (out / "07_받은클립" / "넣는법.txt").write_text(
        "Flow 에서 받은 영상을 장면 번호 이름(S01.mp4 …)으로 이 폴더에 둔다.\n", encoding="utf-8")
    (out / "00_먼저읽기.md").write_text(_readme(story, len(story["cast"]), len(story["locations"])),
                                    encoding="utf-8")
    saved = dict(story)
    for kind in ("cast", "locations"):
        saved[kind] = [{**it, "refs": [str(p) for p in _ref_paths(it, base)]} for it in story[kind]]
    saved["shots"] = [{**s, **({"start_frame": str(base / s["start_frame"])} if s.get("start_frame") else {})}
                      for s in story["shots"]]
    (out / "story.json").write_text(json.dumps(saved, ensure_ascii=False, indent=1), encoding="utf-8")
    return {"ok": True, "errors": [], "blocked": {}, "warnings": warned, "out": str(out)}


def main() -> int:
    ap = argparse.ArgumentParser(description="스토리보드 → 구글 Flow 작업 패키지")
    ap.add_argument("story")
    ap.add_argument("--out")
    a = ap.parse_args()
    path = Path(a.story).resolve()
    story = load(path)
    out = Path(a.out) if a.out else (
        Path.home() / "Downloads" / f"플로우_{re.sub(r'[^0-9A-Za-z가-힣]+', '_', story['title'])}_{datetime.now():%m%d_%H%M}")
    r = package(story, path.parent, out)
    for e in r["errors"]:
        print("❌", e)
    for sid, bad in r["blocked"].items():
        print(f"⛔{sid}", "; ".join(bad))
    for sid, warn in r["warnings"].items():
        print(f"⚠️ {sid}", "; ".join(warn))
    if not r["ok"]:
        print("→ 패키지를 만들지 않았다. 위를 고치고 다시 돌린다")
        return 1
    print(f"✅ 패키지 {r['out']}  (장면 {len(story['shots'])} · 경고 {len(r['warnings'])})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
