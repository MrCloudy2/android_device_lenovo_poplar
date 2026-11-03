# LineageOS 24.0 for the Lenovo Tab TB311XU (poplar)

Unofficial LineageOS 24.0 (Android 17) device tree for the Lenovo Tab, LTE model `TB311XU`,
codename `poplar`. It's a MediaTek MT8786 (MT6768 family) tablet running a stock GKI
`android15-6.6` kernel. The tree is a fork of
[9cb14c1ec0's Lenovo Tab One (TB305FU, clove_row_wifi) tree](https://github.com/9cb14c1ec0/android_device_lenovo_clove_row_wifi-lineage),
which uses the same SoC and the identical stock kernel build. It was ported to 24.0 and
adapted to the TB311XU's LTE modem, telephony and stock vendor.

The blobs, SELinux policy and VINTF come from stock firmware
**TB311XU_ROW_OPEN_USER_V15.271_A16_ZUI_17** (`37.350.260708W`, Android 16 with an
Android 15 vendor).

> **Unofficial.** Unlocking the bootloader wipes the tablet. You do all of this at your own risk.
> Back up the `nvram`, `nvdata`, `nvcfg`, `proinfo`, `persist` and `protect1/2` partitions before
> you flash anything: they hold the IMEI and the radio calibration.

## Status

| Works | Not tested / known issues |
|---|---|
| Boot, SELinux enforcing, FBE + metadata encryption | Deep sleep unplugged: not measured yet |
| Display, touch, auto-rotate, sensors | GPS: `mnld` runs, outdoor fix not tested |
| Wi-Fi, Bluetooth | Wi-Fi calling: enabled, not tested |
| Calls, SMS, LTE data, **VoLTE** (tested on A1 Slovenia) | Brightness curve not tuned |
| Both cameras (photo and video), audio | Play Integrity fails (unlocked bootloader) |
| Charging | |
| Google Play via MindTheGapps | |
| A/B OTA with Lineage recovery (in `vendor_boot`) | |

## Installing

You need a PC with `fastboot` and `adb`, and these files from the
[Releases](https://github.com/MrCloudy2/android_device_lenovo_poplar/releases) page:
`lineage-24.0-*-poplar.zip`, `boot.img`, `init_boot.img`, `vendor_boot.img`, `dtbo.img`,
`vbmeta.img`, `vbmeta_system.img`, `vbmeta_vendor.img`.
Check them with `sha256sum -c SHA256SUMS`.

1. **Unlock the bootloader.**
   - Settings → About tablet → tap *Build number* 7 times.
   - Developer options → enable **OEM unlocking** and **USB debugging**.
   - `adb reboot bootloader`, then `fastboot getvar all`. Note `Bootloader_SN_Part1` and
     `Bootloader_SN_Part2`.
   - Request the unlock image at Lenovo's unlock site (zui.com/iunlock) with those values. It
     emails you an `sn.img`.
   - `fastboot flash unlock sn.img`, then `fastboot oem unlock-go`. Confirm on the tablet. It
     wipes itself.
   - Without `sn.img`, `fastboot oem unlock` fails with `Sn Image Auth fail`.
   - After the unlock, boot stock once and let any pending system update finish.
2. **Flash the boot images** from the bootloader (`adb reboot bootloader`).
   - Use the slot that is active now (`fastboot getvar current-slot`). This example uses `b`:
     ```
     fastboot flash vbmeta_b vbmeta.img
     fastboot flash vbmeta_system_b vbmeta_system.img
     fastboot flash vbmeta_vendor_b vbmeta_vendor.img
     fastboot flash dtbo_b dtbo.img
     fastboot flash boot_b boot.img
     fastboot flash init_boot_b init_boot.img
     fastboot flash vendor_boot_b vendor_boot.img
     fastboot erase md_udc
     fastboot reboot recovery
     ```
   - `md_udc` is `/metadata`. Erasing it is required when coming from stock.
   - The tablet now boots into Lineage recovery.
3. **Copy the firmware to the other slot.**
   - The LineageOS package doesn't contain firmware (lk, tee, modem, ...). It installs to the
     *other* slot, which after a stock OTA may hold older firmware.
   - In recovery, open *Advanced → Enable ADB*.
   - On the PC, with `b` as the active slot:
     ```
     adb shell 'for p in gz lk md1img scp spmfw sspm tee; do
       dd if=/dev/block/by-name/${p}_b of=/dev/block/by-name/${p}_a bs=1M && echo $p ok; done; sync'
     ```
   - If `a` is active, swap `_a` and `_b`.
4. **Install LineageOS.**
   - **Factory reset → Format data/factory reset.** This is required when coming from stock or
     from a build signed with different keys.
   - **Apply update → Apply from ADB**, then on the PC: `adb sideload lineage-24.0-*-poplar.zip`.
     adb stopping at about 47 % is normal.
5. **Google apps (optional).**
   - They must be installed before the first boot. If you already booted, format data again.
   - When recovery offers to reboot to recovery for add-ons, choose **Yes**.
   - Then **Apply update → Apply from ADB** and sideload
     [MindTheGapps 17.0.0 arm64](https://github.com/MindTheGapps/17.0.0-arm64/releases).
   - "Signature verification failed" is expected: choose *Install anyway*.
6. **Reboot system now.** The first boot takes a few minutes.

If you signed in to a Google account on stock, Factory Reset Protection asks for that account
after the format. Remove the account in stock Settings before you start.

## Building

```
repo init -u https://github.com/LineageOS/android.git -b lineage-24.0 --git-lfs
mkdir -p .repo/local_manifests
curl -o .repo/local_manifests/poplar.xml \
  https://raw.githubusercontent.com/MrCloudy2/android_device_lenovo_poplar/lineage-24.0/local_manifests/poplar.xml
repo sync -c -j8
source build/envsetup.sh
lunch lineage_poplar-cp2a-userdebug
m bacon
```

- The result is a full A/B OTA package, `out/target/product/poplar/lineage-24.0-*-UNOFFICIAL-poplar.zip`.
  The images to flash are next to it.
- Soong analysis needs a lot of memory: plan for about 64 GB of RAM plus swap combined. A clean
  build took about 8 h on 16 threads with `-j12`.
- Release builds are signed with
  [your own keys](https://wiki.lineageos.org/signing_builds) in `vendor/lineage-priv/keys`.
- AVB uses the AOSP test key with verification disabled (`--flags 3`). The unlocked TB311XU
  bootloader accepts a vbmeta signed with any key.

### Re-extracting the blobs

The blobs are already in
[android_vendor_lenovo_poplar](https://github.com/MrCloudy2/android_vendor_lenovo_poplar).
To regenerate them from a stock dump:

- Unpack `super` with `lpunpack --slot=1`.
- Extract each EROFS image with `fsck.erofs --extract`, so that symlinks survive.
- Run `./extract-files.py <dump>/vendor_x`.

`proprietary-files.txt` was generated by `tools/gen_blob_list.py` (usage in its header).
The SELinux port is regenerated as described in
[sepolicy/README.md](sepolicy/README.md).

## Device notes

- **Boot layout** (like stock):
  - `boot` holds only the kernel.
  - `init_boot` (header v4) holds the generic ramdisk.
  - `vendor_boot` holds the vendor ramdisk and Lineage recovery. There is no recovery partition.
- **SELinux:**
  - `sepolicy/vendor/stock/` is generated from the stock vendor policy by
    `sepolicy/gen_stock_port.py`.
  - It is checked with `m selinux_policy` and the treble sepolicy tests.
- **VINTF:**
  - Target FCM level 7 (Android 17 has no level 6).
  - The device compatibility matrix lists the stock vendor HALs: radio V3, mtkradioex, IMS,
    Dolby, Beanpod.
- **Telephony and IMS:**
  - The stock AIDL radio HAL (`mtkfusionrild`) talks to AOSP telephony directly.
  - VoLTE uses [techyminati's MediaTek IMS](https://github.com/techyminati/android_vendor_mediatek_ims)
    (`persist.dbg.volte_avail_ovr=1`).
- **`libmnl`:** MediaTek's `libmnl.so` (the GPS library) has the same name as AOSP's netlink
  library. It ships as `libmnl_mtk.so` and `mnld` is patched to use it.
- **SurfaceFlinger:** RenderEngine is forced to `skiaglthreaded`. The stock non-threaded `skiagl`
  crashes SurfaceFlinger on screenshots.

## Repositories

| Path | Repository |
|---|---|
| `device/lenovo/poplar` | this repository |
| `device/lenovo/poplar-kernel` | [android_device_lenovo_poplar-kernel](https://github.com/MrCloudy2/android_device_lenovo_poplar-kernel): stock kernel, DTB/DTBO, modules |
| `vendor/lenovo/poplar` | [android_vendor_lenovo_poplar](https://github.com/MrCloudy2/android_vendor_lenovo_poplar): proprietary blobs |
| `device/mediatek/sepolicy_vndr` | [LineageOS/android_device_mediatek_sepolicy_vndr](https://github.com/LineageOS/android_device_mediatek_sepolicy_vndr) |
| `hardware/mediatek` | [LineageOS/android_hardware_mediatek](https://github.com/LineageOS/android_hardware_mediatek) |
| `vendor/mediatek/ims` | [techyminati/android_vendor_mediatek_ims](https://github.com/techyminati/android_vendor_mediatek_ims) |

The kernel is Google's unmodified GKI `android15-6.6` build (`6.6.82-android15-8-g076ac12bde16`),
the same build as on the TB305FU; see
[9cb14c1ec0's clove kernel repository](https://github.com/9cb14c1ec0/android_kernel_lenovo_clove_row_wifi)
for the source. Lenovo has not published the vendor module source.

## Credits

- [9cb14c1ec0](https://github.com/9cb14c1ec0) for the TB305FU (clove_row_wifi) tree this is based on
- The LineageOS project
- [techyminati](https://github.com/techyminati) for the MediaTek IMS package
