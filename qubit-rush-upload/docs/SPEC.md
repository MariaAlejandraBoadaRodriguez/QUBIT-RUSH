# QUBIT RUSH — Android Game Development Specification

**Version:** 1.1 | **Date:** 2026-10-21 | **Status:** Implementation-ready product specification for Claude

## 0. Instructions to the development agent

Build a production-oriented, portrait-mode Android puzzle game named **Qubit Rush**. Deliver actual Godot source, automated tests, Android export configuration, documentation, and an installable debug APK plus signed-release AAB instructions (and AAB when signing credentials are supplied). Do not substitute a website, static mockup, or slideshow for the native game. Implement the functional vertical slice first, then complete the remaining scope in stages. Never fabricate test results, SDK availability, ad integration success, or Play Console approval. Work autonomously without requesting routine approvals, debugging help, implementation choices, or permission to fix errors. Only external credentials, signing keys, legally required owner decisions, or actions requiring access to the owner’s accounts may remain as clearly documented external blockers; do not invent or bypass them. Keep implementation updates concise; prioritize code and testing.

### Non-negotiable product principles
- **Instant guest play:** no login, email, phone number, account creation, cloud registration, or network connection required to play.
- **Accessible explanation:** understandable to a curious 10-year-old, with no childish mascots, baby talk, or patronizing language. A 30-year-old should enjoy the same interface.
- **Authentic quantum mechanics:** gates act on complex amplitudes, with mathematically correct phase, measurement, interference, and entanglement.
- **Clean visual design:** warm white backgrounds, navy typography, muted blue accents, restrained animation; never neon casino styling, coins, flashing rewards, or fake urgency.
- **Ad-funded but respectful:** advertising never blocks access to the main puzzle experience; no forced ads during gameplay; privacy and age-sensitive policies come before monetization.
- **Offline-first:** all core gameplay, tutorials, progress, and saved levels work without internet. Ads and optional platform services degrade gracefully.

## 1. Product overview and audience

**Genre:** single-player, mobile-first, turn-based quantum circuit puzzle game with optional timed challenges. **Platform:** Android, distributed via Google Play. **Orientation:** portrait primary. **Audience:** general audience including children aged 10+ and adults. **Primary language:** English (all in-game copy and development documentation). **Secondary localization:** prepare string keys for future Spanish, without requiring a translation in v1.

### Core fantasy
A player starts with qubits in a known state and selects quantum gates to reach a target state, probability distribution, or measurement objective. The player learns by experimenting and seeing immediate, scientifically accurate feedback. Success rewards elegant solutions, not repeated ad viewing.

### Core loop
1. Choose a level from a clean, vertically scrolling level list.
2. Read one short objective and see the starting state.
3. Tap or drag gates onto circuit slots; undo and reorder them.
4. View a preview of the resulting state (when allowed by level rules).
5. Tap **Run**; simulate, compare to target, and display a meaningful result.
6. Earn 1–3 stars based on correctness and circuit efficiency, not randomized rewards.
7. Continue, retry, or optionally open a brief explanation.

### Game modes
- **Learn:** untimed guided levels; primary onboarding; all content can be completed without ads.
- **Rush:** optional 45–90 second circuit challenges, unlocked after basic instruction; timer pauses when app loses focus or a system consent dialog opens.
- **Daily Challenge:** deterministic locally generated challenge with a date-based seed; works offline. Avoid falsely implying globally synchronized competition.
- **Practice Lab:** unrestricted experimentation with unlocked gates; no rewards required.

## 2. Game engine and programming stack

**Recommended engine:** Godot 4.x stable, pinned to an exact tested release in the repository; use **GDScript** for game logic and UI. Reason: strong 2D UI tools, fast iteration, lightweight exports, no mandatory account/backend, straightforward unit testing, and open-source licensing. Avoid experimental C# Android export for this project. Use a **custom Android Gradle export** when integrating AdMob or other Android-native SDKs.

**Architecture:** separate pure quantum computation, puzzle validation, level definitions, UI state, save persistence, audio, and Android services. Avoid engine-dependent math so the simulator can be tested headlessly.

