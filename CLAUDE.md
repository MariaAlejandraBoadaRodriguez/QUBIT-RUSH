# Qubit Rush — instructions for Claude Code

## Source of truth
- Full product spec: `docs/SPEC.md` (Qubit Rush Android Development Specification v1.1). Follow it exactly, especially §0, §16 and §17.
- Work autonomously through Phases A → D. Do not ask the owner for routine decisions, debugging help or approvals. Make documented choices in `docs/DECISIONS.md`.

## Environment
- At the start of every session run: `bash scripts/setup-env.sh && source ~/.bashrc`
- Godot binary: `~/tools/godot` (pinned version in `scripts/setup-env.sh`; confirm it is the latest 4.x stable before Phase A and record it in README).
- Android SDK: `$ANDROID_HOME` (API 36 platform + build-tools). JDK 17.
- No emulator/KVM in this container: mark device/emulator runtime checks **BLOCKED / NOT VERIFIED**; never claim them as PASS. The owner will install the debug APK on a real phone.
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
