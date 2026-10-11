#!/usr/bin/env python3
"""재미나이(Gemini API)로 그림·소리를 뽑는 도구 — GitHub Actions(gemini-assets.yml)에서 돈다.

키는 환경 변수 GEMINI_API_KEY 로만 받는다(화면·기록에 찍지 않는다).

쓰는 법:
  python tools/gemini/run.py probe            # 모델 목록 + 공식 문서를 받아 gen_out/probe 에 둔다
  python tools/gemini/run.py job <이름>       # tools/gemini/jobs/<이름>.json 의 일을 차례로 한다

일 파일(JSON) 한 줄 = 한 번 부르기:
  {"id": "...", "model": "모델 이름", "method": "generateContent" 등,
   "body": {... REST 본문 그대로 ...},
   "images": ["보낼 그림 경로", ...]   # (선택) body.contents[0].parts 뒤에 그림을 붙인다
   "out": "gen_out/폴더/이름"          # 확장자는 받은 형식으로 붙인다
   "n": 2}                             # (선택) 같은 요청을 몇 번
응답에 inlineData(그림·소리)가 있으면 파일로, 나머지(글·오류)는 같은 이름 .json 으로 남긴다.
오래 걸리는 작업(name 이 operations/…)이면 끝날 때까지 기다린다.
"""

from __future__ import annotations

import base64
import html
import json
import mimetypes
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

API = "https://generativelanguage.googleapis.com/v1beta"
OUT = Path("gen_out")

DOCS = [
    "https://ai.google.dev/gemini-api/docs/models",
    "https://ai.google.dev/gemini-api/docs/image-generation",
    "https://ai.google.dev/gemini-api/docs/music-generation",
    "https://ai.google.dev/gemini-api/docs/speech-generation",
    "https://ai.google.dev/gemini-api/docs/audio",
    "https://ai.google.dev/gemini-api/docs/pricing",
]

EXT = {
    "image/png": ".png",
    "image/jpeg": ".jpg",
    "image/webp": ".webp",
    "audio/wav": ".wav",
    "audio/x-wav": ".wav",
    "audio/mpeg": ".mp3",
    "audio/mp3": ".mp3",
    "audio/ogg": ".ogg",
    "audio/L16": ".pcm",
}


def key() -> str:
    k = os.environ.get("GEMINI_API_KEY", "").strip()
    if not k:
        sys.exit("GEMINI_API_KEY 가 없습니다(저장소 비밀값에 넣어 주세요).")
    return k


def call(method: str, url: str, body: dict | None = None, timeout: int = 600):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("x-goog-api-key", key())
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read() or b"{}")
        except json.JSONDecodeError:
            return e.code, {"error": str(e)}


def strip_html(s: str) -> str:
    s = re.sub(r"(?is)<(script|style|nav|header|footer)[^>]*>.*?</\1>", " ", s)
    s = re.sub(r"(?i)<br\s*/?>|</(p|div|li|h\d|tr|pre)>", "\n", s)
    s = re.sub(r"<[^>]+>", "", s)
    s = html.unescape(s)
    s = re.sub(r"[ \t]+", " ", s)
    return re.sub(r"\n\s*\n+", "\n\n", s).strip()


def probe() -> None:
    d = OUT / "probe"
    d.mkdir(parents=True, exist_ok=True)
    models, page = [], ""
    while True:
        st, r = call("GET", f"{API}/models?pageSize=200" + (f"&pageToken={page}" if page else ""))
        if st != 200:
            (d / "models_error.json").write_text(json.dumps(r, ensure_ascii=False, indent=1))
            break
        models += r.get("models", [])
        page = r.get("nextPageToken", "")
        if not page:
            break
    (d / "models.json").write_text(json.dumps(models, ensure_ascii=False, indent=1))
    lines = [
        f"{m.get('name')}\t{','.join(m.get('supportedGenerationMethods', []))}\t{m.get('displayName', '')}"
        for m in models
    ]
    (d / "models.txt").write_text("\n".join(lines) + "\n")
    for u in DOCS:
        name = u.rstrip("/").split("/")[-1]
        try:
            with urllib.request.urlopen(u, timeout=60) as r:
                (d / f"doc_{name}.txt").write_text(strip_html(r.read().decode("utf-8", "replace")))
        except Exception as e:  # 문서를 못 받으면 그 사실만 남긴다.
            (d / f"doc_{name}.txt").write_text(f"받지 못함: {e}")
    print(f"모델 {len(models)}개 · 문서 {len(DOCS)}쪽 → {d}")