Suggested modules:
```
project.godot
scenes/{home,level_select,puzzle,results,settings,practice,consent}/
scripts/core/{complex_math,statevector,quantum_gates,measurement,fidelity}/
scripts/game/{level_schema,level_loader,level_validator,scoring,challenge_generator}/
scripts/ui/{circuit_editor,bloch_view,probability_bars,tutorial_overlay}/
scripts/services/{save_service,audio_service,ads_service,consent_service,analytics_service}/
android/plugins/
assets/{fonts,icons,sfx,music,illustrations}/
data/levels/
tests/{unit,integration,ui}/
docs/
```

**Dependency rules:** pin plugin versions and licenses; document plugin maintenance and compatibility. Avoid unmaintained AdMob plugins. Prefer a small Kotlin/Java Android plugin using the supported Godot Android plugin interface and official Google Mobile Ads SDK if a maintained compatible plugin cannot be validated.

## 3. Graphics, rendering APIs, and visual design

### Visual identity — approved neutral/light design
Reference: the **second, white-background mobile UI concept** approved by the product owner, not the earlier neon sci-fi concept. Implement native, responsive UI rather than embedding the concept image.

| Design token | Hex | Usage |
|---|---|---|
| Background | `#FAFAF8` | Main app canvas, warm off-white |
| Surface | `#FFFFFF` | Cards and controls |
| Primary text | `#142338` | Headlines, body text, primary buttons |
| Secondary text | `#667181` | Descriptions and metadata |
| Primary action | `#253C58` | Play, Run, selected tabs |
| Soft blue | `#7DA7EA` | Circuit gates, charts, highlights |
| Pale blue | `#EAF1FB` | Selected cards and tutorials |
| Border | `#E4E7EB` | Dividers, circuit slots |
| X gate | `#E78F98` | Muted coral gate label |
| Z gate | `#A58DDB` | Muted violet gate label |
| Success | `#3B806C` | Success messaging |
| Error | `#B35E60` | Non-alarming error messaging |

Use a clean sans-serif typeface with a redistributable license (e.g. Inter or Noto Sans), with bundled font files only if licensed. Minimum body text approximately 14–16sp equivalent; interactive touch targets at least 48dp equivalent. Do not rely solely on color for gate identification or correctness.

### Screens
1. **Home:** “Qubit Rush”, subtle atom/Bloch-sphere line illustration, short tagline “Solve quantum puzzles, one gate at a time”, large **Play** button, navigation to Levels, Learn, Challenges, Settings. No login call to action.
2. **Levels:** tabs Fundamentals / Entanglement / Algorithms; list of level cards, completion stars, lock states, no aggressive monetization banners.
3. **Puzzle:** level title and optional timer; objective card; horizontal scrollable circuit editor; gate tray; undo, reset, run; probability bars and optional simplified Bloch sphere; short context hint.
4. **Results:** success/failure, target comparison, concise explanation, stars, next level / retry; optional rewarded hint for a future attempt where legally appropriate.
5. **Settings:** sound, music, haptics, accessibility, privacy policy, ad choices/consent, local progress reset.
6. **Practice Lab:** experiment with gates without time pressure.

### Rendering
- **Default Godot Compatibility renderer** for broad Android device support; verify OpenGL ES 3.0-capable devices. Use 2D CanvasItem/Control nodes and lightweight shaders only where essential.
- Avoid requiring Vulkan or heavy 3D graphics; the Bloch sphere may be a simple 2D vector visualization with a projected axis and state marker.
- Use scalable vector-like primitives for circuit wires, nodes, probability bars, and gates; texture assets should have mobile-appropriate resolutions and compression.
- Layout must respect display cutouts, status/navigation bars, safe areas, screen density, and Android gesture navigation.
- Test aspect ratios 16:9, 19.5:9, 20:9, and tablet sizes. Use dynamic font/layout scaling rather than hardcoded pixel coordinates.
- Support 60 FPS target; render only necessary animations and avoid continuous 3D rendering.

## 4. Animation

Use subtle, purposeful motion: 120–250ms button press and card transitions; 250–450ms gate insertion and circuit execution; restrained success confirmation; probability bars ease smoothly toward calculated values. Provide reduced-motion settings that remove nonessential animation. Animations must never change the quantum computation or conceal incorrect results. Pause animations and gameplay clocks on backgrounding.

