# -*- coding: utf-8 -*-
"""Stitch MCP 중계기 — Claude Code 가 Stitch 도구를 못 읽는 문제를 푼다.

2026-09-15 실측: **키는 통한다**(initialize 200 · tools/list 200 · 도구 15개).
그런데 Claude Code 는 「Connected · tools fetch failed」였다.
  Issue: can't resolve reference #/$defs/ScreenInstance from id #
Stitch 도구 설명서(inputSchema)가 `$ref: #/$defs/…` 로 서로를 가리키는데
Claude Code 의 검사기가 그 참조를 풀지 못한다. 키 문제도 OAuth 문제도 아니다.

⇒ 이 중계기가 Claude Code 와 Stitch 사이에 선다.
  ① 요청은 그대로 Stitch 로 넘긴다 — 키는 환경변수 STITCH_API_KEY 에서만 읽고 **어디에도 찍지 않는다**
  ② tools/list 응답만 `$ref` 를 풀어 **펼친 설명서**로 바꿔 돌려준다
외부 패키지 없음(표준 라이브러리만).

등록:  claude mcp add -s user stitch -- <python.exe> <이 파일>
키:    그림도구/scripts/stitch_key_gui.ps1 (붙여넣기 창)
"""
from __future__ import annotations

import json
import os
import sys
import threading
import urllib.error
import urllib.request

URL = "https://stitch.googleapis.com/mcp"
TIMEOUT = 600          # 화면 생성은 몇 분 걸릴 수 있다
MAX_DEPTH = 12         # 서로를 가리키는 참조가 끝없이 돌지 않게

_out = threading.Lock()
_state: dict[str, str] = {}


def api_key() -> str:
    """환경변수 → 없으면 Windows 사용자 환경변수(레지스트리). 앱을 다시 켜기 전에도 돈다."""
    k = os.environ.get("STITCH_API_KEY", "").strip()
    if k:
        return k
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as h:
            return str(winreg.QueryValueEx(h, "STITCH_API_KEY")[0]).strip()
    except OSError:
        return ""


def deref(schema, defs: dict | None = None, depth: int = 0):
    """`$ref: #/$defs/이름` 을 그 정의로 바꿔 끼운 **새** 설명서. 원본은 건드리지 않는다."""
    if isinstance(schema, list):
        return [deref(x, defs, depth) for x in schema]
    if not isinstance(schema, dict):
        return schema
    defs = {**(defs or {}), **schema.get("$defs", {}), **schema.get("definitions", {})}
    ref = schema.get("$ref")
    if isinstance(ref, str) and ref.startswith(("#/$defs/", "#/definitions/")):
        rest = {k: v for k, v in schema.items() if k != "$ref"}
        name = ref.rsplit("/", 1)[-1]
        if name in defs and depth < MAX_DEPTH:
            return deref({**defs[name], **rest}, defs, depth + 1)
        return deref({"type": "object", **rest}, defs, depth)   # 못 풀면 느슨한 객체로 둔다
    return {k: deref(v, defs, depth) for k, v in schema.items()
            if k not in ("$defs", "definitions")}


def fix_tools(reply: dict) -> dict:
    """tools/list 응답에서 설명서만 펼친다. 나머지는 그대로."""
    tools = reply.get("result", {}).get("tools")
    if not isinstance(tools, list):
        return reply
    fixed = []
    for t in tools:
        t2 = dict(t)
        for field in ("inputSchema", "outputSchema"):
            if isinstance(t2.get(field), dict):
                t2[field] = deref(t2[field])
        fixed.append(t2)
    return {**reply, "result": {**reply["result"], "tools": fixed}}


def hide_key(text: str) -> str:
    k = api_key()
    return text.replace(k, "[KEY]") if k else text


def error(msg: dict, text: str) -> dict:
    return {"jsonrpc": "2.0", "id": msg.get("id"),
            "error": {"code": -32000, "message": hide_key(text)}}


def post(payload: dict) -> tuple[int, str, str]:
    """Stitch 로 한 번 보낸다 → (상태, 본문, Content-Type)."""
    hdr = {"Content-Type": "application/json",
           "Accept": "application/json, text/event-stream",
           "X-Goog-Api-Key": api_key()}
    if _state.get("session"):
        hdr["Mcp-Session-Id"] = _state["session"]
    if _state.get("protocol"):
        hdr["MCP-Protocol-Version"] = _state["protocol"]
    req = urllib.request.Request(URL, data=json.dumps(payload).encode("utf-8"),
                                 headers=hdr, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            if r.headers.get("Mcp-Session-Id"):
                _state["session"] = r.headers["Mcp-Session-Id"]
            return r.status, r.read().decode("utf-8", "replace"), r.headers.get("Content-Type", "")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace"), e.headers.get("Content-Type", "") if e.headers else ""


def parse(body: str, ctype: str) -> list[dict]:
    """JSON 한 덩어리 또는 SSE(data: 줄들) → 메시지 목록."""
    if "text/event-stream" in ctype or body.lstrip().startswith(("event:", "data:")):
        return [json.loads(line[5:]) for line in body.splitlines()
                if line.startswith("data:") and line[5:].strip()]
    d = json.loads(body)
    return d if isinstance(d, list) else [d]


def handle(msg: dict) -> list[dict]:
    """요청 하나 → Claude Code 에 돌려줄 메시지들. 알림(id 없음)은 아무것도 돌려주지 않는다."""
    has_id = "id" in msg
    if not api_key():
        return [error(msg, "STITCH_API_KEY 가 없다 — 그림도구 stitch_key_gui.ps1 로 키를 넣을 것")] if has_id else []
    status, body, ctype = post(msg)
    if not has_id:
        return []
    if status >= 400 or not body.strip():
        return [error(msg, f"Stitch HTTP {status}: {body[:300]}")]
    try:
        replies = parse(body, ctype)
    except ValueError as e:
        return [error(msg, f"Stitch 응답을 못 읽었다: {e}")]
    if msg.get("method") == "initialize":
        ver = replies[0].get("result", {}).get("protocolVersion") if replies else None
        if ver:
            _state["protocol"] = ver
    if msg.get("method") == "tools/list":
        replies = [fix_tools(r) for r in replies]
    return replies


def _serve(msg: dict) -> None:
    try:
        replies = handle(msg)
    except Exception as e:                      # 중계기가 죽으면 Claude Code 쪽 도구가 통째로 사라진다
        replies = [error(msg, f"중계기 오류: {type(e).__name__}: {e}")] if "id" in msg else []
    with _out:
        for r in replies:
            sys.stdout.write(json.dumps(r, ensure_ascii=False) + "\n")
        sys.stdout.flush()


def main() -> int:
    for stream in (sys.stdin, sys.stdout):
        try:
            stream.reconfigure(encoding="utf-8", newline="\n")
        except (AttributeError, ValueError):
            pass
    workers: list[threading.Thread] = []
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        for one in (msg if isinstance(msg, list) else [msg]):
            th = threading.Thread(target=_serve, args=(one,), daemon=True)
            th.start()
            workers.append(th)
    for th in workers:                           # 입력이 끝나도 진행 중인 요청은 마저 돌려준다
        th.join(timeout=TIMEOUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
