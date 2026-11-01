#!/bin/bash
# Shared settings for the build scripts. Override any of these from the environment.
#
# Build INSIDE the Linux filesystem (e.g. /home/you/...), never under /mnt/c or /mnt/e on WSL:
# NTFS is slow and case-insensitive, and the Android build breaks on it.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

export LINEAGE_ROOT=${LINEAGE_ROOT:-$HOME/lineage}   # LineageOS 14.1 source tree (~45 GB synced, ~130 GB with a build)
export TWRP_ROOT=${TWRP_ROOT:-$HOME/twrp-src}        # TWRP source tree
export JOBS=${JOBS:-8}

# Revision of mt8127/android_kernel_alcatel_ttab (branch cm-14.1) the kernel patches were made and tested against.
export KERNEL_URL=https://github.com/mt8127/android_kernel_alcatel_ttab
export KERNEL_REV=557d9dfd7005a24215f98e70dfe7db0f6bb0916c

# The Android 7.1 build wants these.
export LC_ALL=C
export ALLOW_MISSING_DEPENDENCIES=true
export USE_CCACHE=1
export CCACHE_DIR=${CCACHE_DIR:-$HOME/.ccache}
export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx6g"
