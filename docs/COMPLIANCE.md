# Children, families and privacy — compliance notes

**Status: decision required from the owner. Legal review required before release.**

## Facts about the app
- Content is designed to be understandable from age 10; adults are also an audience. This likely makes children part of the target audience under Google Play's Families policy, regardless of a "10+" label (SPEC §11).
- No account, login, email, phone, location, contacts, camera, microphone or date-of-birth collection. Progress is stored locally only.
- The only third-party SDKs that can process data are the Google Mobile Ads SDK and UMP, and only after the player opts into optional ads.

## Default configuration until the owner decides (implemented)
- `audience_policy = child_safe`: `tagForChildDirectedTreatment = true`, `tagForUnderAgeOfConsent = true`, `maxAdContentRating = G`; non-personalised ads only; **no interstitials**; rewarded ads only on opt-in, outside gameplay.
- No age gate is implemented. Because reliable age handling is absent, the stricter configuration applies to everyone (SPEC §11).

## Owner decisions needed
1. Play Console target age groups (e.g. include 9–12 / 13–15 → Families programme applies).
2. If Families applies: confirm the exact Mobile Ads SDK version is Families self-certified at submission time; keep child-directed treatment.
3. Whether to ship ads at all in v1 (the game is complete without them; a release built without AdMob env vars has no ads SDK).
4. Privacy policy hosting URL and contact address.
5. Regional laws review (COPPA, GDPR-K/UK Age Appropriate Design Code, US state laws).

## Data safety form (draft mapping, verify against the SDK version shipped)
| Build | Data collected/shared | Purpose |
|---|---|---|
| Without ads SDK | None | — |
| With ads SDK (opt-in) | Device or other IDs (advertising ID, where permitted), app interactions/diagnostics, approximate location derived from IP (by Google) | Advertising, fraud prevention, analytics (by Google) |
The app itself transmits nothing. Data is encrypted in transit by the SDK. Users can withdraw via Ad choices.
