# Qubit Rush — final verification report

Generated: 2026-10-22 (session `claude/intelligent-wozniak-l6gr6q`). Machine-readable results: `reports/test-results.json`. Logs: `reports/logs/`. Commands and exit codes: `reports/commands.tsv`.

**Overall status: ALL TESTS PASSED for every check executable in this environment. NOT "fully verified for Android release":** the Android runtime gate (emulator/device) and the GitHub CI run are BLOCKED / NOT VERIFIED (see Gate E and `reports/BLOCKERS.md`).

## Environment
| Item | Value |
|---|---|
| OS | Ubuntu 24.04 container, Linux 6.18 x86_64, no KVM (`/dev/kvm` absent) |
| Godot | 4.7.2.stable.official.ed1daf0bf (latest 4.x stable on 2026-10-22) |
| JDK | OpenJDK 17.0.20.1 (system default JDK 21 is bypassed) |
| Android SDK | platform android-36; build-tools 36.1.0 (template), 36.0.0, 34.0.0 (AGP default); platform-tools 37.0.1 |
| Gradle / AGP | Gradle 8.11.1, AGP 8.6.1 (Godot 4.7.2 template) |
| Test framework | GUT 9.7.1 |
| Ads SDKs | play-services-ads 25.5.0, user-messaging-platform 4.0.0 (Google test IDs only) |
| Emulator / device | none in this container; emulator workflow written for GitHub Actions but not run (push blocked) |

## Commands (final regression after the last code change)
`scripts/run-all-checks.sh` runs, in order (exit codes in `reports/commands.tsv`):

| # | Check | Command | Result |
|---|---|---|---|
| 1 | Project import | `~/tools/godot --headless --path . --import` | exit 0 |
| 2 | Compile every script/scene | `~/tools/godot --headless --path . -s tests/compile_all.gd` | exit 0 |
| 3 | GUT unit + integration + UI | `~/tools/godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit` | exit 0 — see table |
| 4 | Level solvability | `~/tools/godot --headless --path . -s tests/check_levels.gd` | exit 0 — 40/40 |
| 5 | Performance / memory | `~/tools/godot --headless --path . -s tests/perf_check.gd` | exit 0 |
| 6 | Android build template | `bash scripts/install-android-template.sh` | exit 0 |
| 7 | AdMob/UMP plugin AARs | `bash scripts/build-android-plugin.sh` | exit 0 |
| 8 | Debug APK (Gradle) | `~/tools/godot --headless --path . --export-debug "Android" build/qubit-rush-debug.apk` | exit 0 |
| 9 | Release AAB pipeline | `bash scripts/build-release-aab.sh --validate` (throwaway key, `bundletool validate`) | exit 0 |

### GUT results
| Suite | Tests | Failed | Skipped |
|---|---|---|---|
| tests/unit/test_quantum_core.gd | 26 | 0 | 0 |
| tests/unit/test_levels.gd | 18 | 0 | 0 |
| tests/unit/test_save_service.gd | 12 | 0 | 0 |
| tests/integration/test_ads_policy.gd | 19 | 0 | 0 |
| tests/integration/test_gameplay_flow.gd | 15 | 0 | 0 |
| tests/ui/test_layout.gd | 4 | 0 | 0 |
| **Total** | **94** | **0** | **0** |
Asserts: 4630/4630 passed. JUnit: `reports/junit.xml`.

