# -*- coding: utf-8 -*-
"""Stitch MCP 중계기 — Stitch 를 실제로 부르지 않는다(post 를 가짜로 바꾼다)."""
import json
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import stitch_mcp_proxy as sp  # noqa: E402

FAKE_KEY = "AQ.fake-key-for-tests-0000000000"

SCHEMA = {
    "type": "object",
    "properties": {
        "screen": {"$ref": "#/$defs/ScreenInstance"},
        "screens": {"type": "array", "items": {"$ref": "#/$defs/ScreenInstance"}},
    },
    "$defs": {
        "ScreenInstance": {"type": "object", "properties": {"id": {"type": "string"},
                                                            "size": {"$ref": "#/$defs/Size"}}},
        "Size": {"type": "string", "enum": ["MOBILE", "DESKTOP"]},
    },
}


def test_imports_the_copy_next_to_this_test():
    assert Path(sp.__file__).resolve().parent == HERE


def test_deref_removes_every_reference():
    out = sp.deref(SCHEMA)
    text = json.dumps(out)
    assert "$ref" not in text and "$defs" not in text
    assert out["properties"]["screen"]["properties"]["size"]["enum"] == ["MOBILE", "DESKTOP"]
    assert out["properties"]["screens"]["items"]["properties"]["id"]["type"] == "string"


def test_deref_does_not_touch_the_original():
    before = json.dumps(SCHEMA, sort_keys=True)
    sp.deref(SCHEMA)
    assert json.dumps(SCHEMA, sort_keys=True) == before


def test_deref_stops_on_a_reference_loop():
    loop = {"$ref": "#/$defs/A", "$defs": {"A": {"type": "object",
                                                  "properties": {"next": {"$ref": "#/$defs/A"}}}}}
    out = sp.deref(loop)                          # 끝나기만 하면 된다 — 무한 반복이면 테스트가 멈춘다
    assert "$ref" not in json.dumps(out)


def test_fix_tools_only_changes_schemas():
    reply = {"jsonrpc": "2.0", "id": 1,
             "result": {"tools": [{"name": "get_screen", "description": "d", "inputSchema": SCHEMA}],
                        "nextCursor": "x"}}
    out = sp.fix_tools(reply)
    tool = out["result"]["tools"][0]
    assert tool["name"] == "get_screen" and tool["description"] == "d"
    assert out["result"]["nextCursor"] == "x"
    assert "$ref" not in json.dumps(tool["inputSchema"])


@pytest.fixture
def key(monkeypatch):
    monkeypatch.setattr(sp, "api_key", lambda: FAKE_KEY)
    sp._state.clear()


def test_notification_returns_nothing(key, monkeypatch):
    sent = []
    monkeypatch.setattr(sp, "post", lambda m: (sent.append(m) or (202, "", "")))
    assert sp.handle({"jsonrpc": "2.0", "method": "notifications/initialized"}) == []
    assert sent, "알림도 Stitch 로는 넘겨야 한다"


def test_tools_list_comes_back_flattened(key, monkeypatch):
    body = json.dumps({"jsonrpc": "2.0", "id": 7,
                       "result": {"tools": [{"name": "t", "inputSchema": SCHEMA}]}})
    monkeypatch.setattr(sp, "post", lambda m: (200, body, "application/json; charset=UTF-8"))
    out = sp.handle({"jsonrpc": "2.0", "id": 7, "method": "tools/list"})
    assert out[0]["id"] == 7 and "$ref" not in json.dumps(out)


def test_event_stream_reply_is_read(key, monkeypatch):
    body = 'event: message\ndata: {"jsonrpc":"2.0","id":3,"result":{}}\n\n'
    monkeypatch.setattr(sp, "post", lambda m: (200, body, "text/event-stream"))
    assert sp.handle({"jsonrpc": "2.0", "id": 3, "method": "ping"}) == [
        {"jsonrpc": "2.0", "id": 3, "result": {}}]


def test_initialize_remembers_protocol_version(key, monkeypatch):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "result": {"protocolVersion": "2025-06-18"}})
    monkeypatch.setattr(sp, "post", lambda m: (200, body, "application/json"))
    sp.handle({"jsonrpc": "2.0", "id": 1, "method": "initialize"})
    assert sp._state["protocol"] == "2025-06-18"


def test_error_message_never_shows_the_key(key, monkeypatch):
    monkeypatch.setattr(sp, "post", lambda m: (403, f"bad key {FAKE_KEY}", "text/plain"))
    out = sp.handle({"jsonrpc": "2.0", "id": 9, "method": "tools/call"})
    assert FAKE_KEY not in json.dumps(out) and "[KEY]" in out[0]["error"]["message"]


def test_missing_key_gives_a_clear_error(monkeypatch):
    monkeypatch.setattr(sp, "api_key", lambda: "")
    out = sp.handle({"jsonrpc": "2.0", "id": 1, "method": "tools/list"})
    assert "stitch_key_gui.ps1" in out[0]["error"]["message"]
