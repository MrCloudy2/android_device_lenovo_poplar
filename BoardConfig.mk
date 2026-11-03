#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# LineageOS 24.0 (Android 17) board config for the Lenovo Tab
# (TB311XU / poplar). MediaTek MT6768/MT8786 family, GKI 6.6 kernel.
#

DEVICE_PATH := device/lenovo/poplar

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a53
TARGET_CPU_VARIANT_RUNTIME := cortex-a53

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a53
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a53

TARGET_SUPPORTS_64_BIT_APPS := true

# The vendor blobs are frozen at API 30 (GRF), as on stock
# (ro.board.first_api_level=30).
BOARD_SHIPPING_API_LEVEL := 30

# Platform
TARGET_BOARD_PLATFORM := mt6768
TARGET_BOOTLOADER_BOARD_NAME := poplar
TARGET_NO_BOOTLOADER := true

# OTA
TARGET_OTA_ASSERT_DEVICE := TB311XU,poplar

# Kernel: prebuilt, from device/lenovo/poplar-kernel (see its README).
# Image.gz and system_dlkm modules are an unmodified AOSP GKI android15-6.6
# build; vendor_dlkm / vendor_ramdisk modules, DTB and DTBO are stock Lenovo.
KERNEL_PATH := $(DEVICE_PATH)-kernel
TARGET_NO_KERNEL := false
TARGET_PREBUILT_KERNEL := $(KERNEL_PATH)/Image.gz
TARGET_PREBUILT_KERNEL_HEADERS := $(KERNEL_PATH)/kernel-uapi-headers.tar.gz
BOARD_PREBUILT_DTBIMAGE_DIR := $(KERNEL_PATH)/dtb
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_PREBUILT_DTBOIMAGE := $(KERNEL_PATH)/dtbo.img