## 5. Sound and haptics

Provide a restrained original or appropriately licensed sound palette: gentle gate-placement tick, circuit run pulse, success chime, quiet error cue, and optional ambient loop. Default moderate volume; separate toggles for sound effects, music, and haptics. Honor Android silent-mode expectations where feasible and audio focus; stop or duck audio on interruptions. Do not require headphones. All information must remain understandable with sound off. Bundle and attribute licensed assets.

## 6. Game loops and progression

**Engine loop:** Godot's frame/input loop handles visuals and events; quantum simulation is triggered by circuit changes or Run, not simulated continuously every frame. Use delta-based animation and monotonic timer semantics; timer pauses in background. **Progression loop:** complete puzzles, receive stars, unlock more gates and levels, return for optional challenges. **Session loop:** quick 2–5 minute play sessions, with clear exit and resume.

### Level curriculum — v1 minimum 40 handcrafted levels
- Levels 1–8: basis states, X, identity, measurement probabilities.
- Levels 9–16: Hadamard, superposition, probability versus amplitude.
- Levels 17–24: Z, relative phase, interference, H–Z–H equivalence.
- Levels 25–32: two-qubit states, X/H on selected wires, CNOT, Bell pairs.
- Levels 33–40: circuit efficiency, mixed gates, entanglement, phase-sensitive targets.

Introduce at most one new concept per level. Each tutorial has one-sentence explanation, a visible example, and a simple action. Provide optional “Why?” panels with deeper explanations. No forced reading or school-like tests.

### Sample age-neutral copy
- “A qubit can be measured as 0 or 1.”
- “The X gate flips 0 to 1.”
- “The H gate creates two possibilities.”
- “A probability tells you how often a result appears after many runs.”
- “The Z gate changes a phase. The probability may look the same, but the next gate can reveal the difference.”
- “Two qubits can become linked in a way ordinary bits cannot.”

**Scientific accuracy note:** distinguish superposition from an ordinary classical 50/50 coin; never say a single measurement proves a quantum state. Use statevector fidelity for exact-state objectives and distribution comparison for probability-only objectives.

## 7. Quantum simulation and level validation

### Data representation
Store an n-qubit pure state as an array of `2^n` complex amplitudes. Initial state is `|0...0⟩`. For v1 cap at 3 qubits unless profiling shows room for more. Implement H, X, Y, Z, S, T, CNOT, and measurement; only unlock gates as the curriculum introduces them. Use correct qubit indexing and consistent little-endian/big-endian conventions, documented in tests.

### Required math
- X: `[[0,1],[1,0]]`.
- Z: `[[1,0],[0,-1]]`.
- H: `(1/sqrt(2))*[[1,1],[1,-1]]`.
- CNOT: flip target when control qubit is `1`.
- State probabilities: `P(i) = |amplitude_i|^2`; sum must be approximately 1.
- State fidelity: `F = |<target|actual>|^2`, invariant under global phase.
- Measurement samples from Born probabilities and collapses a **copy** of the state; deterministic state comparison must not depend on a random measurement.

### Level formats
Use versioned JSON resources containing id, title, starting state, qubit count, available gates, max slots, goal type, goal target, optional timer, scoring thresholds, tutorial, and hints. Validate all level data on load. Define objective types `state_fidelity`, `measurement_distribution`, `bell_state`, and `gate_efficiency`. Do not accept circuits based on visually similar probability bars when relative phase matters.

### Scoring
Correct completion is mandatory. Award 1 star for a valid solution, 2 for meeting a reasonable gate-count threshold, and 3 for an efficient solution (and optional time target only in Rush). A player can always replay. Avoid energy systems, paywalls, random loot boxes, or ad-driven scoring.

## 8. Input system and device compatibility

Primary: single-finger touch (tap, swipe, drag/drop), with tap-to-place alternative for motor accessibility. Long press displays a gate description. Support Android Back gesture/button, orientation/screen resize, keyboard and mouse in desktop editor for development/testing, and optional hardware keyboard navigation on tablets. Do not require gamepads, sensors, camera, microphone, contacts, precise location, or external storage permissions.

