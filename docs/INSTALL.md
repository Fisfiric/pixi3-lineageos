# Installing

> **This erases the tablet.** Unlocking the bootloader wipes all user data, and the install replaces the system.
> Do the backup in step 1 before anything else. Everything here was done on one tablet (Windows 11 PC,
> stock firmware build `vE6I-0`); read the whole page once before you start.

You need:

- a Windows PC with **git**, **Python 3.9+** and a USB cable (the scripts are PowerShell; the build side needs Linux, see [BUILD.md](BUILD.md)),
- the tablet charged to at least 50 %,
- Android platform-tools (`adb`, `fastboot`) on your `PATH`,
- the [**UsbDk**](https://github.com/daynix/UsbDk/releases) driver (x64 `.msi`; reboot the PC after installing),
- the stock firmware package for the 8079 (MT8127), which supplies one file the backup tool needs, `preloader_ttab.bin`
  (this repo used `Alcatel_OneTouch_Pixi_3_8079_MT8127_09222017_5.0.1` from alcatelfirmware.com).

The order is: **backup, unlock, TWRP, dump your stock system (for blobs), build, flash.** You can only build the
ROM once you have the blobs from your own tablet, which is why TWRP comes before the build.

## 1. Back up (read-only, cannot brick)

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\setup.ps1
```

Unzip the stock firmware into `firmware_dl\extracted\` so that `firmware_dl\extracted\preloader_ttab.bin` exists.
Then:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\backup-small.ps1
```

When it says it is waiting for the device: power the tablet **fully off** (hold power about 15 s if it hangs),
hold **Volume Up** and plug in the USB cable. If nothing happens within about 10 s, unplug and try **Volume Down**,
then **both** buttons. The tablet screen stays black in this mode; that is normal.

The result is `backup\small\` (about 70 MB): the partitions that are unique to your unit (`nvram` holds the serial,
Wi-Fi/BT MACs and calibration; `protect_f/s`, `pro_info`, `sec_ro`) plus `uboot`, `bootimg`, `recovery`, `logo`,
`misc` and a `SHA256.txt`. **Copy that folder somewhere safe.** It cannot be downloaded again.

Troubleshooting (all of these happened during development):

| Symptom | Cause / fix |
|---|---|
| `USB enumeration error: Operation not supported` | UsbDk is not installed, or `setup.ps1` did not apply `mtkclient-usbdk.patch`. Install UsbDk, reboot, re-run. |
| Hangs at DRAM / `RAM-Length: 0x0` | Wrong preloader. It must be `preloader_ttab.bin` from the stock firmware (the scripts pass it with `--preloader`). |
| Hangs at "Reconnecting to stage2" | The scripts already pass `--noreconnect`; if you run mtkclient by hand, add it. |
| Second command says "Waiting for device" forever | Every mtkclient run needs a fresh BROM connection: power off, replug with the key held. |

## 2. Unlock the bootloader

On the tablet: *Settings, About tablet*, tap **Build number** seven times, then *Developer options, USB debugging*.

```
adb reboot bootloader
fastboot oem unlock
```

The tablet asks for confirmation: press **Volume Up** to accept (this erases all data). `fastboot getvar all` should then
show `unlocked: yes`.

The fastboot interface (`0BB4:0C01`) may show up in Windows without a driver. Install the Google USB driver by hand:
*Device Manager, the unknown device, Update driver, Browse, Let me pick, Have Disk*, choose `android_winusb.inf`
from the Google USB driver package, and pick **Android Bootloader Interface**.

Limits of this bootloader: **`fastboot boot` is not supported** (every test image has to be flashed), but
`fastboot flash` and `fastboot oem reboot-recovery` work.

## 3. TWRP

Build the recovery from your backup (see [BUILD.md](BUILD.md#2-twrp)):

```bash
scripts/build/build-twrp.sh /path/to/backup/small/recovery.bin      # on the Linux build host
```

```
adb reboot bootloader
fastboot flash recovery recovery.img
fastboot oem reboot-recovery
```

TWRP gives you a root `adb` shell. (From a powered-off tablet you can also reach recovery with **Volume Up + Power**.)

## 4. Dump your stock system (for the proprietary blobs)

The ROM needs MediaTek HAL libraries that only exist on the stock firmware. They are taken from *your* tablet's
`/system`, using the list in `device/alcatel/pixi3_8079/proprietary-files.txt`. In TWRP:

```
adb shell "mount -t ext4 -o ro /dev/block/mmcblk0p6 /system"
cmd /c "adb exec-out dd if=/dev/block/mmcblk0p6 bs=1048576 > system_p6.img"
```

(`cmd /c` matters: PowerShell's `>` corrupts binary output.) That is a 1.4 GB raw ext4 image. Keep it private; it is the vendor's firmware.
[BUILD.md](BUILD.md#3-lineageos) shows how to loop-mount it on the build host.

## 5. Build the ROM

Follow [BUILD.md](BUILD.md). You end up with `boot.img` and `system.img` in `out/target/product/pixi3_8079/`.

## 6. Flash

```
adb reboot bootloader
fastboot flash boot boot.img
fastboot flash system system.img         # sparse image: the bootloader accepts 128 MB at a time, fastboot splits it
fastboot oem reboot-recovery
```

In TWRP, format `/data` and `/cache` with the script in this repo. It matters: Android keeps an encryption footer in the
**last 16 KB** of the data partition, so the filesystem must be made 16 KB smaller than the partition, which TWRP's own
format does not do.

```
adb push scripts/device/twrp-format-data.sh /tmp/
adb shell sh /tmp/twrp-format-data.sh
adb reboot
```

The first boot takes a few minutes (Alcatel logo, then the LineageOS animation). If it stays on the Alcatel logo for
more than ten minutes, see [PORTING-NOTES.md](PORTING-NOTES.md#bring-up-failures-and-their-causes).

**Why not flash the `.zip` from TWRP?** The zip checks `ro.product.device == pixi3_8079`, but this TWRP build reports
the donor name `ttab`, so the check fails. Fastboot is the supported route.

## After installing

- Developer options reset **ADB over network** and **Root access** on every boot (LineageOS default). Re-enable them
  while you debug, and turn **all** of them off afterwards. See [STATUS.md](STATUS.md#security-notes).
- Put the tablet on an isolated (guest) Wi-Fi network.
- To go back to stock, see [RECOVERY.md](RECOVERY.md).
