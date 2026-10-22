# Qubit Rush — instructions for Claude Code

## Source of truth
- Full product spec: `docs/SPEC.md` (Qubit Rush Android Development Specification v1.1). Follow it exactly, especially §0, §16 and §17.
- Work autonomously through Phases A → D. Do not ask the owner for routine decisions, debugging help or approvals. Make documented choices in `docs/DECISIONS.md`.

## Environment
- At the start of every session run: `bash scripts/setup-env.sh && source ~/.bashrc`
- Godot binary: `~/tools/godot` (pinned version in `scripts/setup-env.sh`; confirm it is the latest 4.x stable before Phase A and record it in README).
- Android SDK: `$ANDROID_HOME` (API 36 platform + build-tools). JDK 17.
- No emulator/KVM in this container. Emulator testing runs in **GitHub Actions** instead (see "Android emulator CI" below). Physical-device testing is done by the owner and stays **BLOCKED / NOT VERIFIED** until she reports it.

## Android emulator CI (Gate E)
- Create `.github/workflows/android-emulator.yml` triggered on push and `workflow_dispatch`:
  - `ubuntu-latest` runner; enable KVM (udev rule step); set up JDK 17; install the pinned Godot + export templates + Android SDK (reuse `scripts/setup-env.sh`).
  - Run headless unit/integration/level-solvability tests, then export the debug APK.
  - Use `reactivecircus/android-emulator-runner` (pin a released version) with an x86_64 `google_apis` image at API 36 (fall back to the newest available API if 36 is unavailable, and document it), plus a second job at API 26 for the minimum-version check if runtime allows.
  - Inside the emulator: `adb install` the APK, launch the main activity, wait for startup, capture `adb shell screencap` screenshots of home, level 1 and results, run a scripted smoke flow (tap Play → place X gate → Run) via `adb shell input` with coordinates computed from the known layout, collect `adb logcat`, and fail the job on crash, ANR, or Godot `ERROR`/`SCRIPT ERROR` lines.
  - Upload APK, screenshots, logcat and test results as workflow artifacts.
- After each push, check the workflow run result with `gh run list` / `gh run view --log-failed` (or the GitHub REST API). Diagnose and fix failures, then push again until it passes.
- Gate E = PASS only when the emulator workflow actually passes; cite the run URL in `reports/FINAL_VERIFICATION.md`. If the run results cannot be read from this session, record that in `reports/BLOCKERS.md` and keep working on everything else.
- If a download is blocked by the network allowlist, record the exact domain in `reports/BLOCKERS.md` and continue with independent work.

## Commands (keep these working)
- Import project: `~/tools/godot --headless --path . --import`
- Unit/integration tests: headless Godot test runner (GUT, pinned version in `addons/`), e.g. `~/tools/godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit`
- Level solvability check: a headless script under `tests/` that verifies every level in `data/levels/` has a solution.
- Debug APK: `~/tools/godot --headless --path . --export-debug "Android" build/qubit-rush-debug.apk`
- Release AAB: only when signing env vars are provided; otherwise document steps.

## Rules
- Never weaken, skip or delete tests to get green results.
- Never commit keystores, passwords, AdMob production IDs or any secret. Use Google test ad unit IDs only.
- Commit and push after each working increment with clear messages, so progress survives if the session ends.
- Keep updates short; prioritize code and tests.
- At the end of each phase update `reports/FINAL_VERIFICATION.md` (gates A–F as PASS / FAIL / BLOCKED / NOT VERIFIED) and `reports/test-results.json`.
- If the session is resumed, read `reports/FINAL_VERIFICATION.md` and `git log` first, then continue from the next unfinished step.
