#!/bin/bash
# Build the TWRP recovery for the Pixi 3 (10). TWRP is built with the tablet's OWN stock recovery kernel,
# which is taken from your backup (recovery.bin from backup-small.ps1), so no kernel binary ships in this repo.
#
# usage: build-twrp.sh PATH/TO/recovery.bin
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
RECOVERY_BIN=${1:?usage: build-twrp.sh PATH/TO/recovery.bin}

# --- source (minimal TWRP, Android 5.1 based)
if [ ! -d "$TWRP_ROOT/build" ]; then
    mkdir -p "$TWRP_ROOT"
    cd "$TWRP_ROOT"
    repo init --depth=1 -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni.git -b twrp-5.1 < /dev/null
    repo sync -c --no-tags --no-clone-bundle -j"$JOBS" --force-sync
fi
cd "$TWRP_ROOT"

# --- device tree + prebuilt kernel from your recovery.bin
rm -rf device/alcatel/ttab
mkdir -p device/alcatel
cp -a "$REPO_ROOT/twrp/device/alcatel/ttab" device/alcatel/ttab
tmp=$(mktemp -d)
python3 "$REPO_ROOT/tools/unpack.py" "$tmp" "$RECOVERY_BIN"
cp "$tmp"/*/kernel.bin device/alcatel/ttab/kernel
rm -rf "$tmp"

# --- two fixes for building the 5.1 TWRP tree on Ubuntu 18.04
[ -e /usr/include/asm ] || sudo ln -s /usr/include/x86_64-linux-gnu/asm /usr/include/asm
sed -i 's/\bnullptr\b/NULL/g' bootable/recovery/partition.cpp

set +u
source build/envsetup.sh
lunch omni_ttab-eng
set -u
mka recoveryimage -j"$JOBS"
ls -la out/target/product/ttab/*.img
