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

adb logcat -d > "$LOG"
if grep -aE "FATAL EXCEPTION|ANR in $PKG|SCRIPT ERROR|E godot[^:]*: ERROR" "$LOG" > "$OUT/errors.txt"; then
  cat "$OUT/errors.txt"
  fail "crash, ANR or Godot error found in logcat"
fi
echo "SMOKE PASS" | tee -a "$RESULT"
