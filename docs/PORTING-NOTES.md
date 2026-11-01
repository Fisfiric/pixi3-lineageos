# Porting notes

How the port was done, what broke and why. Written so the next person (for another panel variant, or another
MT8127 tablet) can reuse the techniques, not only the result. Hardware facts are in [HARDWARE.md](HARDWARE.md).

## 1. Strategy

The tablet has no upstream support, no source drop for its exact board, and a bootloader that cannot `fastboot boot`.
The plan was: **keep the stock bootloader, reuse a sibling device's open-source work, and reverse-engineer only the
parts that are really specific to this unit.**

- Donor: the `mt8127` GitHub organisation's **"ttab"** (Telekom Puls 8", a TCL design). The stock preloader of the Pixi 3 (10)
  is literally named `preloader_ttab.bin`, and the partition layout and resolution match. It provides a LineageOS 14.1 device
  tree, a Nougat-patched 3.10.108 kernel and a TWRP tree.
- What the donor cannot provide: the kernel's `pixi3_10` board directory is a MediaTek reference template (wrong sensors,
  a different panel), and it has no driver for this tablet's panel. So `ttab_defconfig` is the base, and the panel driver is new.
- Target: LineageOS **14.1**. The donors use it, 3.10 kernels and non-Treble MediaTek blobs cannot realistically run 15.1+.

A rule that paid off: every phase ended in a gate ("TWRP boots, touch works, adb root" before the kernel; "custom kernel boots
the stock ROM" before Nougat), so that a failure in a later phase could not be blamed on an earlier one.

## 2. Reconnaissance and safety net

- **BROM is open.** `mtkclient` reports secure boot, SLA and DAA all off, so it can read and write any partition. That is
  what makes experimenting cheap. Two non-obvious requirements on this chip: the legacy download agent needs the device's *own*
  preloader to configure DRAM (`--preloader preloader_ttab.bin`; the auto-selected one hangs with `RAM-Length: 0x0`), and the
  stage-2 reconnect hangs unless `--noreconnect` is passed. On Windows the BROM port is bound to the `usbser` driver, which
  libusb can only open through **UsbDk** (`scripts/windows/mtkclient-usbdk.patch`).
- **Minimal backup** instead of a full eMMC image: everything before `custpack` (about 70 MB), which contains the unit-specific
  `nvram`, `protect_f/s`, `pro_info`, `sec_ro`, and the bootloader / boot / recovery.
- **The firmware zip is not the tablet's firmware.** The downloadable stock package is build `vE6A` (kernel 2017-08-24); the
  tablet runs `vE6I` (kernel 2020-10-13), and the kernels differ. Anything that must match (kernel, blobs) was taken from the
  tablet's own boot image and `/system`.
- **LK fastboot:** `oem unlock` (confirm with Volume Up) works; `flash` works; `boot` does not. So every test is a real
  flash. The stock images and BROM make that safe, and `restore-stock.ps1` was written and dry-run before the first write.
- **Hardware census** in TWRP (root adb): `/proc/cmdline` revealed the panel (`lcm=1-rm68200_txd_wxga_pixi3`), the I2C
  map, the bound drivers (Goodix GT9xx at 1-0x5d, BMA2xx, BQ24158) and a GPIO dump that replaces the board DCT file. The
  stock kernel registers drivers for hardware this unit does not have (FocalTech touch, MC3XXX), so *bound* drivers in
  `dmesg` are the ground truth, not the list of drivers in the binary.

## 3. TWRP

The donor TWRP tree plus the tablet's **own recovery kernel**, `--board vE6I-0`, crypto off. Two build fixes for Ubuntu 18.04
(`/usr/include/asm` symlink; `nullptr` to `NULL` in `bootable/recovery/partition.cpp`). Result: display, touch, root adb,
and `/data`, `/cache`, `/system` mount. TWRP's `last_kmsg` access is also the most important debugging channel (section 7).

## 4. The kernel

**4.1 Unmodified donor kernel.** Built with Ubuntu's GCC 7 cross compiler, the ttab kernel gives an LK logo, garbled red
static, then a reboot loop. `/proc/last_kmsg` shows `Kernel panic - not syncing: Fatal exception` at 14 s in
`init_dsi <- disphal_get_lcm_driver <- DISP_DetectDevice <- mtkfb_probe`. The bootloader passes `lcm=1-rm68200_txd_wxga_pixi3`;
the donor's built-in list has no such driver, the lookup loop falls through and dereferences a NULL driver. That was the only blocker.

**4.2 The RM68200 panel driver** (reverse-engineered):
1. The stock kernel is a zImage with an xz payload and no symbols. `vmlinux-to-elf` recovered about 50,000 symbols from
   `kallsyms` (kernel base `0xc0008000`).
2. The `LCM_DRIVER` struct was located through its name string; its field offsets come from the donor's `lcm_drv.h` (the layout
   was checked to be identical to the stock one).
