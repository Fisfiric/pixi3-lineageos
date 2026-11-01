# Recovery and going back to stock

**A bad flash can always be undone from a PC.** The chip's BROM (mask ROM) is not protected, so `mtkclient` can write
partitions however broken they are. Nothing in this project writes the preloader, and the bootloader (LK) is only touched
if you ask `restore-stock.ps1` to; the only partitions that are wiped are `userdata` and `cache`.

Everything below uses the backup made by `scripts\windows\backup-small.ps1` (`backup\small\`).

## The tablet does not boot (stuck on the logo, black screen, bootloop)

### 1. Via fastboot, if you can still reach the bootloader

From a working system run `adb reboot bootloader`. If it does not boot, power it off and hold **Volume Up** while
powering on to reach TWRP, then run `adb reboot bootloader` from there. Put the original boot image back:

```
fastboot flash boot backup\small\bootimg.bin
fastboot flash recovery backup\small\recovery.bin
fastboot reboot
```

### 2. Via BROM, if nothing else works

Always possible with the PC. Power the tablet off completely, then:

```powershell
# shows what it would write; no changes made
powershell -ExecutionPolicy Bypass -File .\scripts\windows\restore-stock.ps1 -What boot,recovery

# really write (the script pauses before each item so you can power off and replug into BROM)
powershell -ExecutionPolicy Bypass -File .\scripts\windows\restore-stock.ps1 -What boot,recovery -Go
```

Items: `boot`, `recovery`, `uboot`, `logo`, and the unit-specific `nvram`, `protect_f`, `protect_s`, `pro_info`, `sec_ro`.
All of them are restored from **your own** backup. Each item is one BROM session: power off, hold Volume Up, plug in
when asked. If `nvram` was ever damaged (lost Wi-Fi or Bluetooth MAC, `serial` gone), restore it from the backup the same way.

## Back to the stock Android 5.0.1

1. Restore `boot` and `recovery` as above.
2. Flash a stock `system` image. The firmware package that supplied `preloader_ttab.bin` also contains one (it is the
   older `vE6A` build); a raw dump of your own `system` partition from before the install ([INSTALL.md](INSTALL.md#4-dump-your-stock-system-for-the-proprietary-blobs))
   is the better source, and the one that matches your unit:

   ```
   fastboot flash system system_p6.img
   ```

   A raw ext4 dump may need converting to a sparse image first (`img2simg`) for fastboot to accept it.
3. Boot TWRP (`fastboot oem reboot-recovery`), wipe `/data` and `/cache` with `scripts/device/twrp-format-data.sh`
   (same procedure as the install) and reboot.

The `custpack` partition (holding the stock `build.prop`) is never written by this project, so it is still intact.

> The return-to-stock path is the least exercised part of this repository: the BROM restore of boot / recovery is
> scripted and dry-run tested, but a full stock restore of `system` has not been rehearsed. Keep the backup and the
> `system` dump safe until you are sure you will not go back.
