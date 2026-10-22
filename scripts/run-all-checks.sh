#!/usr/bin/env bash
# Full regression (SPEC §17 Gate F): runs every automated check, records exact
# commands, exit codes and logs, then writes reports/test-results.json.
#   scripts/run-all-checks.sh [--skip-android]
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/tools/godot}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
[ -d /usr/lib/jvm/java-17-openjdk-amd64 ] && export JAVA_HOME="${JAVA_HOME_17:-/usr/lib/jvm/java-17-openjdk-amd64}"
LOGS=reports/logs
mkdir -p "$LOGS" build
CMDS=reports/commands.tsv
: > "$CMDS"

run() {  # run <name> <timeout_s> <command...>
  local name="$1" to="$2"; shift 2
  local start end code
  start=$(date +%s)
  timeout "$to" "$@" > "$LOGS/$name.log" 2>&1
  code=$?
  end=$(date +%s)
  printf '%s\t%s\t%s\t%s\n' "$name" "$code" "$((end - start))" "$*" >> "$CMDS"
  printf '%-22s exit=%-3s %4ss  %s\n' "$name" "$code" "$((end - start))" "$*"
}

run import 600 "$GODOT" --headless --path . --import
run compile_all 300 "$GODOT" --headless --path . -s tests/compile_all.gd
run gut_tests 1800 "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit
run level_solvability 900 "$GODOT" --headless --path . -s tests/check_levels.gd
run performance 900 "$GODOT" --headless --path . -s tests/perf_check.gd
if [ "${1:-}" != "--skip-android" ]; then
  run android_template 300 bash scripts/install-android-template.sh
  run android_plugin 1200 bash scripts/build-android-plugin.sh
  rm -f build/qubit-rush-debug.apk
  run export_debug_apk 2400 "$GODOT" --headless --path . --export-debug "Android" build/qubit-rush-debug.apk
  run validate_aab 2400 bash scripts/build-release-aab.sh --validate
fi
python3 tools/make_report.py
