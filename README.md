# LineageOS 14.1 for the Alcatel OneTouch Pixi 3 (10) WiFi

An unofficial port of **LineageOS 14.1 (Android 7.1.2)** to the **Alcatel OneTouch Pixi 3 (10) WiFi, model 8079**
(TCL, MediaTek MT8127), a tablet that never got an update past Android 5.0.1.

This repository has everything needed to reproduce the port: the device tree, the kernel patches
(including a panel driver that was **reverse-engineered from the stock kernel**), a TWRP recovery tree, the
scripts for backup / unlock / flashing / building, and notes on how every problem was solved.

> **Status: alpha, tested on a single unit.** It boots, and display, touch, Wi-Fi and Bluetooth work. The **cameras do
> not work** yet, SELinux is still **permissive**, and this is a **userdebug build with insecure ADB defaults**.
> Read [docs/STATUS.md](docs/STATUS.md) before you flash, and see [Security](#security) before you connect it to a network you care about.

| | |
|---|---|
| **Device** | Alcatel OneTouch Pixi 3 (10) WiFi, model **8079** (codename used here: `pixi3_8079`) |
| **SoC / RAM / storage** | MediaTek MT8127 (4x Cortex-A7, Mali-450), 1 GB, 8 GB eMMC |
| **Display / touch** | 10.1", 800x1280, Raydium RM68200 (TXD module) / Goodix GT9xx |
| **ROM** | LineageOS 14.1 (Android 7.1.2), kernel 3.10.108 |
| **Stock firmware tested** | build `vE6I-0` (Android 5.0.1) |

## What works

| | |
|---|---|
| Display, incl. sleep / wake | Works |
| Touchscreen | Works (after fixing a driver bug that reset the controller every 2.3 s) |
| Wi-Fi | Works |
| Bluetooth | Turns on (pairing untested). The MAC address is a placeholder |
| Accelerometer, battery gauge, thermal, internal storage | Work |
| Charging | Works (verified with this same kernel under the stock ROM) |
| Audio | The speaker route is set up; a hands-on listening test is still pending |
| ADB over USB and over Wi-Fi | Work |
| **Cameras** | **Not working** (no camera devices; sensor drivers are missing from the kernel) |
| Light / proximity / gyro | Not detected (the hardware is probably absent) |
| GPS, FM radio | Untested |
| SELinux | Permissive (about 70 known denials still to be fixed) |

The full list, with how each item was checked, is in [docs/STATUS.md](docs/STATUS.md).

## Is my tablet supported?

Only if it is the **8079** with the **RM68200 (TXD)** panel and Goodix touch controller, the combination this was developed on.
The stock firmware also supports three other panel variants and a FocalTech touch controller; on those units the
kernel in this repo will **not** bring up the display. How to check your unit, and how to add another panel with the
included tools, is in [docs/HARDWARE.md](docs/HARDWARE.md).

## Install

The short version (details, driver notes and troubleshooting are in **[docs/INSTALL.md](docs/INSTALL.md)**):

1. **Back up first.** `scripts\windows\backup-small.ps1` dumps the irreplaceable partitions (nvram with your serial and MACs,
   calibration, bootloader, boot, recovery) over MediaTek's BROM. This cannot brick the tablet, and neither can
   anything else here: the BROM boot mode on this chip is unprotected, so a bad flash can always be undone from the PC.
2. Unlock the bootloader: `fastboot oem unlock` (erases all data).
3. Flash TWRP, then `boot.img` and `system.img` with fastboot; format data and cache from TWRP.

**There are no prebuilt images in this repository** (they contain proprietary MediaTek blobs from the stock ROM, which
is not ours to redistribute). You build them yourself from your own tablet's firmware: see below.

## Build

You need an Ubuntu 18.04 host (native, VM or WSL2), about 130 GB of disk and plenty of RAM (it was built with 20 GB of RAM plus 16 GB of swap).
The scripts in [scripts/build](scripts/build) do each step; [docs/BUILD.md](docs/BUILD.md) explains them.

```bash
scripts/build/install-host-deps.sh      # packages, repo, Jack TLS fix
scripts/build/sync-lineage.sh           # ~30 GB source download
scripts/build/setup-tree.sh ~/stock     # device tree + kernel + patches + blobs from YOUR tablet's /system
scripts/build/build-lineage.sh          # 3-5 h the first time; ccache makes the rest quick
scripts/build/build-twrp.sh recovery.bin
```

## Repository layout

```
device/alcatel/pixi3_8079/    LineageOS device tree (blobs are extracted from your own tablet, not shipped)
kernel/patches/               3 patches on top of mt8127/android_kernel_alcatel_ttab (cm-14.1)
twrp/device/alcatel/ttab/     TWRP device tree (the prebuilt kernel is taken from your own recovery backup)
scripts/windows/              mtkclient setup, BROM backup, BROM restore (PowerShell)
scripts/build/                build host setup, source sync, tree setup, LineageOS / kernel / TWRP builds
scripts/device/               script to run in TWRP that formats /data and /cache correctly
tools/                        boot image unpack / repack, ARM kernel disassembler used for the panel driver
docs/                         install, build, hardware, status, recovery, and the porting notes
```

## How it was done

The stock Android 5.0.1 kernel boots the tablet, but the closest open-source kernel (the Telekom Puls "ttab" tree,
same TCL board family) has no driver for this panel: it panics in `init_dsi` and bootloops. The RM68200 driver in
[kernel patch 0001](kernel/patches) was reconstructed from the stock kernel binary: DSI timings, power-up sequence,
init commands and the ESD check were all read out of the machine code and verified against the original.
Getting from "kernel boots" to "LineageOS boots" took three more root causes, including a hang in `init_user0` and
every native process aborting at start-up because a library Android 7.1 no longer ships was `LD_PRELOAD`ed.
[docs/PORTING-NOTES.md](docs/PORTING-NOTES.md) tells the whole story, including the debugging techniques that worked
without a serial console.

## Security

The tablet's vendor stopped issuing security patches years ago and LineageOS 14.1 is long end-of-life,
so treat this device as **untrusted on your network**. On top of that, this build is a bring-up build:

- it is a `userdebug` build with **ADB enabled and RSA authentication off by default** (`ro.adb.secure=0`),
- SELinux is permissive.

Put the tablet on a guest network that cannot reach your LAN, and turn off *USB debugging*, *ADB over network* and
*Root access* in Developer options once you are done. Details: [docs/STATUS.md](docs/STATUS.md#security-notes).

## Credits and licenses

- [LineageOS](https://lineageos.org/) and the Android Open Source Project.
- The **mt8127** GitHub organisation: [android_device_alcatel_ttab](https://github.com/mt8127/android_device_alcatel_ttab) and
  [android_kernel_alcatel_ttab](https://github.com/mt8127/android_kernel_alcatel_ttab) are the base of the device tree and kernel; the
  [TWRP ttab tree](https://github.com/mt8127/TWRP_android_device_alcatel_ttab) is the base of the recovery.
- [mtkclient](https://github.com/bkerler/mtkclient) by B. Kerler, for BROM access to the MT8127.
- [vmlinux-to-elf](https://github.com/marin-m/vmlinux-to-elf), used to recover the symbols of the stripped stock kernel.

Original files in this repository are under the **Apache License 2.0** ([LICENSE](LICENSE)); the kernel patches
are derivative works of the Linux kernel and therefore **GPL-2.0**. Files taken from the projects above keep their own licenses and headers.

This is an unofficial community project, **not affiliated with Alcatel, TCL or LineageOS**.
You flash it at your own risk; read [docs/INSTALL.md](docs/INSTALL.md) and make the backup.
