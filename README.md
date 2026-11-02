# LineageOS 23.2 for Lenovo Tab One (TB305FU / poplar)

Unofficial LineageOS 23.2 (Android 16) device tree for the Lenovo Tab One
Wi-Fi (`TB305FU`, device `poplar`), a MediaTek MT8786 (MT6768 family)
tablet with a GKI 6.6 kernel.

## Status

Boots with SELinux enforcing; tested on one device.

| Area | State |
| --- | --- |
| Display, touch, SystemUI | works |
| Wi-Fi | works |
| Bluetooth (audio: A2DP, HFP) | works |
| Cameras (front + rear) | work |
| Audio playback | works |
| Sensors | accelerometer, light and virtual sensors listed |
| GNSS | HAL starts; fix not verified on this build |
| Encrypted `/data` (Beanpod Keymaster 4.1) | works |
| A/B OTA via `adb sideload` / updater, LineageOS recovery | works |
| Factory reset from LineageOS recovery | works (boots to setup) |
| Upgrade from 22.2 | installs; first boot, then factory reset tested |

## Repositories

| Path | Repository |
| --- | --- |
| `device/lenovo/poplar` | this repository |
| `device/lenovo/poplar-kernel` | [android_device_lenovo_poplar-kernel](https://github.com/9cb14c1ec0/android_device_lenovo_poplar-kernel) — prebuilt kernel, DTB/DTBO, modules |
| `vendor/lenovo/poplar` | [android_vendor_lenovo_poplar](https://github.com/9cb14c1ec0/android_vendor_lenovo_poplar) — proprietary blobs |
| `device/mediatek/sepolicy_vndr` | [LineageOS/android_device_mediatek_sepolicy_vndr](https://github.com/LineageOS/android_device_mediatek_sepolicy_vndr) |
| `hardware/mediatek` | [LineageOS/android_hardware_mediatek](https://github.com/LineageOS/android_hardware_mediatek) |

Kernel source: [android_kernel_lenovo_poplar](https://github.com/9cb14c1ec0/android_kernel_lenovo_poplar).
The kernel is unmodified AOSP GKI `android15-6.6` at `kernel/common`
`076ac12bde16` (the commit of Lenovo's stock GKI build `ab13715361`); the
MediaTek/Lenovo vendor modules are the stock ones. Lenovo has not published
the vendor module source.

## Building

`.repo/local_manifests/poplar.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
    <remote name="clove" fetch="https://github.com/9cb14c1ec0" />
    <project name="android_device_lenovo_poplar-lineage" path="device/lenovo/poplar" remote="clove" revision="lineage-23.2" />
    <project name="android_device_lenovo_poplar-kernel" path="device/lenovo/poplar-kernel" remote="clove" revision="lineage-23.2" />
    <project name="android_vendor_lenovo_poplar" path="vendor/lenovo/poplar" remote="clove" revision="lineage-23.2" />
</manifest>
```

The two LineageOS MediaTek repositories are pulled in through
`lineage.dependencies` (`breakfast`/`roomservice`), or add them to the local
manifest as well.

```bash
repo sync
source build/envsetup.sh
lunch lineage_poplar-bp4a-userdebug
m bacon
```

The result is a full A/B OTA package,
`out/target/product/poplar/lineage-23.2-*-UNOFFICIAL-poplar.zip`.
It does not contain firmware (preloader, LK, TEE, modem, ...).

## Installing

**This wipes the device. Back up first.** You need an unlocked bootloader.
The procedure below from stock has not been tested end to end; the author's
device was converted step by step during bring-up.

1. **Firmware.** The vendor blobs come from stock
   `S2002997_260522_ROW` (Android 15, `AP3A.240905.015.A2`). Both slots must
   run that firmware (preloader, lk, tee, gz, scp, sspm, spmfw, md1img).
   After a stock OTA only one slot has it; flash the same images to the other
   slot's partitions (`*_a` and `*_b`) with `fastboot`.
2. **Patched LK.** The stock LK refuses any `vbmeta` not signed by Lenovo,
   even when unlocked. Flash the dm-verity-patched LK from the
   [TWRP port](https://github.com/9cb14c1ec0/android_device_lenovo_poplar)
   releases to **both** `lk_a` and `lk_b` (it is built from the same stock
   firmware version).
3. **Boot images**, from the build output, to the current slot:
   ```bash
   fastboot getvar product          # must be poplar
   fastboot flash vbmeta vbmeta.img
   fastboot flash vbmeta_system vbmeta_system.img
   fastboot flash vbmeta_vendor vbmeta_vendor.img
   fastboot flash dtbo dtbo.img
   fastboot flash boot boot.img
   fastboot flash vendor_boot vendor_boot.img    # LineageOS recovery
   fastboot reboot recovery
   ```
4. In recovery: **Factory reset → Format data**, then **Apply update → Apply
   from ADB** and run `adb sideload lineage-23.2-*.zip`. Reboot.

Later updates: sideload the new zip from recovery, or run
`adb reboot sideload-auto-reboot` and `adb sideload <zip>`; the device reboots
by itself into the updated slot. After an A/B install recovery asks whether to
reboot to recovery; answer it (or use `sideload-auto-reboot`) — `adb sideload`
on the host only finishes after that.

## Tree layout

| Path | Contents |
| --- | --- |
| `BoardConfig.mk`, `device.mk`, `lineage_poplar.mk` | board, product |
| `rootdir/etc/` | vendor init scripts, fstabs, ueventd, module loading |
| `sepolicy/vendor/` | device policy on top of `sepolicy_vndr`; `stock_port.te` and the contexts files are generated from the stock Lenovo vendor policy |
| `configs/` | VINTF, permissions |
| `rro_overlays/` | framework and Wi-Fi overlays |
| `proprietary-files.txt`, `extract-files.py`, `setup-makefiles.py` | blob list and extraction |

## Notes

- **First-stage fstab.** LK passes `androidboot.hardware=mt8786` and loads
  *all* `vendor_boot` ramdisk fragments on every boot, including the recovery
  one. Lenovo ships the real first-stage fstab (`fstab.mt8786`) only in its
  recovery fragment, so this tree puts `first_stage_ramdisk/fstab.mt8786{,dm}`
  into the platform fragment. Without them any other recovery makes
  first-stage init panic.
- **Wi-Fi HAL.** Lenovo's `libwifi-hal` is built against the Android 15
  `wifi_hal.h`; it is installed as `libwifi-hal-mtk.so` and loaded through
  `libwifi-hal-wrapper` from `hardware/mediatek`, built with
  `use_pre_baklava_qpr0_struct`.
- **`PRODUCT_SHIPPING_API_LEVEL := 34`** is required. With it unset,
  `hwservicemanager` is not installed, keystore2 cannot reach the HIDL
  Keymaster, `vold` blocks and the device hangs on the boot logo.
- **`debug.renderengine.backend=skiaglthreaded`.** The stock value `skiagl`
  triggers a use-after-free in SurfaceFlinger's screenshot path.
- **Slot retries.** Each failed boot uses one of the slot's retries. At zero LK
  shows the Lenovo logo forever (`[AB] no valid slot!`). Recover with
  `fastboot set_active <slot>`.
- **Extracting blobs.** `lpunpack` of a `super` dumped from a device that has
  taken a stock OTA returns the pre-snapshot base images, with zeroed inodes.
  Use a stock firmware image, or `pull-stock-images.sh`, which reads the
  merged `/dev/block/mapper` devices over adb.
- `pstore` (`/sys/fs/pstore/console-ramoops-0`) survives a warm reset and holds
  the previous boot's kernel log.
