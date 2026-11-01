# Hardware reference

Everything here was read from a real unit (stock build `vE6I-0`, kernel 3.10.108 built 2020-10-13) over `adb` in
TWRP and from the stock kernel and bootloader binaries.

## Summary

| | |
|---|---|
| SoC | MediaTek MT8127 (hw code `0x8127`), quad Cortex-A7, Mali-450 MP4 |
| RAM / storage | 1 GB LPDDR / 8 GB eMMC (7.4 GiB), MBR partition table (not GPT) |
| Display | 10.1", 800x1280, MIPI-DSI, **Raydium RM68200**, TXD module (`rm68200_txd_wxga_pixi3`) |
| Touch | **Goodix GT9xx** on I2C bus 1, address `0x5d`, firmware `0x44` |
| Accelerometer | BMA2xx on I2C bus 2, `0x18` (the HAL calls it "mc3210") |
| Charger / PMIC | TI **BQ24158** on I2C bus 1, `0x6a` / MediaTek MT6323 |
| Wi-Fi / Bluetooth / FM / GPS | MediaTek CONSYS_8127 combo chip (MT6627 for FM) |
| Camera hardware | `kd_camera_hw` on I2C bus 0; lens driver FM50AF at `0x18`. The stock kernel knows ov5670, ov56702nd, ov2680, gc2375 and s5k5e2ya; which are fitted to this unit is not yet known |
| Battery | 4060 mAh |
| Kernel command line (from the bootloader) | `lcm=1-rm68200_txd_wxga_pixi3 vmalloc=496M vram=27262976 fps=5497 slub_max_order=0 coherent_pool=3240K` (a replacement boot image must keep the `vmalloc`/`vram` values) |

Registered by the stock kernel but **not present** on this unit: FocalTech FT5x26 touch, MC3XXX accelerometer.

## Which variant do I have?

The stock firmware supports four panels and two touch controllers; this repo's kernel only contains the RM68200 TXD panel
driver and the Goodix touch driver. To check a unit, boot TWRP and run:

```
adb shell cat /proc/cmdline
```

Look for `lcm=1-<name>`. Only `rm68200_txd_wxga_pixi3` is supported. If you see one of the others
(`otm1287a_tdt_wxga_pixi3`, `otm1287a_txd_wxga_pixi3`, `rm68200_yeji_wxga_pixi3`), the kernel will panic in `init_dsi` and
bootloop, exactly as the unmodified donor kernel did on the author's unit. For touch, `adb shell dmesg | grep -i -E "gt9|fts"`
shows which controller bound.

### Adding another panel

The recipe the RM68200 driver was made with (the same one will work for the other variants, whose code is in the same
stock kernel):

1. `python3 tools/unpack.py out backup/small/bootimg.bin` strips the boot-image and MediaTek headers; the kernel is a
   zImage with an **xz** payload. Decompress that payload to get a raw `Image`.
2. The stock kernel has no symbol table. Run [vmlinux-to-elf](https://github.com/marin-m/vmlinux-to-elf) on the raw image
   (about 50,000 symbols are recovered, kernel base `0xc0008000`), then `arm-linux-gnueabi-nm` on the ELF.
3. Find the `LCM_DRIVER` struct of the panel by the pointer to its name string; field offsets come from `lcm_drv.h` of the donor
   kernel (the layout was verified to be identical).
4. `python3 tools/armdis.py Image.raw stock.nm START END` disassembles `get_params`, `init`, `suspend`, `esd_check`, ... with
   literal-pool loads resolved to symbols and strings. From that you read the DSI mode, lanes, porches, PLL, the GPIO
   sequence and the init command table.
5. Write the driver next to [`rm68200_txd_wxga_pixi3.c`](../kernel/patches/0001-pixi3_8079-add-RM68200-TXD-panel-driver-reconstructe.patch),
   register it in `mt65xx_lcm_list.c` and add its name to `CONFIG_CUSTOM_KERNEL_LCM`.

## The RM68200 (TXD) panel

Recovered from the stock driver:

| | |
|---|---|
| Interface | DSI burst video mode, 4 lanes, RGB888 (24-bit packed), 800x1280 |
| Vertical | sync 4, back porch 8, front porch 8 |
| Horizontal | sync 4, back porch 132, front porch 24 |
| DSI PLL clock | 224 MHz, non-continuous clock, low-power clock per line enabled |
| Power-up | GPIO27 high, 5 ms, GPIO26 high, 5 ms, reset GPIO83 high / low / high (5 / 10 / 20 ms) |
| Init commands | `FE 0E`, `01 63`, `FE 00`, `11` (sleep out), 34 ms, `29` (display on), 180 ms |
| Suspend | `28`, 34 ms, `10`, 180 ms, then reset / GPIO26 / GPIO27 low |
| ESD check | read register `0x0A`, expect `0x9C` |

## Flash layout

Raw offsets into the eMMC user area (these are the offsets `backup-small.ps1` and `restore-stock.ps1` use):

| Partition | Offset | Size | Notes |
|---|---|---|---|
| `pro_info` | `0x0100000` | 3 MB | |
| `nvram` | `0x0400000` | 5 MB | MACs, serial, calibration: **unique to the unit** |
| `protect_f` | `0x0900000` | 10 MB | |
| `protect_s` | `0x1300000` | 10 MB | |
| `seccfg` | `0x1D00000` | 128 KB | |
| `uboot` (LK) | `0x1D20000` | 384 KB | |
| `boot` | `0x1D80000` | 16 MB | `/dev/bootimg` |
| `recovery` | `0x2D80000` | 16 MB | `/dev/recovery` |
| `sec_ro` | `0x3D80000` | 6 MB | |
| `misc` | `0x4380000` | 512 KB | `/dev/misc` |
| `logo` | `0x4400000` | 3 MB | |
| `custpack` | | | `mmcblk0p5`; holds the stock `build.prop` |
| `system` | | 1,468,006,400 B | `mmcblk0p6` |
| `cache` | | 256 MB | `mmcblk0p7` |
| `userdata` | | 4,847,042,560 B | `mmcblk0p8` |

The partition sizes above are the values in `BoardConfig.mk`. Note that the donor tree pointed `/misc` at `mmcblk0p3`, which on
this tablet is `protect_s`; the tree here uses `/dev/misc`.

## Boot image format

Android boot image header v0: page size 2048, base `0x80000000`, kernel offset `0x8000`, ramdisk offset `0x4000000`,
tags offset `0x100`, board name `vE6I-0`, empty command line (the bootloader appends its own). The kernel and the ramdisk
each carry a **512-byte MediaTek header** (magic `0x58881688`, a name string `KERNEL` / `ROOTFS` / `RECOVERY`) in front of
the data, which the stock bootloader expects (every image that booted had it). The ramdisk is a gzip-compressed `newc` cpio.

## Bootloader (LK) behaviour

- BROM (the chip's mask ROM) is **not protected** (secure boot, SLA and DAA are all off): `mtkclient` can read and write any
  partition as long as the stock preloader is supplied for the DRAM setup.
- `fastboot oem unlock` works (confirm on the tablet with Volume Up). `fastboot flash <partition>` works, `fastboot boot`
  does not, `fastboot oem reboot-recovery` does.
- `fastboot` runs in LK, which can take 128 MB per download; sparse images are split automatically.
