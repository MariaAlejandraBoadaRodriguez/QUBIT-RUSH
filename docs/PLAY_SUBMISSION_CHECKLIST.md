# Play Console submission checklist (owner)

Legal review is still required. Items marked (auto) are already handled in the repository.

## Build
- [ ] Signed release AAB built with `scripts/build-release-aab.sh` (upload key from a secure location, Play App Signing enabled).
- [x] (auto) targetSdk 36, minSdk 26, arm64-v8a + armeabi-v7a.
- [ ] Confirm current target API requirement at submission time: https://support.google.com/googleplay/android-developer/answer/11926878
- [x] (auto) No debug ad unit IDs in release: release builds include AdMob only with owner-supplied IDs.
- [x] (auto) No debug keystore in release: release export requires `GODOT_ANDROID_KEYSTORE_RELEASE_*` env vars.
- [ ] Version code incremented for each upload (`export_presets.cfg` `version/code`).

## Store listing
- [ ] Title "Qubit Rush", short description, full description (honest; no fake urgency).
- [ ] Screenshots captured from the real game (`tools/screenshots.gd` or the CI emulator artifacts).
- [ ] App icon 512×512 (source: `assets/icons/icon.svg`), feature graphic 1024×500.
- [ ] Category: Puzzle (or Educational).

## Policy
- [ ] Target audience and content (see `docs/COMPLIANCE.md`); Families programme if children are targeted.
- [ ] Content rating questionnaire (IARC).
- [ ] Ads declaration: "Contains ads" = yes only if AdMob IDs are configured.
- [ ] Data safety form (see `docs/COMPLIANCE.md`).
- [ ] Privacy policy URL (draft text in `data/privacy_policy.txt`).
- [ ] App access: no login required.

## Testing
- [ ] Internal testing track: install from Play, crash-free start, offline play, ad failure handling.
- [ ] Real-device smoke test on one low-end and one mid-range phone (Android 8.0+).
- [ ] TalkBack and large font pass on a device.
- [ ] Pre-launch report reviewed.