Circuit editor must offer undo, clear, accessible gate selection, horizontal scroll for larger circuits, visual drop targets, and clear error messages. Provide readable semantic labels and focus order where supported; test with TalkBack and large font settings.

## 9. IDE, Android SDK/NDK, build pipeline

- **Primary IDE:** Godot editor; **Android Studio** for Android SDK manager, emulator, Gradle, Logcat, native plugin debugging.
- **Language:** GDScript for game; Kotlin or Java only for Android-specific AdMob/consent bridge.
- **Java:** JDK 17 unless pinned Godot/Android Gradle Plugin requires otherwise.
- **Android SDK:** install platform/build tools matching current Play requirements; **target API 36 or higher** for new Play submissions as of August 31, 2026. Confirm requirements at build/submission time.
- **Minimum Android version:** start with Android 8.0 (API 26) as a product choice, subject to engine/plugin validation; use 64-bit ARM build support and optionally ARMv7 if practical.
- **NDK:** not needed for ordinary GDScript or a standard Android Gradle export; install a version compatible with pinned engine only if compiling native GDExtension/C++ components.
- **Build artifacts:** debug APK for testing; signed Android App Bundle (`.aab`) for Play release; secure keystore outside source control; use Play App Signing.
- **CI:** headless Godot tests, project import/validation, Android Gradle build, static checks, dependency/license review; protect signing secrets.

Official references:
- Godot Android export: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
- Godot Gradle builds: https://docs.godotengine.org/en/stable/tutorials/export/android_gradle_build.html
- Play target API: https://support.google.com/googleplay/android-developer/answer/11926878

## 10. Resource and memory management

Use shared theme styles and reusable components, preloaded small UI assets, and lazy loading of level-specific resources. Avoid allocating temporary arrays every frame; reuse UI nodes and cache probability computations until a circuit changes. Keep a 2–3 device-tier profiling matrix (low-end, midrange, tablet). Targets: cold launch under ~4 seconds on a midrange device, 60 FPS for UI, no perceptible lag on 3-qubit simulations, memory usage comfortably below device limits, no uncontrolled memory growth over 30-minute sessions. These are performance targets, not claimed benchmarks. Handle Android pause/resume, process termination, audio focus, and memory pressure gracefully.

## 11. Monetization: Google AdMob

### Advertising philosophy
The game is **free to play**, supported by limited ads. Ads are optional whenever possible. Monetization must not exploit children or interrupt learning. No deceptive buttons, fake system alerts, countdown pressure, accidental taps, or ad placements next to Run/Undo.

### Ad formats and placement
1. **Rewarded ad (preferred):** optionally watch to receive one extra hint, an alternate circuit explanation, or a cosmetic theme. Always provide a non-ad path to completing every level; a basic hint is always free. Explicit opt-in and clear reward disclosure.
2. **Interstitial (conditional, conservative):** only at natural breaks after completed levels, never before the first few levels and never during a timer, tutorial, or circuit. Suggested initial cap: at most one per 4 completed levels and no more than one per 10 minutes; remotely adjustable only through compliant configuration, with safe offline defaults. **Disable entirely for child-directed or age-uncertain sessions until policy-reviewed.**
3. **Banner:** not recommended for v1 because it consumes valuable vertical puzzle space and increases accidental tap risk. If introduced later, only on non-gameplay screens with clear spacing and policy review.

### Ad implementation
Integrate the official Google Mobile Ads SDK through a validated Godot Android plugin; use Google UMP (User Messaging Platform) where consent is required. Initialize/load ads only after the applicable privacy/consent flow and age-appropriate ad policy decisions. Use test ad unit IDs in debug builds; production IDs only in release config. Handle no-fill, airplane mode, SDK errors, app pause, ad dismissal, and reward callbacks without breaking gameplay. Grant rewards **only** after verified reward callback, idempotently; never on ad open. Do not promise ad availability. Ensure an offline player can finish the game.

