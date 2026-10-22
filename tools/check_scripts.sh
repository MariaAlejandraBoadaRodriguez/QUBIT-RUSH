#!/usr/bin/env bash
# Compiles every project script/scene with autoloads active. Fails on any error.
set -uo pipefail
GODOT="${GODOT:-$HOME/tools/godot}"
out="$("$GODOT" --headless --path . -s tests/compile_all.gd 2>&1)"; code=$?
echo "$out" | grep -E "SCRIPT ERROR|Parse Error|Compile Error|FAILED|Compiled" -A1
if echo "$out" | grep -qE "SCRIPT ERROR"; then exit 1; fi
exit $code
