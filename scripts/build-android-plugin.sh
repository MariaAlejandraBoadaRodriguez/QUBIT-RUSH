#!/usr/bin/env bash
# Builds the QubitRushAds Android plugin AARs into addons/qubitrush_ads/bin/.
set -euo pipefail
cd "$(dirname "$0")/../android/plugins/qubitrush-ads"
: "${ANDROID_HOME:=$HOME/android-sdk}"
echo "sdk.dir=$ANDROID_HOME" > local.properties
./gradlew --no-daemon -q copyAarToAddon
ls -la ../../../addons/qubitrush_ads/bin/