3. `tools/armdis.py` (Capstone) disassembles `get_params`, `init`, `suspend`, `esd_check`, resolving literal-pool loads
   to symbols and strings. From that: DSI mode, lanes, porches, PLL, the power GPIOs and delays, the init command table and the
   ESD register check. All the numbers are in [HARDWARE.md](HARDWARE.md#the-rm68200-txd-panel) and match the stock binary
   one-for-one. The table-push loop was matched to the stock packing (DCS short write for 0 or 1 parameters, long write otherwise).
4. Registered in `mt65xx_lcm_list.c`, added to `CONFIG_CUSTOM_KERNEL_LCM` in the new `pixi3_8079_defconfig`.

Result: the custom kernel booted the stock Android 5.0.1 ramdisk to the launcher.

**4.3 Board fixes.** Touch: the donor puts the Goodix chip on I2C bus 0; here it is on bus 1, and the driver must **never push
a config** (`GTP_DRIVER_SEND_CFG 0`, so a wrong config cannot brick the controller). Charger: the donor uses FAN5405; this
tablet has a BQ24158, with the same charge-voltage limits as stock (checked in the stock binary). Wi-Fi and the
accelerometer came with the donor config.

**4.4 The "swipes become clicks" bug.** After Nougat booted, touch worked, but swipes registered as taps and some taps were
lost. Cause: the Goodix driver's ESD worker calls `gtp_check_fw()`, which compares register `0x8140` with the product ID of
the firmware image **compiled into the driver** (a GT912). This chip has a different ID, so the check always "failed" and the
worker hard-reset the controller every 2.33 s, leaving a 0.4 s dead zone each time. The fix makes the check pass
(`kernel/patches/0003`). Found by recording raw touch events and noticing the periodic gaps.

## 5. LineageOS device tree and blobs

- `device/alcatel/pixi3_8079` is the donor tree renamed, with: board `vE6I-0` and this unit's `userdata` size, the kernel
  command line (`androidboot.hardware=mt8127`), the `/misc` fix, init shim properties, an empty `lineage.dependencies`, and the lunch combo.
- **Blobs** come from the tablet's own `/system` (171 entries). The donor's list was adapted: donor-only codec entries removed,
  this tablet's own MediaTek OMX libraries added, and the dependency closure checked by scanning every ELF's `NEEDED` entries
  (nothing missing except the two libraries that were then added).
- The three `frameworks/av` patches from the donor (MediaTek colour formats, camera, microphone) are applied as commits;
  `repo sync` discards them, hence `setup-tree.sh`.
- The donor kernel source had been packaged from a build tree and contained stale generated headers and object files, which
  broke the out-of-tree Android kernel build (`asm/types.h` not found). A clean clone of upstream does not have the problem.

## Bring-up failures and their causes

LineageOS first built fine and then did **not** boot. Three independent causes, found one after the other:

1. **Stuck on the LK logo: `init_user0` blocks forever.** Android 7.1's `on post-fs-data` runs `init_user0`, which calls
   `vdc --wait cryptfs init_user0` synchronously; if `vold` is not running, `init` waits forever and nothing else starts.
   (Symptom: no `adb`, no kernel panic, no reboot.) Diagnosed by removing the call and watching what started; it was a symptom of #2.
2. **Every native process aborted at start-up: `libstlport.so` missing.** The device tree sets `TARGET_LDPRELOAD`, so `init.environ.rc`
   exports `LD_PRELOAD=libsigchain.so:libxlog.so:libmtk_symbols.so` into **every** process. The two MediaTek shims need
   `libstlport.so`, which Android 7.1 no longer ships, so the dynamic linker failed and each process died with `SIGABRT`: `vold`,
   `servicemanager`, `surfaceflinger`, all of them. Because `vold` is in a critical class, the crash loop made `init` reboot to
   recovery. The fix is one line: add `lib/libstlport.so` from the stock `/system` to `proprietary-files.txt` (a scan of every ELF
   in the stock system showed it is the only missing `NEEDED` library). This also fixed SurfaceFlinger's "couldn't find an
   OpenGL ES implementation".
3. **Touch resets**: section 4.4.

Smaller items: `fstab` listed `/misc` on `mmcblk0p3` (that is `protect_s` here; now `/dev/misc`), the `data` filesystem needs the
16 KB encryption-footer gap, and the Jack compiler needs TLS 1.0/1.1 enabled in OpenJDK 8 (`install-host-deps.sh`).

## 6. Things that were wrong in the plan

- The first assumption was that the firmware zip's kernel and blobs would match the tablet. They did not (vE6A vs vE6I).
- The census said the stock driver list contained two touch controllers and two accelerometers; only one of each is bound.
- "Cameras are last" turned out to mean "not yet": the sensors fitted are still unidentified.

## 7. Debugging without a serial console

There is no UART and no `fastboot boot`; these are the techniques that worked.

- **`/proc/last_kmsg` from TWRP.** The MediaTek `ram_console` survives a *warm* reset. Put the test kernel in `boot` and a working TWRP
  in `recovery`, boot, let it crash (or panic), then hold **Volume Up** from the moment of the restart: TWRP comes up and
  `cat /proc/last_kmsg` holds the failed boot. A power-button hold is a cold reset and **wipes it**, so avoid that.
- **Marker folders.** When `init` hangs before `adb` is up, patch the ramdisk's `init.rc` to `mkdir /data/dbg_<stage>` at known
  points (`on post-fs-data`, `on early-boot`, `on boot`, ...), boot, go to TWRP and `ls /data`. The last marker shows how far
  `init` got. (A throwaway script that rewrote the ramdisk's cpio inside the boot image did this in seconds;
  `tools/unpack.py` shows how to split an MTK boot image, and `tools/mkboot.py` how to re-wrap the pieces.)
- **Self-reboot timer.** Add `reboot recovery` after ~100 s plus a service that dumps `logcat` and `dmesg` into `/data/local` just
  before: that gives a log of a boot that otherwise never exposes `adb`, and the warm reset keeps `last_kmsg`.
- **Network ADB.** Once the system is up, enable *ADB over network* and *Root access: ADB only* in Developer options, then
  `adb connect <ip>:5555` for live `dmesg` and logcat. As root, the boot partition can be rewritten without a PC cable:
  `dd if=/data/local/tmp/boot.img of=/dev/bootimg bs=2048`, and verified with `dd if=/dev/bootimg bs=2048 count=N | sha256sum`.
- **Touch recording.** A raw `getevent` capture of the touch node, looked at over time, showed the 2.3 s periodic gaps.

## 8. Tooling quirks

- Every `mtkclient` run needs a fresh BROM connection (power off, hold Volume Up, plug in).
- PowerShell 5.1 reads BOM-less UTF-8 as ANSI, so `.ps1` files in this repo are ASCII-only.
- In WSL, build in the ext4 disk; WSL keeps cache memory, so cap it with `.wslconfig` and do not periodically drop caches (it slows the build).
- Git Bash mangles `/paths` passed to `wsl.exe`; use `MSYS_NO_PATHCONV=1`, or put the commands in a script file.
