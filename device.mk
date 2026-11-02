#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/lenovo/poplar

# -- A/B / update_engine -------------------------------------------------
# Only the partitions we actually build are listed for postinstall.
AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    FILESYSTEM_TYPE_system=ext4 \
    POSTINSTALL_PATH_system=system/bin/otapreopt_script \
    POSTINSTALL_OPTIONAL_system=true

# -- Shipping API level ----------------------------------------------------
# The stock device launched on Android 14 (ro.product.first_api_level=34) and
# its vendor is HIDL-based (Beanpod Keymaster 4.1 among others). This MUST be
# set: with PRODUCT_SHIPPING_API_LEVEL unset, main.mk installs NONE of the
# PRODUCT_PACKAGES_SHIPPING_API_LEVEL_* lists, so hwservicemanager is dropped
# (leaving a dangling /system/bin/hwservicemanager compat symlink). keystore2
# then never reaches Keymaster, vold blocks on keystore2 at late-fs, and the
# boot hangs on the LK splash forever.
PRODUCT_SHIPPING_API_LEVEL := 34

PRODUCT_PACKAGES += \
    otapreopt_script \
    update_engine \
    update_engine_sideload \
    update_verifier

# -- Dynamic partition / filesystem tooling (host + target) --------------
# lpmake is HOST-only; putting it in PRODUCT_PACKAGES is a hard build error
# ("Host modules should be in PRODUCT_HOST_PACKAGES"). It is not needed here
# anyway -- the build pulls it in as a host tool when it assembles a super
# image. The rest below all have real target variants and are useful on-device
# (fastbootd resizing logical partitions, recovery filesystem checks).
PRODUCT_PACKAGES += \
    lpdump \
    mkfs.erofs \
    fsck.erofs \
    make_f2fs \
    fsck.f2fs

# -- Kernel module path compat -------------------------------------------
# /system/lib/modules -> /system_dlkm/lib/modules is REQUIRED: vendor
# modules.dep references /system/lib/modules/rfkill.ko, and without the link
# cfg80211 never loads (Wi-Fi: "Unknown symbol cfg80211_*", no wlan0). The
# build creates it because BOARD_USES_SYSTEM_DLKMIMAGE is set (BoardConfig.mk);
# do not add a second copy here -- it collides with the build's own rule.

# -- SurfaceFlinger RenderEngine ---------------------------------------------
# Stock vendor sets debug.renderengine.backend=skiagl (non-threaded). With the
# LOS 22.2 (A15 QPR2) SurfaceFlinger (inherited from clove; not yet re-checked on
# 24.0) that path is a use-after-free:
# renderScreenImpl() captures a raw RenderArea* in a lambda that, for a
# NON-threaded RenderEngine, is deferred onto the main thread after
# captureScreenshot() has already destroyed the RenderArea. Every screenshot /
# task snapshot then SIGSEGVs SurfaceFlinger in ScreenCaptureOutput, which
# restarts system_server ("reboots" when opening e.g. Settings > Reset options).
# The threaded backend runs present() synchronously and is the AOSP default.
# Product props load after vendor, so this overrides the stock value.
PRODUCT_PRODUCT_PROPERTIES += \
    debug.renderengine.backend=skiaglthreaded

# -- Recovery -----------------------------------------------------------------
# ro.hardware is mt8786; stock ships the same file under both platform names.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init.recovery.mt8786.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.mt8786.rc \
    $(LOCAL_PATH)/rootdir/etc/init.recovery.mt8786.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.mt6768.rc

# -- Overlays ------------------------------------------------------------
PRODUCT_PACKAGES += \
    FrameworksResOverlayPoplar \
    WifiResOverlayPoplar

# -- Soong namespace -----------------------------------------------------
PRODUCT_SOONG_NAMESPACES += $(LOCAL_PATH)

# Boot control. MediaTek's HAL (hardware/mediatek) rather than the AOSP default: switching slots here also switches the eMMC boot area
# (preloader_a/b). LineageOS recovery has no boot HAL of its own, and without
# one update_engine_sideload cannot install anything.
PRODUCT_PACKAGES += \
    android.hardware.boot-service.mediatek \
    android.hardware.boot-service.mediatek_recovery

# First-stage fstab (vendor_boot platform ramdisk). LK passes
# androidboot.hardware=mt8786, so first-stage init reads fstab.mt8786; Lenovo
# ships the same file under all three names. fstab.mt8786dm is the variant with
# the dm-userdata (lenovobackup) layout.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt6768:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.mt6768 \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt6768:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.mt8786 \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt8786dm:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.mt8786dm

# -- Init / fstab (vendor) ------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.enableswap:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.enableswap \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt6768:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6768 \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt6768:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt8786 \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt8786dm:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6768dm \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt8786dm:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt8786dm \
    $(LOCAL_PATH)/rootdir/etc/fstab.zram_wb:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.zram_wb \
    $(LOCAL_PATH)/rootdir/etc/init.insmod.mt8786.cfg:$(TARGET_COPY_OUT_VENDOR)/etc/init.insmod.mt8786.cfg \
    $(LOCAL_PATH)/rootdir/etc/init.insmod.sh:$(TARGET_COPY_OUT_VENDOR)/bin/init.insmod.sh \
    $(LOCAL_PATH)/rootdir/etc/ueventd.mt8786.rc:$(TARGET_COPY_OUT_VENDOR)/etc/ueventd.rc

