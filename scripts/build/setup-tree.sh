#!/bin/bash
# Put the Pixi 3 pieces into a synced LineageOS 14.1 tree:
#   device/alcatel/pixi3_8079       device tree (from this repo)
#   kernel/alcatel/pixi3_8079       upstream ttab kernel + the three patches in kernel/patches/
#   frameworks/av                   the three MediaTek patches (they are lost by every `repo sync`: re-run this script)
#   vendor/alcatel/pixi3_8079       proprietary blobs extracted from YOUR tablet's stock /system
#
# usage: setup-tree.sh [STOCK_ROOT]
#   STOCK_ROOT   directory that contains the tablet's stock `system/` (e.g. a loop mount of a dump of the
#                system partition, or `adb pull /system` from TWRP). Omit to skip blob extraction.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
STOCK_ROOT=${1:-}

[ -d "$LINEAGE_ROOT/build" ] || { echo "No LineageOS tree at $LINEAGE_ROOT - run sync-lineage.sh first"; exit 1; }
cd "$LINEAGE_ROOT"

# --- device tree
mkdir -p device/alcatel
cp -a "$REPO_ROOT/device/alcatel/pixi3_8079" device/alcatel/
echo "device tree installed"

# --- kernel (patches need --keep-cr: the Goodix touch driver files have CRLF line endings)
if [ ! -d kernel/alcatel/pixi3_8079/.git ]; then
    mkdir -p kernel/alcatel/pixi3_8079
    git -C kernel/alcatel/pixi3_8079 init -q
    git -C kernel/alcatel/pixi3_8079 remote add origin "$KERNEL_URL"
    git -C kernel/alcatel/pixi3_8079 fetch --depth 1 origin "$KERNEL_REV"
    git -C kernel/alcatel/pixi3_8079 checkout -q FETCH_HEAD
    git -C kernel/alcatel/pixi3_8079 -c user.name=pixi3-port -c user.email=pixi3-port@localhost \
        am --keep-cr "$REPO_ROOT"/kernel/patches/*.patch
fi
echo "kernel installed"

# --- frameworks/av patches (applied once; skip if already there)
if ! git -C frameworks/av log --oneline -20 | grep -q 'MediaTek: Fix Microphone'; then
    git -C frameworks/av -c user.name=pixi3-port -c user.email=pixi3-port@localhost \
        am --whitespace=nowarn --keep-cr "$LINEAGE_ROOT"/device/alcatel/pixi3_8079/patches/frameworks/av/*.patch
fi
echo "frameworks/av patched"

# --- proprietary blobs
if [ -n "$STOCK_ROOT" ]; then
    "$LINEAGE_ROOT"/device/alcatel/pixi3_8079/extract-files.sh "$STOCK_ROOT"
    echo "blobs extracted to vendor/alcatel/pixi3_8079"
else
    echo "Skipped blob extraction (no STOCK_ROOT given): the build will fail until vendor/alcatel/pixi3_8079 exists."
fi
