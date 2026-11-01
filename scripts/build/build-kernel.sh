#!/bin/bash
# Standalone kernel build (quick iteration; the LineageOS build compiles the kernel itself).
# Output: $OUT/arch/arm/boot/zImage
#
# usage: build-kernel.sh [KERNEL_DIR]    default: $LINEAGE_ROOT/kernel/alcatel/pixi3_8079
# Package it into a boot image with tools/mkboot.py (keeps the ramdisk and MTK headers of an existing image):
#   python3 tools/mkboot.py bootimg.bin zImage boot-test.img
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
SRC=${1:-$LINEAGE_ROOT/kernel/alcatel/pixi3_8079}
OUT=${OUT:-$HOME/pixi3-kernel-out}

export ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-    # Ubuntu's GCC 7 cross compiler (gcc-arm-linux-gnueabi)
mkdir -p "$OUT"
cd "$SRC"
make O="$OUT" pixi3_8079_defconfig
make O="$OUT" -j"$JOBS" zImage
ls -la "$OUT/arch/arm/boot/zImage"