PRODUCT_COPY_FILES += \
    $(foreach f,init.aee.rc init.ago.rc init.cgroup.rc init.connectivity.common.rc \
        init.connectivity.rc init_connectivity.rc init.mt6768.usb.rc init.mt8786.rc \
        init.modem.rc init.mtkgki.rc init.project.rc init.sensor_1_0.rc,\
        $(LOCAL_PATH)/rootdir/etc/$(f):$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/$(f))

# -- Permissions / hardware features ---------------------------------------------
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.audio.low_latency.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.audio.low_latency.xml \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.faketouch.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.faketouch.xml \
    frameworks/native/data/etc/android.hardware.location.gps.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.location.gps.xml \
    frameworks/native/data/etc/android.hardware.opengles.aep.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.opengles.aep.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/android.hardware.sensor.proximity.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.proximity.xml \
    frameworks/native/data/etc/android.hardware.sensor.stepcounter.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.stepcounter.xml \
    frameworks/native/data/etc/android.hardware.sensor.stepdetector.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.stepdetector.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.distinct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.distinct.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.vulkan.compute-0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.compute-0.xml \
    frameworks/native/data/etc/android.hardware.vulkan.level-1.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.level-1.xml \
    frameworks/native/data/etc/android.hardware.vulkan.version-1_3.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.version-1_3.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.hardware.wifi.passpoint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.passpoint.xml \
    frameworks/native/data/etc/android.hardware.telephony.calling.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.calling.xml \
    frameworks/native/data/etc/android.hardware.telephony.data.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.data.xml \
    frameworks/native/data/etc/android.hardware.telephony.gsm.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.gsm.xml \
    frameworks/native/data/etc/android.hardware.telephony.ims.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.ims.xml \
    frameworks/native/data/etc/android.hardware.telephony.messaging.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.messaging.xml \
    frameworks/native/data/etc/android.hardware.telephony.radio.access.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.radio.access.xml \
    frameworks/native/data/etc/android.hardware.telephony.subscription.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.subscription.xml \
    frameworks/native/data/etc/android.hardware.se.omapi.uicc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.se.omapi.uicc.xml \
    frameworks/native/data/etc/android.software.sip.voip.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.sip.voip.xml \
    frameworks/native/data/etc/android.software.ipsec_tunnels.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.ipsec_tunnels.xml \
    frameworks/native/data/etc/android.software.midi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.midi.xml \
    frameworks/native/data/etc/android.software.verified_boot.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.verified_boot.xml \
    $(LOCAL_PATH)/configs/permissions/android.hardware.camera.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.xml \
    $(LOCAL_PATH)/configs/permissions/android.hardware.microphone.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.microphone.xml \
    $(LOCAL_PATH)/configs/permissions/android.software.opengles.deqp.level.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.opengles.deqp.level.xml \
    $(LOCAL_PATH)/configs/permissions/android.software.vulkan.deqp.level.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.vulkan.deqp.level.xml \
    $(LOCAL_PATH)/configs/permissions/handheld_core_hardware.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/handheld_core_hardware.xml

PRODUCT_PACKAGES += \
    android.hardware.hardware_keystore.km41.xml

# -- HALs and services built from source --------------------------------------
# Audio
PRODUCT_PACKAGES += \
    audio.bluetooth.default \
    audio.r_submix.default \
    audio.usb.default \
    audio_policy.stub

PRODUCT_PACKAGES += \
    libaecsw \
    libagc1sw \
    libagc2sw \
    libbassboostsw \
    libbundleaidl \
    libdownmixaidl \
    libdynamicsprocessingaidl \
    libequalizersw \
    libextensioneffect \
    libhapticgeneratoraidl \
    libloudnessenhanceraidl \
    libnssw \
    libpreprocessingaidl \
    libpresetreverbsw \
    libreverbaidl \
    libspatializersw \
    libvirtualizersw \
    libvisualizeraidl \
    libvolumesw

# AEE stub libraries, chipinfo
PRODUCT_PACKAGES += \
    chipinfo \
    libaedv \
    libladder

# DRM
PRODUCT_PACKAGES += \
    android.hardware.drm-service.clearkey

# Health
PRODUCT_PACKAGES += \
    android.hardware.health-service.mediatek \
    android.hardware.health-service.mediatek-recovery

# Memtrack
PRODUCT_PACKAGES += \
    android.hardware.memtrack-service.mediatek

# Sensors (the sub-HALs listed in /vendor/etc/sensors/hals.conf are blobs)
PRODUCT_PACKAGES += \
    android.hardware.sensors-service.multihal \
    sensors.dynamic_sensor_hal

# USB: the stock init.mt6768.usb.rc (rootdir/etc) is used, not the one from
# hardware/mediatek.
$(call soong_config_set_bool,mediatek_gadget,use_custom_usb_gadget_rc,true)

# VNDK
PRODUCT_PACKAGES += \
    vndservicemanager

# Wi-Fi: AOSP service. Lenovo's libwifi-hal-mtk.so is built against the
# Android 15 wifi_hal.h; libwifi-hal-wrapper translates its function table.
$(call soong_config_set_bool,mediatek_wifi_hal,use_pre_baklava_qpr0_struct,true)

PRODUCT_PACKAGES += \
    android.hardware.wifi-service \
    hostapd \
    libwifi-hal-wrapper \
    wlan_assistant \
    wpa_supplicant

PRODUCT_SOONG_NAMESPACES += \
    hardware/mediatek

# -- Proprietary files -------------------------------------------------------
$(call inherit-product, vendor/lenovo/poplar/poplar-vendor.mk)
