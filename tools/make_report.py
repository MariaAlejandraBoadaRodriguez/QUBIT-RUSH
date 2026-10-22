#!/usr/bin/env python3
"""Builds reports/test-results.json from the logs written by scripts/run-all-checks.sh."""
import hashlib, json, os, platform, re, subprocess, datetime
import xml.etree.ElementTree as ET

R = "reports"
def read(p):
    try:
        return open(p, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""

def has_script_errors(text):
    return bool(re.search(r"SCRIPT ERROR", text))

commands = []
for line in read(os.path.join(R, "commands.tsv")).splitlines():
    name, code, secs, cmd = line.split("\t", 3)
    log = os.path.join(R, "logs", name + ".log")
    commands.append({"name": name, "command": cmd, "exit_code": int(code), "seconds": int(secs),
                     "log": log, "script_errors_in_log": has_script_errors(read(log))})

suites = []
junit = os.path.join(R, "junit.xml")
if os.path.exists(junit):
    root = ET.parse(junit).getroot()
    for ts in root.iter("testsuite"):
        tests = int(ts.get("tests", 0)); failures = int(ts.get("failures", 0))
        errors = int(ts.get("errors", 0)); skipped = int(ts.get("skipped", 0) or 0)
        pending = sum(1 for tc in ts.iter("testcase") if tc.find("skipped") is not None)
        suites.append({"suite": ts.get("name"), "tests": tests, "failures": failures,
                       "errors": errors, "skipped": max(skipped, pending)})
totals = {k: sum(s[k] for s in suites) for k in ("tests", "failures", "errors", "skipped")}
gut_log = read(os.path.join(R, "logs", "gut_tests.log"))
m = re.search(r"Asserts\s+(\d+)(?:/(\d+))?", gut_log)
asserts = {"passed": int(m.group(1)), "total": int(m.group(2) or m.group(1))} if m else None

levels = json.loads(read(os.path.join(R, "level-solvability.json")) or "{}")
perf = json.loads(read(os.path.join(R, "performance.json")) or "{}")

def sha(p):
    if not os.path.exists(p):
        return None
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return {"path": p, "bytes": os.path.getsize(p), "sha256": h.hexdigest()}

def ver(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=60).stdout.strip() or \
            subprocess.run(cmd, capture_output=True, text=True, timeout=60).stderr.strip().splitlines()[-1]
    except Exception as e:
        return f"unavailable ({e})"

godot = os.path.expanduser("~/tools/godot")
out = {
    "generated_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    "environment": {
        "os": platform.platform(),
        "godot": ver([godot, "--version"]),
        "java": ver(["bash", "-c", "${JAVA_HOME:-/usr}/bin/java -version 2>&1 | grep -i version | head -1"]),
        "android_build_tools": sorted(os.listdir(os.path.expanduser("~/android-sdk/build-tools"))) if os.path.isdir(os.path.expanduser("~/android-sdk/build-tools")) else [],
        "android_platforms": sorted(os.listdir(os.path.expanduser("~/android-sdk/platforms"))) if os.path.isdir(os.path.expanduser("~/android-sdk/platforms")) else [],
        "emulator_available": os.path.exists("/dev/kvm"),
        "plugins": {"GUT": "9.7.1", "play-services-ads": "25.5.0", "user-messaging-platform": "4.0.0"},
    },
    "commands": commands,
    "gut": {"suites": suites, "totals": totals, "asserts": asserts},
    "levels": {"ok": levels.get("ok"), "count": len(levels.get("levels", [])),
               "passed": sum(1 for l in levels.get("levels", []) if l.get("ok"))},
    "performance": perf,
    "artifacts": [a for a in (sha("build/qubit-rush-debug.apk"), sha("build/qubit-rush-validation.aab"),
                              sha("build/qubit-rush-release.aab")) if a],
}
out["all_executed_checks_passed"] = all(c["exit_code"] == 0 and not c["script_errors_in_log"] for c in commands) \
    and totals.get("failures", 1) == 0 and totals.get("errors", 1) == 0 and bool(levels.get("ok"))
with open(os.path.join(R, "test-results.json"), "w") as f:
    json.dump(out, f, indent=2)
print(json.dumps({"commands": [(c["name"], c["exit_code"]) for c in commands], "gut": totals,
                  "levels": out["levels"], "perf_ok": perf.get("ok"),
                  "all_executed_checks_passed": out["all_executed_checks_passed"]}, indent=1))