# Kernel modules
BOARD_SYSTEM_KERNEL_MODULES := $(wildcard $(KERNEL_PATH)/modules/system_dlkm/*.ko)
BOARD_SYSTEM_KERNEL_MODULES_LOAD := $(strip $(shell cat $(KERNEL_PATH)/modules/system_dlkm/modules.load))
BOARD_VENDOR_KERNEL_MODULES := $(wildcard $(KERNEL_PATH)/modules/vendor_dlkm/*.ko)
BOARD_VENDOR_KERNEL_MODULES_LOAD := $(strip $(shell cat $(KERNEL_PATH)/modules/vendor_dlkm/modules.load))
BOARD_VENDOR_RAMDISK_KERNEL_MODULES := $(wildcard $(KERNEL_PATH)/modules/vendor_ramdisk/*.ko)
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD := $(strip $(shell cat $(KERNEL_PATH)/modules/vendor_ramdisk/modules.load))
BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD := $(strip $(shell cat $(KERNEL_PATH)/modules/vendor_ramdisk/modules.load.recovery))

# Stock Android 15 GKI boot image geometry (header v4, 4 KiB pages)
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_BASE := 0x40000000
BOARD_KERNEL_OFFSET := 0x00080000
BOARD_RAMDISK_OFFSET := 0x07c80000
BOARD_KERNEL_TAGS_OFFSET := 0x0bc80000
BOARD_DTB_OFFSET := 0x0bc80000
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET)
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)
BOARD_MKBOOTIMG_ARGS += --dtb_offset $(BOARD_DTB_OFFSET)
BOARD_RAMDISK_USE_LZ4 := true

# Launched with init_boot (Android 13+ GKI): as on stock, boot.img is kernel
# only and the generic ramdisk lives in init_boot.img (stock: header v4,
# 8 MiB partition). Without this the ramdisk lands in boot.img while the
# bootloader keeps loading the stock init_boot ramdisk.
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_INIT_BOOT_HEADER_VERSION := 4
BOARD_MKBOOTIMG_INIT_ARGS += --header_version $(BOARD_INIT_BOOT_HEADER_VERSION)

# A/B with Virtual A/B snapshots (matches stock)
AB_OTA_UPDATER := true
BOARD_USES_RECOVERY_AS_BOOT :=
TARGET_NO_RECOVERY := true
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true

# Full A/B OTA: every partition LineageOS builds. Firmware (preloader, lk,
# tee, gz, scp, sspm, spmfw, md1img) is NOT shipped, as usual for LineageOS:
# both slots must already carry the same stock firmware (see README).
AB_OTA_PARTITIONS += \
    boot \
    init_boot \
    vendor_boot \
    dtbo \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor \
    system \
    system_ext \
    product \
    vendor \
    vendor_dlkm \
    odm_dlkm \
    system_dlkm

# Virtual A/B (compression.mk is inherited in the product makefile)
BOARD_SUPER_PARTITION_METADATA_DEVICE := super

# Dynamic / super partition
BOARD_SUPER_PARTITION_SIZE := 11811160064
# Same group name and size as stock ("main" -> main_a / main_b in metadata).
BOARD_SUPER_PARTITION_GROUPS := main
BOARD_MAIN_PARTITION_LIST := \
    system \
    system_ext \
    product \
    vendor \
    vendor_dlkm \
    odm_dlkm \
    system_dlkm
BOARD_MAIN_SIZE := 10200547328
# PRODUCT_USE_DYNAMIC_PARTITIONS is a PRODUCT variable and is already set (and
# made readonly) by lineage_poplar.mk before BoardConfig.mk is parsed.
# Setting it here is a hard build error -- keep it in the product makefile only.
BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT := false

# Static partition image sizes
BOARD_BOOTIMAGE_PARTITION_SIZE := 33554432
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
BOARD_FLASH_BLOCK_SIZE := 262144

# Filesystems — stock uses EROFS for read-only logical partitions, F2FS userdata
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
# system, system_ext and product are ext4 with reserved space instead, so
# MindTheGapps can be installed on top from recovery (EROFS has no free space
# and cannot be written). The stock fstab already lists an ext4 variant for
# each of them.
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE := 268435456
BOARD_SYSTEM_EXTIMAGE_PARTITION_RESERVED_SIZE := 268435456
BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE := 1610612736
BOARD_EROFS_COMPRESSOR := lz4hc,9
BOARD_EROFS_PCLUSTER_SIZE := 65536

TARGET_COPY_OUT_SYSTEM := system
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_PRODUCT := product

# TARGET_COPY_OUT_VENDOR MUST be 'vendor', even though this port does not ship
# the vendor image it builds. If it is left unset, board_config.mk silently
# defaults it to the legacy 'system/vendor', and the build then emits /vendor
# as a SYMLINK to /system/vendor instead of a real directory. A partition
# cannot be mounted onto a symlink, so first-stage init mounts system and
# system_ext, fails on vendor, and the device bootloops with
#   Kernel panic - not syncing: Attempted to kill init!
# This cost a full flash/bootloop/forensics cycle to find. Do not remove it.
TARGET_COPY_OUT_VENDOR := vendor
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs

TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
TARGET_COPY_OUT_ODM_DLKM := odm_dlkm
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm
BOARD_USES_VENDOR_DLKMIMAGE := true
BOARD_USES_ODM_DLKMIMAGE := true
BOARD_USES_SYSTEM_DLKMIMAGE := true
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs

# vendor_boot = [platform: modules + first-stage fstab] + [recovery]. The
# generic ramdisk (first-stage init, snapuserd) is in boot.img.
#
# NOTE: this LK loads ALL vendor ramdisk fragments on every boot, including
# "recovery", and the real first-stage fstab is fstab.mt8786, which Lenovo ships
# only in its recovery fragment. The platform fragment therefore carries
# first_stage_ramdisk/fstab.mt8786{,dm} (see device.mk).

# Metadata encryption partition (dm-default-key on userdata)
BOARD_USES_METADATA_PARTITION := true

# Recovery / fstab
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.mt6768
TARGET_RECOVERY_PIXEL_FORMAT := BGRA_8888

# Vendor blobs live in vendor/lenovo/poplar
# (generated by extract-files.py against stock firmware).
# Legacy MTK blobs can trip ELF prebuilt validation.
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_PREBUILT_ELF_FILES := true

# SELinux
include device/mediatek/sepolicy_vndr/SEPolicy.mk
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor
# Generated from the stock vendor policy by sepolicy/gen_stock_port.py
# (everything sepolicy_vndr does not already provide).
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor/stock

# Security patch level: stock vendor (ro.vendor.build.security_patch) and the
# stock GKI boot image (com.android.build.boot.security_patch in its AVB footer)
VENDOR_SECURITY_PATCH := 2025-09-05
BOOT_SECURITY_PATCH := 2024-09-05

# Properties
TARGET_PRODUCT_PROP += $(DEVICE_PATH)/product.prop
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop

# VINTF
DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/configs/vintf/manifest.xml
DEVICE_MATRIX_FILE := $(DEVICE_PATH)/configs/vintf/compatibility_matrix.xml
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE += $(DEVICE_PATH)/configs/vintf/framework_compatibility_matrix.xml

# Verified Boot
# Unlike TB305FU (clove), the unlocked TB311XU LK accepts a vbmeta signed with
# any key (tested 2026-11-02 with a self-signed RSA2048 vbmeta, flags 3: boots
# in orange state). No patched LK is needed.
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
BOARD_AVB_ALGORITHM := SHA256_RSA4096
BOARD_AVB_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_ROLLBACK_INDEX := 0

BOARD_AVB_VBMETA_SYSTEM := system system_ext product
BOARD_AVB_VBMETA_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := SHA256_RSA4096
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := 0
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 1

BOARD_AVB_VBMETA_VENDOR := vendor
BOARD_AVB_VBMETA_VENDOR_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_VBMETA_VENDOR_ALGORITHM := SHA256_RSA4096
BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX := 0
BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX_LOCATION := 4

# Wi-Fi
WPA_SUPPLICANT_VERSION := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_HOSTAPD_DRIVER := NL80211
WIFI_DRIVER_FW_PATH_STA := "STA"
WIFI_DRIVER_FW_PATH_AP := "AP"
WIFI_DRIVER_FW_PATH_P2P := "P2P"
WIFI_HIDL_FEATURE_DUAL_INTERFACE := true
WIFI_HIDL_UNIFIED_SUPPLICANT_SERVICE_RC_ENTRY := true
WIFI_DRIVER_FW_PATH_PARAM := "/dev/wmtWifi"
WIFI_DRIVER_STATE_CTRL_PARAM := "/dev/wmtWifi"
WIFI_DRIVER_STATE_ON := "1"
WIFI_DRIVER_STATE_OFF := "0"

# Inherit proprietary blob board config (generated by extract-files.py)
include vendor/lenovo/poplar/BoardConfigVendor.mk

# Graphics (sets ro.hwui.use_vulkan)
TARGET_USES_VULKAN := true