### Performance (headless, this container; targets, not device benchmarks)
| Metric | Result | Budget |
|---|---|---|
| Run a 3-qubit, 20-gate circuit | ~0.2 ms | 2 ms |
| Live preview refresh | ~0.05 ms | 2 ms |
| Load + validate 40 levels | ~6 ms | 500 ms |
| BFS-solve all 40 levels | ~30 ms | 20 s |
| Object count after 600 puzzle open/close cycles | +12 | ≤ 200 |
| Static memory growth, second 300 cycles | < 1 MB (≈3 KB per screen, from Godot's interned auto-generated node names) | ≤ 1 MB |
Exact numbers: `reports/performance.json`.

## Artifacts
| Artifact | Notes |
|---|---|
| `build/qubit-rush-debug.apk` | debug-signed, arm64-v8a + armeabi-v7a + x86_64, minSdk 26, targetSdk 36, portrait, AdMob **test** app ID, AD_ID permissions removed (child-safe) |
| `build/qubit-rush-validation.aab` | pipeline validation only (throwaway key, never upload); `bundletool validate` passed; minSdk 26 / targetSdk 36; no ads SDK (no production IDs supplied); only `VIBRATE` permission |
| Path | Bytes | SHA-256 |
|---|---|---|
| `build/qubit-rush-debug.apk` | 251,823,278 | `c4d417ba4e606dd10a439132e65402a6df66919d5d1feb5984ecccfd15b77da0` |
| `build/qubit-rush-validation.aab` | 53,228,128 | `9c613a5d5ccb18d462e2c755a71c672ed12d4f9a38f3d7a91f0a6d4589f3e768` |

The same values are in `reports/test-results.json` → `artifacts`. Build outputs are not committed (`.gitignore`).

## Quality gates
| Gate | Status | Evidence |
|---|---|---|
| **A — Quantum correctness** | **PASS** | `test_quantum_core.gd` (26 tests): X/H/Z/Y/S/T matrices and identities, HZH = X, Bell state with documented ordering, CNOT both directions, norm preservation over 150 random 40-gate sequences on 1–3 qubits, global-phase invariance, relative-phase detection, seeded measurement convergence and determinism, collapse on copies only, Bloch vectors, invalid ops fail safely |
| **B — Content completeness** | **PASS** | `tests/check_levels.gd` + `test_levels.gd`: 40/40 levels load and validate; each reference solution solves its level; independent BFS solver finds a solution within `max_slots`; three-star threshold equals the optimal gate count for every level; at most one new gate per level; no level solvable by an empty circuit; all levels reachable in order (end-to-end UI run of all 40 in `test_gameplay_flow.gd`, 120/120 stars) |
| **C — Gameplay integration** | **PASS (headless)**; device checks NOT VERIFIED | `test_gameplay_flow.gd`: offline first run with no account/ads, Play → level 1 → X → Run → results → next; wrong answer path; undo/reset/move/remove/limits; drag-and-drop onto a slot; CNOT editing; in-progress circuit survives restart; Rush timer pauses on focus loss and consent dialog; Rush/Daily completion; locked levels; Android Back; free hints. `test_save_service.gd`: persistence, best-score keeping, v1→v2 migration, corrupt save + backup recovery, atomic write. `test_layout.gd`: 5 aspect ratios incl. tablet and large text, no overflow, all buttons ≥ 48 dp, text labels on every control. TalkBack and real touch input: NOT VERIFIED (no device) |
| **D — Ads safety** | **PASS (logic, mock SDK)**; live test ads NOT VERIFIED | `test_ads_policy.gd` (19 tests): child-safe config with Google test IDs only, safe defaults on malformed config, no ads without opt-in, declined consent and UMP-required block ads, rewarded grant exactly once (duplicate callbacks, replayed ids, forged callbacks, early dismissal), no-fill/SDK error/init failure degrade gracefully, no ads during gameplay, interstitials blocked under child-safe policy, frequency caps for general audience, revocation, progression without ads, release override, offer only on results screen. Java plugin compiles against Mobile Ads 25.5.0 / UMP 4.0.0. Live ads are not enabled (no owner AdMob config) |
| **E — Android delivery** | **BLOCKED / NOT VERIFIED** | PASS parts: headless import and tests; debug APK builds (Gradle, plugin included, manifest checked with aapt2); AAB builds and passes `bundletool validate`. BLOCKED part: launch + gameplay smoke test on an emulator/device. `.github/workflows/android-emulator.yml` (API 36 + API 26, screenshots, scripted Play → X → Run, logcat crash/ANR/Godot-error checks) is committed but **has never run**: `git push` returns HTTP 403 (GitHub App lacks write access), so no workflow run URL exists. No KVM locally. |
| **F — Full regression** | **PASS** | After the last code change, all 9 commands above re-ran with exit 0; GUT 94/94; no `SCRIPT ERROR` in any log (`reports/test-results.json` → `all_executed_checks_passed: true`); no skipped tests |

## Defects found and fixed during verification
1. `setup-env.sh` aborted under `pipefail` and used the preinstalled JDK 21 → JDK 17 resolved explicitly; Godot pinned to 4.7.2.
2. Circuit slots were 46 dp (< 48 dp touch target) — caught by the layout test → 50 dp.
3. Level tabs overflowed at 720 px and with large text → wrapping tabs with tighter padding.
4. Selected-CNOT action row widened every card off-screen (visual review of rendered screenshots) → wrapping row; layout test now checks scroll content width with a selected CNOT.
5. Kets wrapped mid-symbol (`|` / `0⟩`) → word joiner after `|`.
6. Level 1 preview hidden below the fold → tutorial merged into the objective card; main column scrolls with Run pinned.
7. Ads SDK 25.5.0 ships Kotlin 2.3 metadata, incompatible with the template's Kotlin 2.1 → plugin rewritten in Java.
8. Maven Central 429 rate limits → plugin compiles against the template's local `godot-lib` AAR.
9. Ads SDK merged `AD_ID`/AdServices permissions into a child-directed build → removed via manifest `tools:node="remove"` under the child-safe policy (verified with aapt2).
10. Test isolation: a stale `.bak` save restored an earlier run's ads opt-in → all tests now delete `.tmp`/`.bak` too (save backup recovery itself is intended behaviour and tested).
11. Bloch label overlap and non-reading-order basis listing in bars/kets → fixed, test added.

## Honest limitations
- **No emulator or device run** of any build. Cold-start time, 60 FPS, TalkBack, gesture navigation, display cutouts and real touch drag-and-drop are untested on Android.
- The CI emulator workflow is unexecuted, so its own correctness (e.g. API 36 image availability, tap coordinates) is unverified.
- Live AdMob test ads and the UMP form have not been displayed on a device.
- Release signing, Play Console upload, Families/target-audience decision, Data safety form and privacy-policy hosting are owner actions (`docs/PLAY_SUBMISSION_CHECKLIST.md`). Legal review is still required.
- Performance figures come from a desktop-class container, not phones.

## Next concrete steps (owner)
1. Grant the Claude GitHub App write access (or push this branch yourself), then check the `android-emulator` workflow run; Gate E becomes PASS only when it passes.
2. Install `build/qubit-rush-debug.apk` (or the CI artifact) on a low-end and a mid-range phone; walk the smoke flow and TalkBack.
3. Record the target-audience decision and, if ads are wanted, supply AdMob IDs as build env vars (`docs/ADS_INTEGRATION.md`).
4. Create the upload key and build the signed AAB with `scripts/build-release-aab.sh`; upload to an internal testing track.
