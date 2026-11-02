#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base_telephony.mk)

# Generic ramdisk (first-stage init, snapuserd) goes into boot.img.
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_ramdisk.mk)

# Virtual A/B with compression. Not virtual_ab_ota/compression.mk: that also
# puts snapuserd into the vendor ramdisk, and the generic ramdisk has it.
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/launch.mk)
PRODUCT_VIRTUAL_AB_COMPRESSION := true
PRODUCT_PACKAGES += \
    snapuserd \
    snapuserd.recovery

# Inherit from poplar device
$(call inherit-product, device/lenovo/poplar/device.mk)

# Inherit some common Lineage stuff (LTE tablet: telephony, no Wi-Fi-only config)
$(call inherit-product, vendor/lineage/config/common_full_tablet.mk)

PRODUCT_DEVICE := poplar
PRODUCT_NAME := lineage_poplar
PRODUCT_BRAND := Lenovo
PRODUCT_MODEL := TB311XU
PRODUCT_MANUFACTURER := LENOVO

PRODUCT_GMS_CLIENTID_BASE := android-lenovo

PRODUCT_USE_DYNAMIC_PARTITIONS := true

# Stock build fingerprint (ZUI 17, Android 16 / BP2A.250605.031.A3).
BUILD_FINGERPRINT := Lenovo/TB311XU_EEA/TB311XU:16/BP2A.250605.031.A3/37.350.260708W:user/release-keys
