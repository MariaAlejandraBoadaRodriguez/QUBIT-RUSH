#!/usr/bin/env bash
# Builds the QubitRushAds Android plugin AARs into addons/qubitrush_ads/bin/.
set -euo pipefail
cd "$(dirname "$0")/../android/plugins/qubitrush-ads"
: "${ANDROID_HOME:=$HOME/android-sdk}"
[ -d "$ANDROID_HOME/platforms" ] || { echo "Android SDK not found at ANDROID_HOME=$ANDROID_HOME (run scripts/setup-env.sh)" >&2; exit 1; }
echo "sdk.dir=$ANDROID_HOME" > local.properties
./gradlew --no-daemon -q copyAarToAddon
ls -la ../../../addons/qubitrush_ads/bin/
