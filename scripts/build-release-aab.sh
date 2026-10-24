#!/usr/bin/env bash
# Builds the release Android App Bundle.
#
# Signed release (owner): provide the upload keystore through environment
# variables (read by Godot; never stored in the repository):
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH      absolute path to the upload keystore
#   GODOT_ANDROID_KEYSTORE_RELEASE_USER      key alias
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD  keystore/key password
# Optional AdMob production config: see docs/ADS_INTEGRATION.md.
#
#   scripts/build-release-aab.sh              -> build/qubit-rush-release.aab (signed)
#   scripts/build-release-aab.sh --validate   -> build/qubit-rush-validation.aab signed with a
#        throwaway key generated on the fly, ONLY to validate the pipeline. Never upload it.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/tools/godot}"
: "${ANDROID_HOME:=$HOME/android-sdk}"
BUNDLETOOL_VERSION="1.18.3"
mkdir -p build
OUT="build/qubit-rush-release.aab"

if [ "${1:-}" = "--validate" ]; then
  OUT="build/qubit-rush-validation.aab"
  TMP="build/tmp-validation-key"
  rm -rf "$TMP"; mkdir -p "$TMP"
  PASS="$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)"
  keytool -genkeypair -keystore "$TMP/validation.jks" -storepass "$PASS" -keypass "$PASS" \
    -alias validation -keyalg RSA -keysize 2048 -validity 1 -dname "CN=Validation Only" >/dev/null 2>&1
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$PWD/$TMP/validation.jks"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER="validation"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$PASS"
  trap 'rm -rf "$TMP"' EXIT
elif [ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]; then
  echo "Release signing credentials not provided (GODOT_ANDROID_KEYSTORE_RELEASE_*)." >&2
  echo "See README.md 'Release AAB'. Use --validate to test the pipeline with a throwaway key." >&2
  exit 2
fi

bash scripts/install-android-template.sh
bash scripts/build-android-plugin.sh >/dev/null
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Android AAB" "$OUT" 2>&1 | tee build/export-release.log
test -s "$OUT"

BT="build/bundletool-all-${BUNDLETOOL_VERSION}.jar"
if [ ! -f "$BT" ]; then
  curl -fsSL -o "$BT" "https://github.com/google/bundletool/releases/download/${BUNDLETOOL_VERSION}/bundletool-all-${BUNDLETOOL_VERSION}.jar"
fi
java -jar "$BT" validate --bundle="$OUT" | tee build/bundletool-validate.txt
java -jar "$BT" dump manifest --bundle="$OUT" > build/aab-manifest.xml
grep -oE 'targetSdkVersion="[0-9]+"|minSdkVersion="[0-9]+"|package="[^"]+"' build/aab-manifest.xml | tee -a build/bundletool-validate.txt
if grep -q "ca-app-pub-3940256099942544" build/aab-manifest.xml; then
  echo "ERROR: release bundle contains a Google TEST AdMob app id." >&2
  exit 1
fi
sha256sum "$OUT" | tee "$OUT.sha256"