### Critical children/families policy gate
The intended design is understandable to children aged 10, which may make children part of the target audience. **Do not assume that labeling the game “10+” or calling it general audience avoids Google Play Families requirements.** Before integrating live ads, choose and document a defensible Play Console target-audience classification and review the latest Families, ads, child privacy, and applicable regional laws. If children are targeted, use only compliant, appropriately certified ad SDK versions and child-appropriate ad serving/configuration; restrict personalization and data collection as required. If reliable age handling is not implemented, default to the stricter child-safe configuration or disable ads. Never collect date of birth unnecessarily. No ad-driven profiling of children.

References:
- Google Play Families policy: https://support.google.com/googleplay/android-developer/answer/9893335
- Google Play ads policy: https://support.google.com/googleplay/android-developer/answer/9857753
- AdMob Android: https://developers.google.com/admob/android/quick-start
- Google UMP: https://developers.google.com/admob/android/privacy

### Business measurement
Measure ad impressions, rewarded opt-in rate, rewarded completion, ad-related crash rate, and approximate revenue only through compliant, consent-aware SDK reporting. No account identifiers or custom personal profiling. For v1, do not require third-party analytics to play. Add a privacy policy and accurate Google Play Data safety disclosures covering SDK collection and processing.

## 12. Platform services and LiveOps

**v1 offline-first:** guest progress stored locally; no Firebase dependency, Google account, cloud sync, leaderboards, push notifications, or remote backend required. Save progress, stars, settings, unlocked levels, and completed daily challenge using atomic versioned local storage with corruption recovery. Keep no sensitive information in saves.

**Optional future features:** Google Play Games achievements and leaderboards only with explicit opt-in and never as a prerequisite to play; optional cloud save; curated challenge packs; privacy-compliant remote configuration for ad frequency and content. **LiveOps:** monthly curated puzzle packs and rotating challenges can ship through ordinary app updates; no server required. Daily challenge seed should use UTC date with a documented local display policy to avoid timezone confusion.

**Privacy:** no login, no email, no location, no microphone, no contacts, no camera. Android/AdMob may process device and advertising data; document this honestly rather than claiming the entire app collects no data. Provide privacy-policy link, consent revocation/ad settings where applicable, and clear offline behavior.

## 13. First-run UX and instructional approach

Opening the app should show the home screen in under the performance target, with a single obvious Play button. Tapping Play enters the first puzzle directly, not a signup or consent wall unrelated to legal requirements. If an ad consent dialog is legally required before loading ads, defer ad initialization until resolved; allow gameplay without ads meanwhile.

**Level 1:** “Reach |1⟩.” One wire starts at |0⟩; highlight X. Hint: “X flips 0 to 1.” Player taps X then Run. Show “You made |1⟩. Nice work.” **Level 2:** H creates equal 0/1 probabilities; explain that repeated measurements yield about half each. **Level 3:** introduce Z and relative phase; demonstrate that the same measurement probabilities do not mean the same quantum state. **Level 4:** H–Z–H changes |0⟩ into |1⟩. **Level 5+:** gradual two-qubit challenges.

Use one-sentence prompts, progressive disclosure, and a “Learn more” drawer for curious adults. Avoid unnecessary jargon, while preserving correct mathematical labels and an optional detailed explanation.

## 14. Tests and acceptance criteria

### Automated quantum unit tests
- `X|0⟩ = |1⟩`; `X² = I`; `H|0⟩ = |+⟩`; `H² = I`.
- `Z|+⟩ = |−⟩`; `HZH|0⟩ = |1⟩`.
- `CNOT(H⊗I)|00⟩` produces a Bell state under the documented wire ordering.
- `S` and `T` phases are correct; Y is correct including imaginary amplitudes.
- Norm remains 1 within tolerance for all supported gate sequences.
- Fidelity is unchanged by a global phase; relative phase differences are detected.
- Measurement distribution converges statistically with seeded tests; no flaky reliance on single random measurements.
- Invalid circuits, impossible targets, out-of-range qubit indices, and malformed level JSON fail safely.

