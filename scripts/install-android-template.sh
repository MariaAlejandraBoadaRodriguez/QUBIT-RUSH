#!/usr/bin/env bash
# Installs the Godot Android Gradle build template into android/build (needed
# for Gradle exports: AdMob plugin, minSdk/targetSdk control, AAB). Equivalent
# to Project > Install Android Build Template in the editor. Idempotent.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_VERSION="$(grep -oE 'GODOT_VERSION:-[0-9.]+' scripts/setup-env.sh | cut -d- -f2)"
SRC="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable/android_source.zip"
if [ -f android/.build_version ] && grep -q "${GODOT_VERSION}.stable" android/.build_version && [ -f android/build/build.gradle ]; then
  echo "Android build template ${GODOT_VERSION} already installed."
  exit 0
fi
[ -f "$SRC" ] || { echo "Missing $SRC; run scripts/setup-env.sh first." >&2; exit 1; }
rm -rf android/build
mkdir -p android/build
unzip -q -o "$SRC" -d android/build
touch android/build/.gdignore
echo "${GODOT_VERSION}.stable" > android/.build_version
echo "Installed Android build template ${GODOT_VERSION}."
