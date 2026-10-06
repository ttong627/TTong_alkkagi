"""스킬 정밀 점검 — check_skills.py(겉모양) 다음 단계. 실제로 돌아가는지를 본다.

A. 딸린 스크립트 문법(파이썬 컴파일·node --check·bash -n)
B. 부르는 MCP 서버가 설치돼 있는가(mcp__서버__도구 · 「context7」「jina-reader」 같은 이름)
C. 부르는 에이전트가 있는가(subagent_type·`이름` 에이전트)
D. 본문이 가리키는 `/스킬`·`/명령` 이 있는가
E. 발동어 충돌 — 같은 「발동어」가 여러 스킬 설명에 있는가
F. 프로젝트 스킬이 부르는 파이썬 함수(sl.xxx( 등)가 코드에 정의돼 있는가

사용: python deep_check.py --project D:\\Gemma4
종료 코드: ❌ 가 있으면 1.
"""
from __future__ import annotations

import argparse
import json
import py_compile
import re
import shutil
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

HOME = Path.home() / ".claude"
SKIP = {"synced", ".venv", "node_modules", "__pycache__", "tests"}
# 앱·하네스에 내장된 MCP 서버(설정 파일에 안 나온다)
BUILTIN_MCP = {
    "claude-in-chrome", "computer-use", "Claude_Browser", "visualize", "scheduled-tasks", "mcp-registry",
    "terminal", "ccd_session", "ccd_session_mgmt", "ccd_view", "ccd_pr", "ccd_sidebar", "ccd_window",
    "ccd_directory", "ccd_connectors", "ccd_host", "ccd_settings",
}
BUILTIN_AGENTS = {"general-purpose", "Explore", "Plan", "claude", "claude-code-guide", "statusline-setup"}
BUILTIN_CMDS = {
    "loop", "schedule", "compact", "model", "run", "simplify", "clear", "init", "review", "config", "doctor",
    "mcp", "help", "memory", "context", "agents", "hooks", "permissions", "login", "logout", "resume",
    "fast", "effort", "skills", "plugin", "status", "cost", "ultrareview", "update-config", "keybindings-help",
    "fewer-permission-prompts", "claude-api", "workflow-authoring", "rc", "batch", "ralph-loop",
    "rewind", "design-login", "design-sync", "export", "add-dir", "ide", "vim", "bug",
}
# 이름으로 불리는 MCP(도구 접두어 없이 글로 적는 경우)
NAMED_MCP = {"context7": "context7", "jina-reader": "jina-reader", "prompts.chat": "prompts-chat"}


def installed_mcp(project: Path) -> set[str]:
    names = set(BUILTIN_MCP)
    try:
        d = json.loads((Path.home() / ".claude.json").read_text(encoding="utf-8"))
        names |= set(d.get("mcpServers", {}))
        for p, v in d.get("projects", {}).items():
            if Path(p).name.lower() in (project.name.lower(), "gemma4"):
                names |= set(v.get("mcpServers", {}))
    except (OSError, ValueError):
        pass
    for f in (project / ".mcp.json", Path(r"D:\Gemma4\.mcp.json")):
        if f.exists():
            names |= set(json.loads(f.read_text(encoding="utf-8")).get("mcpServers", {}))
    # 플러그인 MCP 는 서버 이름이 plugin_<플러그인>_<서버> 꼴 — 접두어만으로 인정
    names |= {"plugin"}
    return names


def docs(project: Path) -> list[tuple[str, Path, str]]:
    """(종류, 파일, 글) — 전역 스킬·명령·프로젝트 스킬의 모든 .md."""
    out = []
    for kind, root in (("전역", HOME / "skills"), ("명령", HOME / "commands"), ("프로젝트", project / ".claude" / "skills")):
        if not root.exists():
            continue
        for f in root.rglob("*.md"):
            if SKIP & set(f.parts):
                continue
            out.append((kind, f, f.read_text(encoding="utf-8", errors="ignore")))
    return out


def owner(f: Path) -> str:
    parts = f.parts
    for key in ("skills", "commands"):
        if key in parts:
            i = len(parts) - 1 - parts[::-1].index(key)
            return parts[i + 1].removesuffix(".md") if i + 1 < len(parts) else f.stem
    return f.stem


def git_bash() -> str:
    """Git Bash 를 고른다 — PATH 의 bash 는 WSL(System32\\bash.exe)일 수 있고 그건 C:/ 경로를 못 본다."""
    for c in (r"C:\Program Files\Git\bin\bash.exe", r"C:\Program Files\Git\usr\bin\bash.exe"):
        if Path(c).exists():
            return c
    return shutil.which("bash") or "bash"