### Game integration tests
- New user starts without internet, email, account, or ads.
- Every authored level has at least one verified solution and achievable scoring thresholds.
- Save/load and upgrade migrations preserve progress; corrupt save recovers without crash.
- Background/resume preserves circuit and pauses timed levels.
- Gate insertion, undo, reset, scroll, and Run work on touch devices.
- Ad unavailable/declined/consent denied never prevents progression.
- Reward is granted once per verified callback, never twice.
- No ad is displayed during active gameplay, tutorials, or unreviewed child sessions.
- Layout passes phone/tablet, font scaling, TalkBack, and gesture navigation checks.

### Manual release checklist
- Android real-device smoke test on at least one low-end and one midrange phone.
- App Bundle validates and launches from internal Play testing track.
- No debug ad unit IDs or debug keystore in production.
- Privacy policy and Data safety form match actual SDK behavior.
- Target audience and Families policy decision documented and approved.
- Current target SDK/API and Play submission requirements checked.
- Store listing screenshots are honest and correspond to actual gameplay.
- Crash-free startup, offline gameplay, and graceful ad failure confirmed.

## 15. Deliverables and completion standard

Deliver the following artifacts:
1. Fully editable Godot source repository with documented exact engine version.
2. 40 complete playable handcrafted levels plus optional deterministic daily challenge generator.
3. Pure quantum simulator, tested with unit tests and level-solvability checks.
4. Fully functioning portrait mobile UI matching the approved light visual system.
5. Sound and animation assets with license records and reduced-motion option.
6. Guest-only local save system and offline-first behavior.
7. Android AdMob integration with test ads, consent gating, child-safety policy decision, and safe failure handling; do not enable production ads without owner configuration and compliance sign-off.
8. Android export setup, debug APK, and release AAB build workflow (signed AAB only when secure signing materials are available).
9. README with local setup, run, test, build, and Play publication instructions.
10. Test report showing commands, environment, pass/fail counts, known limitations, and reproducible evidence.
11. Privacy-policy draft and Play Console submission checklist (legal review still required).

**Definition of done:** An Android user can install the game, tap Play immediately without an account, complete all 40 scientifically accurate puzzles offline, save progress locally, and optionally view compliant ads at appropriate moments without affecting the core game. Automated tests and actual Android build steps are reproducible. If any external credentials, SDKs, or policy approvals are missing, provide working stubs and a precise integration checklist instead of claiming completion.

## 16. Execution plan for Claude

**Phase A — Foundation:** pin Godot version; create architecture, theme, level schema, quantum math and tests. Build a working 5-level vertical slice on Android. **Exit:** headless tests pass, debug APK runs on a device/emulator.

**Phase B — Full gameplay:** implement 40 validated levels, two-qubit controls, Rush mode, daily challenge, local saves, accessibility, sound, and motion. **Exit:** every level has a verified solution; offline end-to-end test passes.

**Phase C — Ads and compliance:** integrate Android bridge, AdMob test ads, UMP, policy gating, privacy settings, and robust failure handling. **Exit:** ad behavior is testable, never mandatory, and appropriate for the documented audience.

**Phase D — Release readiness:** performance profiling, regression tests, Android AAB pipeline, privacy/store assets, internal testing and bug fixes. **Exit:** reproducible release candidate with documented remaining human-only actions.

At the end of each phase, provide: files changed, tests executed, results, known blockers, and the next concrete steps. Avoid unnecessary web dashboards, HTML prototypes, account systems, or speculative backend infrastructure. Do not silently cut essential tests or scientific accuracy to reduce development effort.


## 17. Mandatory autonomous build–test–fix–verify protocol (non-negotiable)

**Operating instruction for Claude:** Implement the complete specification autonomously. Do not stop after generating code, reporting a failure, or suggesting that the owner fix something. Independently diagnose and repair defects, then rerun the relevant tests and the full regression suite. Do not ask the owner for guidance, confirmation, or debugging assistance for ordinary development decisions. Make reasonable documented choices when requirements leave implementation details open.

