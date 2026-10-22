#!/usr/bin/env bash
# Emulator smoke test: install, launch, screenshots of home / level 1 / results,
# scripted flow (Play -> X -> Run) and logcat checks for crashes, ANRs and
# Godot errors. Tap coordinates come from "QRUI|screen|button|x|y" lines that
# debug builds log after each screen is laid out.
#   scripts/ci/emulator-smoke.sh <apk> <out_dir>
set -uo pipefail
APK="$1"
OUT="$2"
PKG="com.qubitrush.game"
mkdir -p "$OUT"
LOG="$OUT/logcat.txt"
RESULT="$OUT/smoke-result.txt"
fail() { echo "SMOKE FAIL: $*" | tee -a "$RESULT"; adb logcat -d > "$LOG" 2>/dev/null || true; exit 1; }

adb wait-for-device
for i in $(seq 1 90); do
  [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break
  sleep 2
done
adb shell settings put global window_animation_scale 0 || true
adb shell settings put global transition_animation_scale 0 || true
adb shell settings put global animator_duration_scale 0 || true
adb shell input keyevent 82 || true
echo "Device: $(adb shell getprop ro.build.version.sdk | tr -d '\r') $(adb shell wm size | tr -d '\r')" | tee "$RESULT"

adb install -r -g "$APK" || fail "adb install failed"
adb logcat -c
START=$(date +%s)
adb shell am start -W -n "$PKG/com.godot.game.GodotAppLauncher" | tee -a "$RESULT" || fail "launch failed"

# wait_ui <screen> <button> <timeout_s>: prints "x y" once the screen logged it.
wait_ui() {
  local deadline=$(( $(date +%s) + $3 ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    local line
    line="$(adb logcat -d -s godot:I 2>/dev/null | grep -a "QRUI|$1|$2|" | tail -1)"
    if [ -n "$line" ]; then
      echo "$line" | sed -E 's/.*QRUI\|[^|]*\|[^|]*\|([0-9-]+)\|([0-9-]+).*/\1 \2/'
      return 0
    fi
    if ! adb shell pidof "$PKG" >/dev/null 2>&1; then
      return 2
    fi
    sleep 1
  done
  return 1
}

tap_ui() {
  local xy
  xy="$(wait_ui "$1" "$2" "${3:-60}")" || fail "$1/$2 not shown (exit $?)"
  echo "tap $1/$2 at $xy" | tee -a "$RESULT"
  adb shell input tap $xy
}

shot() { sleep 2; adb exec-out screencap -p > "$OUT/$1.png" || true; }

wait_ui home PlayButton 90 > /dev/null || fail "home screen did not appear"
echo "Startup to home: $(( $(date +%s) - START )) s" | tee -a "$RESULT"
shot 01-home
tap_ui home PlayButton
wait_ui puzzle Gate_X 30 > /dev/null || fail "level 1 did not open"
shot 02-level1
tap_ui puzzle Gate_X
sleep 1
tap_ui puzzle RunButton
wait_ui results NextButton 30 > /dev/null || fail "results screen did not appear after Run"
shot 03-results
tap_ui results NextButton
wait_ui puzzle RunButton 30 > /dev/null || fail "level 2 did not open"
shot 04-level2

# Background / resume: app must survive and keep running.
adb shell input keyevent KEYCODE_HOME
sleep 3
adb shell am start -n "$PKG/com.godot.game.GodotAppLauncher" > /dev/null
sleep 5
adb shell pidof "$PKG" > /dev/null || fail "process died after resume"
shot 05-resumed

# Rendering check: screenshots must show the real design colours (warm
# background, navy Play/Run, soft-blue circuit slots, green success title).
PNG="python3 $(dirname "$0")/../../tools/png_colors.py"
$PNG "$OUT/01-home.png" FAFAF8:0.5 253C58:0.01 | tee -a "$RESULT" || fail "home screen did not render"
$PNG "$OUT/02-level1.png" FAFAF8:0.3 7DA7EA:0.002 253C58:0.005 | tee -a "$RESULT" || fail "level 1 did not render"
$PNG "$OUT/03-results.png" FAFAF8:0.3 3B806C:0.001 | tee -a "$RESULT" || fail "results screen did not render"

adb logcat -d > "$LOG"

# Positive check: the debug UI log must show the results screen was reached.
grep -aq "QRUI|results|" "$LOG" || fail "results screen never logged (QRUI|results|...)"
echo "Results screen reached: $(grep -a "QRUI|results|" "$LOG" | tail -1 | sed 's/.*QRUI/QRUI/')" | tee -a "$RESULT"

# Hard failures: crashes, ANRs, FATAL, and any Godot/script error...
grep -aE "FATAL EXCEPTION|FATAL|ANR in $PKG|SCRIPT ERROR|E godot[^:]*: ERROR" "$LOG" > "$OUT/errors-raw.txt" || true
# ...except ONLY these exact lines, a known limitation of software GPU emulation
# on GPU-less CI runners (see docs/DECISIONS.md, "Emulator rendering allowlist"):
#   ERROR: SceneShaderGLES3: Program linking failed:
#   ERROR: CanvasShaderGLES3: Program linking failed:
#   ERROR: Method/function failed.   (only directly after one of the two lines above)
#   ERROR: Condition "p_size < 0" is true. Returning: ERR_INVALID_PARAMETER
awk -v warn="$OUT/known-emulator-warnings.txt" '
  BEGIN { prev_link = 0 }
  /E godot[^:]*: ERROR: (Scene|Canvas)ShaderGLES3: Program linking failed:$/ { print > warn; prev_link = 1; next }
  /E godot[^:]*: ERROR: Method\/function failed\.$/ && prev_link { print > warn; prev_link = 0; next }
  /E godot[^:]*: ERROR: Condition "p_size < 0" is true\. Returning: ERR_INVALID_PARAMETER$/ { print > warn; prev_link = 0; next }
  { prev_link = 0; print }
' "$OUT/errors-raw.txt" > "$OUT/errors.txt"
touch "$OUT/known-emulator-warnings.txt"
WARN_COUNT=$(wc -l < "$OUT/known-emulator-warnings.txt")
echo "Known emulator rendering warnings (allowlisted, not failures): $WARN_COUNT" | tee -a "$RESULT"
if [ -s "$OUT/errors.txt" ]; then
  cat "$OUT/errors.txt"
  fail "crash, ANR, FATAL or Godot/script error found in logcat"
fi
echo "SMOKE PASS" | tee -a "$RESULT"