def check_scripts(project: Path, errs: list, warns: list) -> int:
    node = shutil.which("node")
    bash = git_bash()
    n = 0
    roots = [HOME / "skills", project / ".claude" / "skills"]
    for root in roots:
        for f in root.rglob("*"):
            if not f.is_file() or SKIP & set(f.parts) or "scripts" not in f.parts:
                continue
            n += 1
            try:
                if f.suffix == ".py":
                    py_compile.compile(str(f), doraise=True, cfile=str(Path.home() / ".cache" / "deep_check.pyc"))
                elif f.suffix in (".js", ".cjs", ".mjs") and node:
                    r = subprocess.run([node, "--check", str(f)], capture_output=True, text=True, timeout=20)
                    if r.returncode:
                        raise RuntimeError(r.stderr.strip().splitlines()[-1] if r.stderr else "node --check 실패")
                elif f.suffix == ".sh":
                    # 윈도우 경로(C:\...)를 bash 에 주면 역슬래시가 사라진다 → C:/... 로
                    r = subprocess.run([bash, "-n", f.as_posix()], capture_output=True, text=True, timeout=20)
                    if r.returncode:
                        raise RuntimeError(r.stderr.strip()[:120])
                else:
                    n -= 1
            except Exception as e:  # noqa: BLE001 — 어떤 실패든 보고
                errs.append(f"[A 스크립트] {owner(f)}: {f.name} — {str(e).splitlines()[0][:110]}")
    return n


def check_refs(project: Path, errs: list, warns: list) -> None:
    mcp = installed_mcp(project)
    agents = {p.stem for p in (HOME / "agents").glob("*.md")} | BUILTIN_AGENTS
    skills = {p.name for p in (HOME / "skills").iterdir() if (p / "SKILL.md").exists()}
    skills |= {p.name for p in (project / ".claude" / "skills").iterdir() if (p / "SKILL.md").exists()} if (project / ".claude" / "skills").exists() else set()
    cmds = {p.stem for p in (HOME / "commands").glob("*.md")}
    plugin_skills = set()
    for pj in (HOME / "plugins" / "cache").rglob("SKILL.md"):
        plugin_skills.add(pj.parent.name)
    for pj in (HOME / "plugins" / "cache").rglob("commands/*.md"):
        plugin_skills.add(pj.stem)
    everything = skills | cmds | BUILTIN_CMDS | plugin_skills

    seen: set[tuple] = set()
    for kind, f, t in docs(project):
        o = owner(f)
        body = re.sub(r"<!--.*?-->", "", t, flags=re.S)
        live = [ln for ln in body.splitlines() if not re.search(r"⛔|금지|없다|없음|지웠|삭제|옛 |쓰지 않", ln)]
        text = "\n".join(live)
        # B. MCP
        for m in re.finditer(r"mcp__([A-Za-z0-9_.-]+?)__", text):
            s = m.group(1)
            if s not in mcp and not s.startswith("plugin") and not re.fullmatch(r"[0-9a-f-]{36}", s):
                key = ("B", o, s)
                if key not in seen:
                    seen.add(key)
                    errs.append(f"[B MCP] {o}: 없는 MCP 서버 `{s}` 를 부른다")
        named_text = "\n".join(ln for ln in body.splitlines() if not re.search(r"설치 안|설치돼 있지 않|미설치|없다|없음", ln))
        for word, srv in NAMED_MCP.items():
            if re.search(rf"(?<![\w-]){re.escape(word)}(?![\w-])", named_text) and srv not in mcp:
                key = ("B", o, srv)
                if key not in seen:
                    seen.add(key)
                    warns.append(f"[B MCP] {o}: 「{word}」 MCP 를 쓰라고 하지만 설치돼 있지 않다")
        # C. 에이전트
        for m in re.finditer(r"subagent_type[\"'=:\s]+[\"']?([A-Za-z][\w:-]+)", text):
            a = m.group(1)
            if a not in agents and ":" not in a and not a.endswith("-"):  # hc-<이름> 같은 틀은 제외
                key = ("C", o, a)
                if key not in seen:
                    seen.add(key)
                    errs.append(f"[C 에이전트] {o}: 없는 에이전트 `{a}`")
        for m in re.finditer(r"`([a-z][a-z0-9-]{2,})`\s*(?:에이전트|agent)", text):
            a = m.group(1)
            if a not in agents:
                key = ("C", o, a)
                if key not in seen:
                    seen.add(key)
                    warns.append(f"[C 에이전트] {o}: `{a}` 에이전트가 없다")
        # D. /스킬·/명령 — 본문(SKILL.md·명령 파일)만, 명령 이름 모양(한글 또는 소문자-하이픈)만.
        # 원문 생태계 명령(/spec·/build 등)을 옮겨 온 스킬은 「스킬점검:원문명령허용」 표시로 면제.
        is_top = f.name == "SKILL.md" or f.parent.name == "commands"
        if not is_top or "스킬점검:원문명령허용" in t:
            continue
        for m in re.finditer(r"`/([가-힣][가-힣\w-]*|[a-z][a-z0-9-]*)`", text):
            s = m.group(1)
            if s in everything or re.search(r"(?:v\d|예시|예:|제안|→)", text[max(0, m.start() - 40):m.start()]):
                continue
            key = ("D", o, s)
            if key not in seen:
                seen.add(key)
                warns.append(f"[D 연결] {o}: `/{s}` 는 스킬·명령 목록에 없다")