### Required iterative execution loop
1. **DEVELOP:** Implement a small, working increment of production game code, assets, and configuration. Do not substitute pseudocode, screenshots, or a web demo.
2. **TEST:** Run applicable unit, integration, level-solvability, UI, Android build, and device/emulator checks. Capture exact commands, exit codes, and machine-readable results where supported.
3. **DIAGNOSE:** For each failed test, build error, runtime exception, crash, or visual defect, inspect logs and identify its root cause.
4. **FIX AUTONOMOUSLY:** Modify the implementation or tests only when the tests themselves are demonstrably incorrect. Never weaken assertions, remove tests, skip failing checks, or change acceptance criteria merely to obtain a green result.
5. **RETEST:** Rerun failed checks and all affected tests after each fix; rerun the complete automated regression suite after integration and before delivery. Continue the loop until all executable required checks pass or a genuine external blocker is demonstrated.
6. **VERIFY:** Independently confirm the test runner's final summary, process exit codes, Android build artifact presence, level-solvability results, and available runtime evidence. A successful command invocation without passing assertions is not a pass.
7. **REPORT:** Deliver a concise final evidence report, not unsupported claims.

### Mandatory quality gates
- **Gate A — Quantum correctness:** all quantum mathematics unit tests pass; seeded measurement tests are stable; normalization, global phase, relative phase, and Bell-state behavior are verified.
- **Gate B — Content completeness:** all 40 levels load, are solvable by a verified circuit, and meet progression/scoring rules. No inaccessible required level.
- **Gate C — Gameplay integration:** onboarding, no-login offline play, input, undo/reset/run, progression, persistence, pause/resume, and accessibility checks pass.
- **Gate D — Ads safety:** AdMob test-mode bridge, consent decisions, declined/unavailable ads, reward callback idempotency, and no-ads-during-gameplay checks pass. Do not activate live ads without the owner's real AdMob configuration and applicable compliance decisions.
- **Gate E — Android delivery:** Godot headless import and tests pass; Android debug APK builds; launch and gameplay smoke tests pass on an available emulator or physical device; AAB build is validated when tooling permits.
- **Gate F — Full regression:** after the last code change, rerun all runnable automated tests and builds; no failing required tests, unexplained skipped tests, or unresolved critical/high-severity defects.

### Explicit no-interruption policy
- Never ask the owner to run a command, inspect a stack trace, choose between routine libraries, approve a bug fix, create test cases, or retry a failed build. Perform these steps yourself with available tools.
- If a tool is temporarily unavailable, attempt safe alternatives, document the limitation, and continue independent work. Do not claim an emulator/device test passed unless actually executed.
- If genuinely blocked by unavailable Android SDK/emulator, missing signing credentials, external Play Console access, AdMob production IDs, or legally required target-audience/compliance decisions, complete all independent work, leave a precise non-secret handoff, and label the affected gate **BLOCKED / NOT VERIFIED**, not PASS. Do not ask for secrets in chat or embed them in source control.
- Do not silently downgrade scope, skip required tests, suppress failures, or falsely claim a production-ready release.
- Do not terminate the task simply because a test failed. Continue diagnosing and fixing within available execution resources; if execution limits prevent completion, preserve reproducible state and list exact remaining steps without claiming success.

### Final test evidence and completion report
Create `reports/FINAL_VERIFICATION.md` and, when feasible, `reports/test-results.json`, containing:
- Environment: Godot version, Android SDK/build tools, JDK, OS, device/emulator availability, relevant plugin versions.
- Exact commands run and their exit codes; tests passed, failed, skipped, and blocked by suite.
- A checklist of quality gates A–F, each marked **PASS**, **FAIL**, or **BLOCKED / NOT VERIFIED**, with links/paths to logs and artifacts.
- All discovered defects and fixes, plus regression test results after the final fix.
- SHA-256 checksums and locations of generated APK/AAB artifacts when produced.
- Honest limitations, especially real-device, Play Console, legal/compliance, and live-ad verification.

**Strict completion rule:** Report **ALL TESTS PASSED** only when every required test that can be executed in the environment has actually been run and passed, no required check is silently skipped, and every unexecutable external check is explicitly identified as **BLOCKED / NOT VERIFIED**. Report **FULLY VERIFIED FOR ANDROID RELEASE** only when every mandatory quality gate, including Android runtime checks and relevant compliance approvals, is genuinely complete. Never equate generated code or a successful compilation with verified gameplay.
