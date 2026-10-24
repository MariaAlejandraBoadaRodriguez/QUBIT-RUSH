# Ads integration (AdMob + UMP)

## Architecture
```
GDScript (policy)                          Android (SDK calls only)
ConsentService  ── ads choice, UMP status   QubitRushAdsPlugin.java (Godot plugin v2)
AdsService      ── gating, caps, rewards ─▶   ├─ Google UMP 4.0.0 (consent form / privacy options)
AndroidAdsProvider (bridge)                   └─ Google Mobile Ads 25.5.0 (rewarded, interstitial)
MockAdsProvider (tests/desktop)
```
- Plugin source: `android/plugins/qubitrush-ads/` (Java, Gradle library). Build: `scripts/build-android-plugin.sh` → `addons/qubitrush_ads/bin/*.aar` (not committed).
- Godot export plugin: `addons/qubitrush_ads/export_plugin.gd` adds the AAR, Maven dependencies and the `com.google.android.gms.ads.APPLICATION_ID` manifest entry to **Gradle** exports.
- Requires `gradle_build/use_gradle_build=true` and the Android build template (`scripts/install-android-template.sh`).

## Flow
1. App starts. No ads SDK call happens. Gameplay is available immediately.
2. Player opens Settings > Ad choices (or is offered an optional rewarded hint) and taps **Allow optional ads**.
3. `requestConsent(underAgeOfConsent = child_safe)` runs Google UMP. A form appears only if UMP says it is required.
4. If UMP reports `canRequestAds`, ConsentService stores `obtained`/`not_required`; AdsService initialises Mobile Ads with the child-safe `RequestConfiguration` and preloads one rewarded ad.
5. On the results screen (never during gameplay/tutorial/timer), a rewarded offer appears only if an ad is loaded. Reward → one extra hint for that level's next attempt.
6. **No ads** or **Privacy options** revokes at any time.

## Policy settings (`data/config/ads_config.json`)
| Key | Default | Notes |
|---|---|---|
| `audience_policy` | `child_safe` | `general` only after the owner records a non-child Play target audience |
| `rewarded_enabled` | `true` | opt-in only |
| `interstitial_enabled` | `false` | and always off under `child_safe` |
| `interstitial_first_after_level` / `_min_levels_between` / `_min_seconds_between` | 6 / 4 / 600 | SPEC §11 caps |
| `max_ad_content_rating` | `G` | |
| `android.*` | Google **test** IDs | production IDs are never committed |

## Production configuration (owner)
Set at release export time (CI secrets or local shell), never in git:
```
export QUBITRUSH_ADMOB_APP_ID="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"
export QUBITRUSH_ADMOB_REWARDED_UNIT="ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ"
export QUBITRUSH_ADMOB_INTERSTITIAL_UNIT=""          # optional, unused under child_safe
export QUBITRUSH_AUDIENCE_POLICY="child_safe"         # or "general" after Play review
```
Without `QUBITRUSH_ADMOB_APP_ID`, a **release** export contains no ads SDK at all (the game is fully playable; ads are simply unavailable). Debug exports always use Google's public test IDs.

## Integration checklist (owner)
- [ ] Decide and record the Play Console target audience (see `docs/COMPLIANCE.md`).
- [ ] If children are in the target audience: enrol in Families, confirm the AdMob SDK version is on Google's Families self-certified list at submission time, keep `child_safe`.
- [ ] Create the AdMob app and a rewarded ad unit; mark the app as child-directed in AdMob if applicable.
- [ ] Configure UMP messages (GDPR/US states) in the AdMob Privacy & messaging tab.
- [ ] Publish `app-ads.txt` on the developer website.
- [ ] Provide the env vars above to the release build; verify test ads on an internal test track first.
- [ ] Update the Data safety form to reflect the Mobile Ads SDK (see `docs/PLAY_SUBMISSION_CHECKLIST.md`).

## Verification status
- Policy logic: automated GUT tests in `tests/integration/test_ads_policy.gd` with `MockAdsProvider` (consent gating, declined/unavailable, no-fill, SDK errors, reward idempotency, no ads during gameplay, child-safe interstitial block, frequency caps).
- Plugin compiles against Godot 4.7.2 `godot-lib` and Mobile Ads 25.5.0 / UMP 4.0.0.
- **Not verified:** live test-ad display on a device/emulator (no emulator here; CI emulator smoke test does not opt into ads). Production ads: BLOCKED on owner configuration.
