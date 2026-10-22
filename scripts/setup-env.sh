#!/usr/bin/env bash
# Qubit Rush — Claude Code cloud environment setup
# Installs: JDK 17, Godot 4.x (headless editor + export templates), Android SDK (API 36), debug keystore.
# Idempotent: safe to run at the start of every session.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.5.1}"          # Pin: confirm latest stable 4.x before Phase A and update here
GODOT_TAG="${GODOT_VERSION}-stable"
ANDROID_CMDLINE_ZIP="commandlinetools-linux-13114758_latest.zip"
ANDROID_API="${ANDROID_API:-36}"
BUILD_TOOLS="${BUILD_TOOLS:-36.0.0}"

export ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
TOOLS_DIR="$HOME/tools"
mkdir -p "$TOOLS_DIR" "$ANDROID_HOME"

echo "==> System packages (JDK 17, unzip, curl)"
if ! command -v javac >/dev/null 2>&1 || ! javac -version 2>&1 | grep -q " 17"; then
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends openjdk-17-jdk-headless unzip curl ca-certificates
fi
export JAVA_HOME="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")}"

echo "==> Godot ${GODOT_TAG}"
GODOT_BIN="$TOOLS_DIR/godot"
if [ ! -x "$GODOT_BIN" ] || ! "$GODOT_BIN" --version 2>/dev/null | grep -q "^${GODOT_VERSION}"; then
  BASE="https://github.com/godotengine/godot/releases/download/${GODOT_TAG}"
  curl -fL --retry 3 -o /tmp/godot.zip "${BASE}/Godot_v${GODOT_TAG}_linux.x86_64.zip"
  unzip -o -q /tmp/godot.zip -d /tmp/godot
  mv "/tmp/godot/Godot_v${GODOT_TAG}_linux.x86_64" "$GODOT_BIN"
  chmod +x "$GODOT_BIN"
fi

TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
if [ ! -f "$TEMPLATES_DIR/android_source.zip" ]; then
  echo "==> Godot export templates"
  curl -fL --retry 3 -o /tmp/templates.tpz \
    "https://github.com/godotengine/godot/releases/download/${GODOT_TAG}/Godot_v${GODOT_TAG}_export_templates.tpz"
  mkdir -p "$TEMPLATES_DIR"
  unzip -o -q /tmp/templates.tpz -d /tmp/templates
  cp -r /tmp/templates/templates/* "$TEMPLATES_DIR/"
fi

echo "==> Android SDK"
if [ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
  curl -fL --retry 3 -o /tmp/cmdline.zip "https://dl.google.com/android/repository/${ANDROID_CMDLINE_ZIP}"
  unzip -o -q /tmp/cmdline.zip -d /tmp/cmdline
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  rm -rf "$ANDROID_HOME/cmdline-tools/latest"
  mv /tmp/cmdline/cmdline-tools "$ANDROID_HOME/cmdline-tools/latest"
fi
SDKM="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
yes | "$SDKM" --licenses >/dev/null || true
"$SDKM" --install "platform-tools" "platforms;android-${ANDROID_API}" "build-tools;${BUILD_TOOLS}" >/dev/null

echo "==> Debug keystore (debug builds only — never used for release)"
DEBUG_KS="$HOME/.android/debug.keystore"
if [ ! -f "$DEBUG_KS" ]; then
  mkdir -p "$HOME/.android"
  keytool -genkeypair -v -keystore "$DEBUG_KS" -storepass android -keypass android \
    -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi

echo "==> Godot editor settings (SDK, JDK, debug keystore paths)"
MAJOR_MINOR="$(echo "$GODOT_VERSION" | cut -d. -f1,2)"
CFG_DIR="$HOME/.config/godot"
mkdir -p "$CFG_DIR"
cat > "$CFG_DIR/editor_settings-${MAJOR_MINOR}.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "${ANDROID_HOME}"
export/android/java_sdk_path = "${JAVA_HOME}"
export/android/debug_keystore = "${DEBUG_KS}"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOF

# Persist env vars for later shells in this session
PROFILE_LINE="export ANDROID_HOME=$ANDROID_HOME ANDROID_SDK_ROOT=$ANDROID_HOME JAVA_HOME=$JAVA_HOME PATH=$TOOLS_DIR:$ANDROID_HOME/platform-tools:\$PATH"
grep -qF "ANDROID_HOME=$ANDROID_HOME" "$HOME/.bashrc" 2>/dev/null || echo "$PROFILE_LINE" >> "$HOME/.bashrc"

echo "==> Versions"
"$GODOT_BIN" --version
java -version 2>&1 | head -1
"$SDKM" --list_installed | grep -E "platforms|build-tools|platform-tools" || true
echo "Setup complete. Note: no Android emulator in this cloud container (no KVM) — device smoke tests are BLOCKED / NOT VERIFIED here."
