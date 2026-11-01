# Status

Build: `lineage_pixi3_8079-userdebug`, kernel `3.10.108` (ttab base plus [three patches](../kernel/patches)).
Tested on one tablet (stock build `vE6I-0`, RM68200 TXD panel, Goodix touch). "Verified" means checked on that tablet
over `adb` or by hand. A health scan of the running system found 0 crashes and 0 ANRs.

## What works

| Area | State | How it was checked |
|---|---|---|
| Boot to launcher | Works | Boots and reaches the setup wizard and launcher |
| Display | Works | 800x1280 at about 55 Hz; sleep / wake cycles exercise the panel suspend and re-init paths |
| Touch | Works | After the ESD-reset fix (see below), taps and swipes are reliable |
| Wi-Fi | Works | Connects and holds a link (about 39 Mbit/s measured) |
| Bluetooth | Powers on | Pairing / audio not tested; the address is a placeholder `22:22:28:EA:EA:AC`, not read from nvram |
| Accelerometer | Works | BMA2xx bound; auto-rotate not tested by hand |
| Battery gauge, thermal, storage | Work | Read through the usual interfaces |
| Charging | Works | Verified with the same kernel under the stock ROM: BQ24158 on USB, health good, CV 4.36 V (4.10 V hot) as stock |
| Audio | Partly | Routing to the speaker is configured; a listening test across all paths is pending |
| ADB | Works | Over USB, and over Wi-Fi once enabled in Developer options |

## What does not work / is missing

| Area | State |
|---|---|
| **Cameras** | `0` camera devices. The HAL is a stub (`USE_CAMERA_STUB`) and the kernel's sensor list lacks `gc2375` and `s5k5e2ya`; which sensors this unit really has is not yet known. Needs reverse-engineering work. |
| Light / proximity / gyro | Not detected; the hardware is most likely absent from this tablet. |
| GPS, FM radio | Untested. |
| Bluetooth MAC | Placeholder; should be read from the nvram partition. |
| **SELinux** | **Permissive.** About 70 `avc` denials to turn into rules: `surfaceflinger` and `audioserver` to device nodes, `fsck` to `mmc_device`, `nvram_daemon`, a `system_app` binder call. |
| Other panel / touch variants | Not supported ([HARDWARE.md](HARDWARE.md#which-variant-do-i-have)). |

## Known quirks

- **ADB over network and Root access reset on every boot** (a LineageOS default). Re-enable in *Developer options*.
- **The zip cannot be sideloaded from this TWRP** (device-name assert); use the fastboot install.
- A `repo sync` removes the three `frameworks/av` patches; re-run `scripts/build/setup-tree.sh`.
- The `data` filesystem must be 16 KB smaller than the partition (the encryption footer); `scripts/device/twrp-format-data.sh` does that.

## Debug leftovers still in the tree

These were left in on purpose during bring-up and are what makes this build unsuitable for everyday use as is:

| Where | What | Why it matters |
|---|---|---|
| `device.mk`, `ifneq ($(TARGET_BUILD_VARIANT),user)` blocks | `ro.secure=0`, `ro.adb.secure=0`, `persist.sys.usb.config=adb`, ... | ADB runs as root from boot with **no RSA authorisation** |
| `BoardConfig.mk` | `androidboot.selinux=permissive` on the kernel command line | No SELinux enforcement |

A release build would remove both. Building the `user` variant drops the `device.mk` properties, but that variant has **not**
been built or booted yet, and SELinux has to be made enforcing first.

## Security notes

The vendor ships no security patches for this tablet, and LineageOS 14.1 is long end-of-life: the kernel, the
Bluetooth/Wi-Fi stacks and WebView all have public, unpatched vulnerabilities. Combined with the open ADB above:

1. After installing, turn off **USB debugging**, **ADB over network** and **Root access** in Developer options.
2. Put the tablet on a **guest Wi-Fi network that cannot reach your LAN** (or use the router's client / AP isolation) so that
   a compromised tablet cannot reach your PCs, NAS or router. Doing this on the router is more robust than
   firewall rules on the tablet, which a compromised tablet could remove.
3. Do not sign in to anything valuable (banking, main Google account, password manager) on it. Prefer a throwaway account.

## Roadmap

1. Cameras (identify the fitted sensors, add drivers, build a real camera HAL).
2. SELinux enforcing, then a `user` build without the debug properties.
3. Bluetooth address from nvram; listening and pairing tests; sleep / rotation / charging soak tests.
4. The other panel variants.
