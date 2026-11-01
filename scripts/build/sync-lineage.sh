#!/bin/bash
# Download the LineageOS 14.1 (cm-14.1) source: ~30 GB shallow. Safe to re-run to resume.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"

mkdir -p "$LINEAGE_ROOT"
cd "$LINEAGE_ROOT"

repo init --depth=1 -u https://github.com/LineageOS/android.git -b cm-14.1 < /dev/null
repo sync -c --no-tags --no-clone-bundle --force-sync -j"$JOBS"

# The prebuilt WebView is stored in git-lfs; without this the 32-bit APK is a 130-byte pointer file.
# (Only the arm variant is needed: this tablet is armv7.)
( cd external/chromium-webview/prebuilt/arm && git lfs pull )

echo "Synced to $LINEAGE_ROOT"
