# Qubit Rush

A portrait Android puzzle game about real quantum circuits. Place gates on qubits, run the circuit, and reach a target state. No account, no internet, no ads unless you opt in.

- **Engine:** Godot **4.7.2-stable** (pinned; latest 4.x stable as of 2026-10-22), GDScript, Compatibility renderer.
- **Content:** 40 handcrafted levels (Fundamentals, Entanglement, Algorithms), Rush mode, Daily Challenge, Practice Lab, Learn glossary.
- **Simulator:** pure double-precision statevector (≤ 3 qubits), gates I X Y Z H S T CNOT, Born-rule measurement on copies, global-phase-invariant fidelity.
- Spec: `docs/SPEC.md`. Decisions: `docs/DECISIONS.md`. Verification: `reports/FINAL_VERIFICATION.md`. Blockers: `reports/BLOCKERS.md`.

## Repository layout
```
project.godot, export_presets.cfg
scenes/{home,level_select,puzzle,results,settings,practice,consent,rush}/   screens (.tscn + script)
scripts/core/        complex_math, statevector, quantum_gates, measurement, fidelity, circuit
scripts/game/        level_schema, level_loader, level_validator, scoring, solver, challenge_generator, game_state
scripts/ui/          theme, circuit_editor, gate_button, probability_bars, bloch_view, sheet, screen_base
scripts/services/    save, audio, consent, ads (+ providers), analytics (local only)
data/levels/         level_01..40.json + index.json (schema v1)
data/config/         ads_config.json (test IDs, child-safe defaults)
android/plugins/qubitrush-ads/   Java AdMob/UMP Godot plugin (Gradle)
addons/qubitrush_ads/            Godot export plugin for the AAR
addons/gut/                      GUT 9.7.1 test framework (not exported)
tests/{unit,integration,ui}/     GUT tests; tests/check_levels.gd solvability check
.github/workflows/android-emulator.yml   CI: tests, APK, emulator smoke (API 36 and 26)
```

## Setup (Linux)
```bash
bash scripts/setup-env.sh && source ~/.bashrc   # JDK 17, Godot 4.7.2 + templates, Android SDK 36
~/tools/godot --headless --path . --import
```
Open in the editor: `~/tools/godot --path . --editor`. Run on desktop: `~/tools/godot --path .`.

## Tests
```bash
bash tools/check_scripts.sh                                              # every script compiles
~/tools/godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit      # unit + integration + UI (JUnit: reports/junit.xml)
~/tools/godot --headless --path . -s tests/check_levels.gd               # 40 levels solvable, optimal 3-star thresholds
xvfb-run -a -s "-screen 0 720x1440x24" ~/tools/godot --path . --audio-driver Dummy \
  --rendering-driver opengl3 --resolution 720x1440 -s tools/screenshots.gd -- reports/screenshots
```

## Android builds
```bash
bash scripts/install-android-template.sh     # Gradle build template -> android/build (not committed)
bash scripts/build-android-plugin.sh         # AdMob/UMP plugin AARs -> addons/qubitrush_ads/bin
~/tools/godot --headless --path . --export-debug "Android" build/qubit-rush-debug.apk
adb install -r build/qubit-rush-debug.apk
```
The debug APK uses the debug keystore created by `setup-env.sh` and Google's **test** ad IDs. It contains arm64-v8a, armeabi-v7a and x86_64 (emulators).

### Release AAB
Signing material never goes into the repository. Provide it via environment variables:
```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/secure/upload-key.jks
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=upload
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='…'
# optional, only after the target-audience decision (docs/ADS_INTEGRATION.md):
export QUBITRUSH_ADMOB_APP_ID=… QUBITRUSH_ADMOB_REWARDED_UNIT=…
bash scripts/build-release-aab.sh            # -> build/qubit-rush-release.aab (+ bundletool validate)
```
To create an upload key once: `keytool -genkeypair -v -keystore upload-key.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000` (store it and its password outside source control; enrol in Play App Signing).
`bash scripts/build-release-aab.sh --validate` exercises the whole pipeline with a throwaway key (never upload that bundle).

## Play publication
Follow `docs/PLAY_SUBMISSION_CHECKLIST.md` (target audience/Families decision, Data safety, privacy policy URL, internal testing track). Compliance notes: `docs/COMPLIANCE.md`.

## Conventions
- Qubit 0 is the top wire and the least significant bit; kets are written q0 first (`|01⟩` = q0=0, q1=1).
- Level format: `data/levels/level_NN.json`, validated on load by `LevelSchema`; see `docs/LEVEL_FORMAT.md`.
- Translations: `python3 tools/extract_strings.py` regenerates `data/i18n/strings.csv` (add an `es` column for Spanish).

## Licences
Game code: owner's choice (not yet specified). Third-party: Godot (MIT), GUT (MIT, dev only), Inter (OFL 1.1, `assets/licenses/Inter-OFL.txt`), DejaVu Sans subset (`assets/licenses/DejaVu-LICENSE.txt`), Google Mobile Ads SDK / UMP (Google terms). All sounds are synthesised in code.
