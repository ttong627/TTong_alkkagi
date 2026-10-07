#!/usr/bin/env bash
# 플레이에 올릴 AAB 를 업로드 키로 서명한다(CI 가 디버그 키로 만든 AAB 를 다시 서명).
# 사용: tools/signing/sign-aab.sh <keystore.jks> <in.aab> <out.aab> [--no-symbols]
#   --no-symbols: 네이티브 디버그 기호(플레이에 선택 항목)를 빼서 크기를 줄인다.
# 환경변수: ALKKAGI_KEYSTORE_PASSWORD · ALKKAGI_KEY_PASSWORD · ALKKAGI_KEY_ALIAS
set -euo pipefail
KS="$1"; IN="$2"; OUT="$3"; MODE="${4:-}"
cp "$IN" "$OUT"
zip -q -d "$OUT" 'META-INF/*.SF' 'META-INF/*.RSA' 'META-INF/*.DSA' 'META-INF/*.EC' 'META-INF/MANIFEST.MF' 2>/dev/null || true
if [ "$MODE" = "--no-symbols" ]; then
  zip -q -d "$OUT" 'BUNDLE-METADATA/com.android.tools.build.debugsymbols/*' || true
fi
export SP_ENV="$ALKKAGI_KEYSTORE_PASSWORD" KP_ENV="$ALKKAGI_KEY_PASSWORD"
jarsigner -sigalg SHA256withRSA -digestalg SHA-256 -keystore "$KS" \
  -storepass:env SP_ENV -keypass:env KP_ENV "$OUT" "$ALKKAGI_KEY_ALIAS" >/dev/null
jarsigner -verify "$OUT" | grep -q "jar verified" && echo "검증 통과"
keytool -printcert -jarfile "$OUT" | grep -E "SHA256:"