def check_triggers(project: Path, warns: list) -> None:
    trig = defaultdict(set)
    for kind, f, t in docs(project):
        if f.name != "SKILL.md" and "commands" not in f.parts:
            continue
        m = re.match(r"^\ufeff?---\r?\n(.*?)\r?\n---", t, re.S)
        if not m:
            continue
        d = re.search(r"^description:\s*(.*?)(?=^\w[\w-]*:|\Z)", m.group(1), re.S | re.M)
        if not d:
            continue
        desc = d.group(1).strip()
        if desc[:1] in "\"'" and desc[-1:] == desc[:1]:  # 설명 전체를 감싼 따옴표는 벗긴다
            desc = desc[1:-1]
        for p in re.findall(r"「([^」]{2,20})」|“([^”]{2,20})”|\"([^\"]{2,20})\"", desc):
            p = next(x for x in p if x)
            p = p.strip().lower()
            if len(p) >= 2 and not p.startswith("/"):
                trig[p].add(owner(f))
    for p, owners in sorted(trig.items()):
        if len(owners) > 1:
            warns.append(f"[E 발동어] 「{p}」 가 여러 곳에: {', '.join(sorted(owners))}")


def check_functions(project: Path, errs: list) -> None:
    code_root = project / "tongtong_studio"
    if not code_root.exists():
        return
    alias = {"sl": "studio_lib"}
    defs_cache: dict[str, set[str] | None] = {}

    def defs_of(mod: str) -> set[str] | None:
        if mod not in defs_cache:
            f = code_root / f"{mod}.py"
            if not f.exists():
                defs_cache[mod] = None
            else:
                src = f.read_text(encoding="utf-8", errors="ignore")
                defs_cache[mod] = set(re.findall(r"^\s*(?:async\s+)?def\s+(\w+)|^(\w+)\s*=", src, re.M) and
                                      [a or b for a, b in re.findall(r"^\s*(?:async\s+)?def\s+(\w+)|^(\w+)\s*=", src, re.M)])
        return defs_cache[mod]

    root = project / ".claude" / "skills"
    for f in root.rglob("SKILL.md"):
        t = f.read_text(encoding="utf-8", errors="ignore")
        for m in re.finditer(r"\b([a-z_][a-z0-9_]*)\.([a-z_][a-z0-9_]*)\(", t):
            mod, fn = alias.get(m.group(1), m.group(1)), m.group(2)
            ds = defs_of(mod)
            if ds is not None and fn not in ds:
                errs.append(f"[F 함수] {owner(f)}: `{m.group(1)}.{fn}()` — {mod}.py 에 정의 없음")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", default=".")
    a = ap.parse_args()
    project = Path(a.project).resolve()
    errs: list[str] = []
    warns: list[str] = []
    n = check_scripts(project, errs, warns)
    check_refs(project, errs, warns)
    check_triggers(project, warns)
    check_functions(project, errs)
    print(f"■ 정밀 점검 — 스크립트 {n}개 문법 검사 · 참조·발동어·함수 대조")
    for e in sorted(set(errs)):
        print(f"  ❌ {e}")
    for w in sorted(set(warns)):
        print(f"  ⚠️ {w}")
    print(f"■ 합계: 오류 {len(set(errs))} · 주의 {len(set(warns))}")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
