# Building

The Android 7.1 build wants **Ubuntu 18.04** (OpenJDK 8, python2, the 18.04-era toolchain), about **130 GB** of free
disk (source about 45 GB, `out/` about 35 GB, ccache up to 40 GB) and plenty of RAM. The reference build used 8 threads,
20 GB of RAM and 16 GB of swap; the first full build takes roughly 3 to 5 hours.

All the commands below are the scripts in [`scripts/build`](../scripts/build). Their paths come from
[`env.sh`](../scripts/build/env.sh) (`LINEAGE_ROOT`, `TWRP_ROOT`, `JOBS`, ...); override them from the environment.

## 1. Build host

Any Ubuntu 18.04 machine works. On Windows use **WSL2**:

- Import an Ubuntu 18.04 root filesystem onto a disk with plenty of space (`wsl --import`), and **build inside its own ext4
  disk** (`/home/you/...`), never under `/mnt/c` or `/mnt/e`: NTFS is slow and case-insensitive.
- WSL keeps file cache in RAM until it is restarted. A `%UserProfile%\.wslconfig` helps on a PC that also has to run Windows:

  ```ini
  [wsl2]
  memory=20GB
  swap=16GB
  processors=8
  [experimental]
  autoMemoryReclaim=gradual
  ```

  It takes effect after `wsl --shutdown`. (Do not drop the page cache during a build: it makes it slower.)

Then, as a normal user with `sudo`:

```bash
scripts/build/install-host-deps.sh
```

It installs the packages, the `repo` tool and git-lfs, and re-allows TLS 1.0/1.1 in OpenJDK 8. That last change is
needed because Jack, the Java compiler server of Android 7.1, talks to itself over them and the build dies with an
"SSL error" otherwise; the original file is kept as `java.security.orig`.

## 2. TWRP

Needs only your `recovery.bin` from the backup ([INSTALL.md](INSTALL.md#1-back-up-read-only-cannot-brick)):

```bash
scripts/build/build-twrp.sh /path/to/recovery.bin
# -> $TWRP_ROOT/out/target/product/ttab/recovery.img
```

It syncs the minimal TWRP (Android 5.1) manifest, installs `twrp/device/alcatel/ttab`, and uses **the tablet's own
recovery kernel** (unpacked from your `recovery.bin` with [`tools/unpack.py`](../tools/unpack.py)) as the prebuilt kernel. It also applies two
fixes that Ubuntu 18.04 needs for this old tree: an `/usr/include/asm` symlink and `nullptr` to `NULL` in
`bootable/recovery/partition.cpp`.

Flash it and dump your stock system next ([INSTALL.md](INSTALL.md#3-twrp)).

## 3. LineageOS

```bash
scripts/build/sync-lineage.sh               # repo init -b cm-14.1 + sync (about 30 GB) + git lfs pull for the WebView
```

Loop-mount the stock system dump so the blobs can be read from it:

```bash
mkdir -p ~/stock/system
sudo mount -o loop,ro /path/to/system_p6.img ~/stock/system
scripts/build/setup-tree.sh ~/stock
```

`setup-tree.sh` does four things, and is safe to re-run (do re-run it after any `repo sync`, which discards local patches):

| Step | What |
|---|---|
| device tree | copies `device/alcatel/pixi3_8079` into the tree |
| kernel | clones `mt8127/android_kernel_alcatel_ttab` at the tested revision into `kernel/alcatel/pixi3_8079` and applies [`kernel/patches`](../kernel/patches) with `git am --keep-cr` |
| `frameworks/av` | applies the three MediaTek patches from the device tree (colour format, camera, microphone) |
| blobs | runs `extract-files.sh ~/stock`, creating `vendor/alcatel/pixi3_8079` from your tablet |

Kernel patch note: the Goodix touch driver files have CRLF line endings, so the patches carry CRs and **must be applied
with `--keep-cr`** (plain `git am` strips them and the touch patches fail).

Then build:

```bash
scripts/build/build-lineage.sh                          # bacon: zip + boot.img + system.img
scripts/build/build-lineage.sh systemimage bootimage    # just the two images used by the fastboot install
```

The lunch target is `lineage_pixi3_8079-userdebug`. Outputs are in `$LINEAGE_ROOT/out/target/product/pixi3_8079/`.
Continue with [INSTALL.md](INSTALL.md#6-flash).

### About the blobs

The device tree ships **no** vendor files. `proprietary-files.txt` lists 170-odd libraries and firmware files taken from the stock
`/system` (Mali, MediaTek OMX codecs, audio, the CONSYS Wi-Fi/Bluetooth combo chip, GPS, and so on), and
`extract-files.sh` copies them from the tree you give it. If your stock build differs from `vE6I-0`, a few entries may be
missing; remove or replace them in that file. One entry deserves a note: `lib/libstlport.so` is **mandatory** (see
[PORTING-NOTES.md](PORTING-NOTES.md#bring-up-failures-and-their-causes)).

## Kernel only

For quick iteration on the kernel (fresh upstream clone, no Android tree needed):

```bash
scripts/build/build-kernel.sh /path/to/kernel      # Ubuntu's gcc-arm-linux-gnueabi (GCC 7), ARCH=arm
# -> $OUT/arch/arm/boot/zImage
python3 tools/mkboot.py backup/small/bootimg.bin zImage boot-test.img    # swap the kernel into an existing boot image
```

`mkboot.py` keeps the existing ramdisk and board header and re-wraps the kernel with the MediaTek header the bootloader
expects, so it can be used to test a new kernel against the stock ramdisk. With the bootloader's lack of `fastboot boot`,
a test means `fastboot flash boot`; keep `backup/small/bootimg.bin` to put the original back.

## Troubleshooting a build

| Symptom | Cause / fix |
|---|---|
| Jack: `SSL error` / `Communication error with Jack server` | TLS 1.0/1.1 disabled in OpenJDK 8: `install-host-deps.sh` fixes it. |
| `asm/types.h: No such file` while building the kernel | Stale generated headers in an old source tarball. Use the upstream git clone that `setup-tree.sh` makes. |
| `git am` fails on the touch patches | Missing `--keep-cr`. |
| WebView step fails / tiny `webview.apk` | `git lfs pull` was not run in `external/chromium-webview/prebuilt/arm`. |
| `dhcpcd-run-hooks` / `dhcp6c.script` missing from the blob list | These come from AOSP, not from the stock ROM; they are not in `proprietary-files.txt`. |
| Out of memory, the WSL VM dies | Raise `memory`/`swap` in `.wslconfig`, or lower `JOBS`. |
| Everything builds but the tablet shows only the Alcatel logo | See [PORTING-NOTES.md](PORTING-NOTES.md#bring-up-failures-and-their-causes). |
