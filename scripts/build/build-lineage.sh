#!/bin/bash
# Build LineageOS 14.1 for the Pixi 3 (10). First build: roughly 3-5 h on 8 threads / 24 GB RAM; ccache makes later ones fast.
#
# usage: build-lineage.sh [TARGET...]      default target: bacon (flashable zip + boot.img + system.img)
#   build-lineage.sh bootimage             kernel/ramdisk only
#   build-lineage.sh systemimage bootimage the two images used for the fastboot install
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
cd "$LINEAGE_ROOT"

# envsetup.sh/lunch are not -u safe
set +u
source build/envsetup.sh
prebuilts/misc/linux-x86/ccache/ccache -M 40G
lunch lineage_pixi3_8079-userdebug
set -u

make -j"$JOBS" "${@:-bacon}"

ls -la out/target/product/pixi3_8079/*.zip out/target/product/pixi3_8079/*.img 2>&1 || true
