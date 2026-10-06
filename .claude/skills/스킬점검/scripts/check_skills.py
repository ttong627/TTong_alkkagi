"""설치된 클로드 스킬·명령을 점검한다 — 끊긴 참조·빈 껍데기·유료 키·python3·형 규칙 충돌·설명 길이.

사용:
    python check_skills.py                 # 전역(~/.claude) + 현재 폴더의 .claude/skills
    python check_skills.py --project D:\\Gemma4
    python check_skills.py --json          # 기계용 출력

종료 코드: 오류(❌) 가 하나라도 있으면 1, 아니면 0.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

HOME = Path.home() / ".claude"
SKIP_PARTS = {"synced", ".venv", "node_modules", "__pycache__", ".git"}
DESC_HARD = 1024      # 명세 상한
DESC_WARN = 400       # 매 대화 실리는 글 — 이보다 길면 줄일 후보
LIST_CUT = 1536       # 목록에서 잘리는 길이(description+when_to_use)
# 스킬 폴더가 아니라 **프로젝트에 만들어질** 출력 파일 이름 — 없어도 정상
PROJECT_OUTPUTS = {"assets/design-tokens.json"}

SUPPORT_REF = re.compile(r"(?<![\w/.-])((?:references|scripts|assets|data|templates|examples)/[A-Za-z0-9_./-]+\.(?:md|py|csv|json|js|cjs|mjs|sh|html|txt|ts))")
ABS_REF = re.compile(r"(?<![\w/])([A-Za-z]:[\\/][^\s`'\"|)<>*]+?\.(?:json|py|ps1|bat|mjs|js|md|vbs|sh))(?![\w])")
HOME_REF = re.compile(r"(~/\.claude/[^\s`'\"|)<>*]+?\.(?:json|py|mjs|js|md|sh))(?![\w])")
PY3 = re.compile(r"(?:^|[\s`;&|(])python3(?:\s|`|$)")
PAID = re.compile(r"GEMINI_API_KEY|GOOGLE_API_KEY|OPENAI_API_KEY|ELEVENLABS_API_KEY|REPLICATE_API_TOKEN|generativelanguage\.googleapis\.com")
# 이 표시가 있는 줄은 「하지 마라」는 규칙 문장이지 위반이 아니다
GUARD = re.compile(r"⛔|금지|쓰지 말|쓰지 않|유료|형 규칙|말 것|멈춘다|멈춤|가짜 파일")
CONFLICT = [
    (re.compile(r"\bPROACTIVELY\b|MUST BE USED"), "자동 발동 강제 문구(형 09-14 「부를 때만」과 충돌)"),
    (re.compile(r"Wait for (user )?(confirmation|approval)|MUST receive user approval|승인 전까지 코드", re.I), "승인 대기 문구(형 「묻지 말고 끝까지」와 충돌)"),
    (re.compile(r"\bWebFetch\b"), "WebFetch 사용(형 금지 — 세션 멈춤)"),
    (PY3, "python3 로 실행 — 형 PC 에선 스토어 가짜 파일이라 멈춘다(python 으로)"),
]


@dataclass
class Item:
    kind: str             # skill | command
    name: str
    path: Path
    errors: list[str] = field(default_factory=list)
    warns: list[str] = field(default_factory=list)
    desc_len: int = 0
    model_invoked: bool = True


def yaml_error(text: str) -> str:
    """\uba38\ub9ac\ub9d0\uc774 YAML \ub85c \uc548 \uc77d\ud788\uba74 \uc774\uc720\ub97c \ub3cc\ub824\uc900\ub2e4(\uc77d\ud788\uba74 \ube48 \uae00). \uae68\uc9c0\uba74 \uc124\uba85 \uc804\uccb4\uac00 \ubb34\uc2dc\ub418\uace0 \ubaa9\ub85d\uc5d0 \uccab \uc81c\ubaa9\ub9cc \ub72c\ub2e4."""
    m = re.match(r"^\ufeff?---\r?\n(.*?)\r?\n---", text, re.S)
    if not m:
        return ""
    try:
        import yaml  # PyYAML \uc5c6\uc73c\uba74 \uac80\uc0ac\ub97c \uac74\ub108\ub6f4\ub2e4
    except ImportError:
        return ""
    try:
        d = yaml.safe_load(m.group(1))
        return "" if isinstance(d, dict) else "\uba38\ub9ac\ub9d0\uc774 \ud0a4: \uac12 \ubaa8\uc591\uc774 \uc544\ub2d8"
    except yaml.YAMLError as e:
        return str(e).splitlines()[0][:70]


def frontmatter(text: str) -> tuple[dict, str]:
    m = re.match(r"^\ufeff?---\r?\n(.*?)\r?\n---\r?\n?", text, re.S)
    if not m:
        return {}, text
    head, body = m.group(1), text[m.end():]
    meta: dict[str, str] = {}
    key = None
    for ln in head.splitlines():
        km = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", ln)
        if km:
            key = km.group(1)
            meta[key] = km.group(2).strip()
        elif key and (ln.startswith(" ") or ln.startswith("\t")):
            meta[key] = (meta[key] + " " + ln.strip()).strip()
    for k, v in meta.items():
        if v[:1] in "\"'" and v[-1:] == v[:1]:
            meta[k] = v[1:-1]
        elif v.startswith((">", "|")):
            meta[k] = v[1:].lstrip("-+ ").strip()
    return meta, body


def exists_any(p: str, base: Path, project: Path | None) -> bool:
    p = p.rstrip(".,:;")
    cands: list[Path] = []
    if p.startswith("~/"):
        cands.append(Path.home() / p[2:])
    elif re.match(r"[A-Za-z]:", p):
        cands.append(Path(p.replace("/", "\\")))
    else:
        cands.append(base / p)
        if project:
            cands.append(project / p)
    return any(c.exists() for c in cands)


def check_text(it: Item, text: str, base: Path, project: Path | None) -> None:
    code_free = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    miss_support = sorted({m.group(1) for m in SUPPORT_REF.finditer(code_free) if m.group(1) not in PROJECT_OUTPUTS and not (base / m.group(1)).exists()})
    if miss_support:
        it.errors.append(f"딸린 파일 없음 {len(miss_support)}개: {', '.join(miss_support[:4])}{' …' if len(miss_support) > 4 else ''}")
    miss_abs = sorted({
        m.group(1) for pat in (ABS_REF, HOME_REF) for m in pat.finditer(code_free)
        if not any(ch in m.group(1) for ch in "<{$*…") and not exists_any(m.group(1), base, project)
    })
    if miss_abs:
        it.warns.append(f"가리키는 경로 없음 {len(miss_abs)}개: {', '.join(miss_abs[:3])}{' …' if len(miss_abs) > 3 else ''}")
    # 형이 직접 불러 질문을 받는 명령(예: /프로그램제작 인터뷰)은 이 표시로 「승인 대기」 검사를 면제한다
    ask_ok = "스킬점검:묻기허용" in text
    live = [ln for ln in code_free.splitlines() if not GUARD.search(ln)]
    paid = [ln for ln in live if PAID.search(ln)]
    if paid:
        it.errors.append(f"유료 키 사용 문구(막는 말 없음) {len(paid)}줄: {paid[0].strip()[:90]}")
    for pat, why in CONFLICT:
        if ask_ok and why.startswith("승인 대기"):
            continue
        if any(pat.search(ln) for ln in live):
            it.warns.append(why)


def scan_skills(root: Path, project: Path | None) -> list[Item]:
    items: list[Item] = []
    if not root.exists():
        return items
    for d in sorted(p for p in root.iterdir() if p.is_dir() and p.name not in SKIP_PARTS):
        f = d / "SKILL.md"
        it = Item("skill", d.name, d)
        if not f.exists():
            it.warns.append("SKILL.md 없음 — 스킬로 인식되지 않는 폴더")
            items.append(it)
            continue
        text = f.read_text(encoding="utf-8", errors="ignore")
        meta, body = frontmatter(text)
        if not meta:
            it.errors.append("머리말(---) 없음")
        elif err := yaml_error(text):
            it.errors.append(f"머리말 YAML 오류(설명이 무시된다 — 값에 대괄호·콜론이면 따옴표로): {err}")
        name = meta.get("name", "")
        if name and name != d.name:
            it.warns.append(f"name({name}) ≠ 폴더 이름({d.name})")
        desc = (meta.get("description", "") + " " + meta.get("when_to_use", "")).strip()
        it.desc_len = len(desc)
        it.model_invoked = meta.get("disable-model-invocation", "").lower() not in ("true", "yes", "on", "1")
        if not desc:
            it.errors.append("description 없음 — 언제 쓰는지 모델이 모른다")
        elif len(meta.get("description", "")) > DESC_HARD:
            it.errors.append(f"description {len(meta['description'])}자 > {DESC_HARD}")
        elif it.model_invoked and len(desc) > DESC_WARN:
            it.warns.append(f"설명 {len(desc)}자 — 매 대화 실린다, 줄일 후보")
        if len(body.splitlines()) > 500:
            it.warns.append(f"본문 {len(body.splitlines())}줄 > 500 — references/ 로 나눌 후보")
        check_text(it, text, d, project)
        items.append(it)
    return items


def scan_commands(root: Path, project: Path | None) -> list[Item]:
    items: list[Item] = []
    if not root.exists():
        return items
    for f in sorted(root.glob("*.md")):
        text = f.read_text(encoding="utf-8", errors="ignore")
        meta, _ = frontmatter(text)
        it = Item("command", f.stem, f)
        it.desc_len = len(meta.get("description", ""))
        if not meta:
            it.warns.append("머리말 없음 — 목록에 첫 줄 제목만 뜬다(description 추가 권장)")
        elif err := yaml_error(text):
            it.errors.append(f"머리말 YAML 오류(설명이 무시된다 — 값에 대괄호·콜론이면 따옴표로): {err}")
        check_text(it, text, root, project)
        items.append(it)
    return items


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", default=".", help="프로젝트 폴더(.claude/skills 를 같이 본다)")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    project = Path(a.project).resolve()
    groups = {
        "전역 스킬": scan_skills(HOME / "skills", project),
        "전역 명령": scan_commands(HOME / "commands", project),
        f"프로젝트 스킬({project.name})": scan_skills(project / ".claude" / "skills", project),
    }
    if a.json:
        print(json.dumps({g: [dict(kind=i.kind, name=i.name, errors=i.errors, warns=i.warns, desc_len=i.desc_len) for i in its] for g, its in groups.items()}, ensure_ascii=False, indent=1))
    n_err = n_warn = 0
    listing = 0
    for g, its in groups.items():
        e = sum(len(i.errors) for i in its)
        w = sum(len(i.warns) for i in its)
        n_err += e
        n_warn += w
        listing += sum(i.desc_len for i in its if i.model_invoked)
        if a.json:
            continue
        print(f"\n■ {g} {len(its)}개 — 오류 {e} · 주의 {w}")
        for i in its:
            for m in i.errors:
                print(f"  ❌ {i.name}: {m}")
            for m in i.warns:
                print(f"  ⚠️ {i.name}: {m}")
    if not a.json:
        print(f"\n■ 합계: 오류 {n_err} · 주의 {n_warn} · 매 대화 실리는 설명 약 {listing:,}자")
    return 1 if n_err else 0


if __name__ == "__main__":
    sys.exit(main())