def attach_images(body: dict, images: list[str]) -> None:
    parts = body["contents"][0]["parts"]
    for p in images:
        mime = mimetypes.guess_type(p)[0] or "image/png"
        parts.append({"inline_data": {"mime_type": mime, "data": base64.b64encode(Path(p).read_bytes()).decode()}})


def save(resp: dict, out: Path) -> list[str]:
    """응답 속 inlineData 를 파일로 꺼내고, 나머지는 .json 으로."""
    saved: list[str] = []
    out.parent.mkdir(parents=True, exist_ok=True)

    def walk(o, path=""):
        if isinstance(o, dict):
            inline = o.get("inlineData") or o.get("inline_data")
            if isinstance(inline, dict) and "data" in inline:
                mime = inline.get("mimeType") or inline.get("mime_type") or "application/octet-stream"
                base = mime.split(";")[0]
                ext = EXT.get(base, mimetypes.guess_extension(base) or ".bin")
                f = out.with_name(f"{out.name}_{len(saved)}{ext}") if saved else out.with_suffix(ext)
                f.write_bytes(base64.b64decode(inline["data"]))
                saved.append(str(f))
                inline["data"] = f"<{f.name} · {mime}>"
            # 예측(predict) 응답의 bytesBase64Encoded 도 꺼낸다.
            for k in ("bytesBase64Encoded", "audioContent"):
                if isinstance(o.get(k), str) and len(o[k]) > 200:
                    mime = o.get("mimeType", "application/octet-stream")
                    ext = EXT.get(mime, mimetypes.guess_extension(mime) or ".bin")
                    f = out.with_name(f"{out.name}_{len(saved)}{ext}")
                    f.write_bytes(base64.b64decode(o[k]))
                    saved.append(str(f))
                    o[k] = f"<{f.name}>"
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)

    walk(resp)
    out.with_suffix(".json").write_text(json.dumps(resp, ensure_ascii=False, indent=1))
    return saved


def run_task(t: dict) -> None:
    body = json.loads(json.dumps(t.get("body", {})))
    if t.get("images"):
        attach_images(body, t["images"])
    url = f"{API}/models/{t['model']}:{t.get('method', 'generateContent')}"
    for i in range(int(t.get("n", 1))):
        out = Path(t["out"] + (f"_v{i}" if t.get("n", 1) > 1 else ""))
        st, r = call("POST", url, body)
        # 오래 걸리는 작업이면 끝날 때까지 기다린다.
        name = r.get("name", "") if isinstance(r, dict) else ""
        waited = 0
        while st == 200 and name.startswith(("operations/", "models/")) and not r.get("done") and waited < 900:
            time.sleep(10)
            waited += 10
            st, r = call("GET", f"{API}/{name}")
        files = save(r, out)
        status = "ok" if st == 200 and files else f"실패({st})"
        print(f"{t['id']}#{i}: {status} {files}")


def job(name: str) -> None:
    tasks = json.loads(Path(f"tools/gemini/jobs/{name}.json").read_text())
    only = os.environ.get("ONLY", "").split(",") if os.environ.get("ONLY") else None
    for t in tasks:
        if only and t["id"] not in only:
            continue
        try:
            run_task(t)
        except Exception as e:  # 한 장 실패로 나머지를 멈추지 않는다.
            print(f"{t['id']}: 오류 {e}")


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "probe":
        probe()
    elif len(sys.argv) >= 3 and sys.argv[1] == "job":
        job(sys.argv[2])
    else:
        sys.exit(__doc__)
