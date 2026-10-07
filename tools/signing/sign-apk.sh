#!/usr/bin/env bash
# 시험용 APK 를 업로드 키로 다시 서명한다(지우지 않고 업데이트로 설치되게).
# 사용: tools/signing/sign-apk.sh <keystore.jks> <in.apk> <out.apk>
# 환경변수: ALKKAGI_KEYSTORE_PASSWORD · ALKKAGI_KEY_PASSWORD · ALKKAGI_KEY_ALIAS
# 서명 도구 apksig 2.3.0 은 Maven Central 에서 받고 SHA-1 을 대조한다.
set -euo pipefail
KS="$1"; IN="$2"; OUT="$3"
HERE="$(cd "$(dirname "$0")" && pwd)"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/alkkagi-signing"
JAR="$CACHE/apksig-2.3.0.jar"
SHA1=6ef7a58375aa68fb492b58edd97607bee8ee5c5c
mkdir -p "$CACHE"
if [ ! -f "$JAR" ]; then
  curl -sSL -o "$JAR" https://repo1.maven.org/maven2/com/android/tools/build/apksig/2.3.0/apksig-2.3.0.jar
fi
echo "$SHA1  $JAR" | sha1sum -c --quiet - || { echo "apksig 내려받기 검사 실패"; rm -f "$JAR"; exit 1; }
javac -d "$CACHE" -cp "$JAR" "$HERE/SignApk.java"
# apksig 2.3.0(2017)은 자바 내부 모듈을 쓴다.
java -Dstdout.encoding=UTF-8 --add-exports java.base/sun.security.x509=ALL-UNNAMED \
  --add-exports java.base/sun.security.pkcs=ALL-UNNAMED \
  --add-exports java.base/sun.security.util=ALL-UNNAMED \
  -cp "$JAR:$CACHE" SignApk "$KS" "$IN" "$OUT"
# 압축하지 않은 항목의 정렬(네이티브 라이브러리 16KB, 나머지 4바이트)이 그대로인지 확인한다.
python3 - "$OUT" <<'PY'
import struct, sys, zipfile
p = sys.argv[1]; z = zipfile.ZipFile(p); f = open(p, 'rb'); bad = 0
for i in z.infolist():
    if i.compress_type != 0:
        continue
    f.seek(i.header_offset); h = f.read(30)
    n, e = struct.unpack('<HH', h[26:30])
    data = i.header_offset + 30 + n + e
    need = 16384 if i.filename.endswith('.so') else 4
    if data % need:
        bad += 1; print('정렬 어긋남', i.filename)
print('정렬 검사: 어긋남', bad)
sys.exit(1 if bad else 0)
PY
