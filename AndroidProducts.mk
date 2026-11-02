#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/lineage_poplar.mk

# Three-part lunch format: <product>-<release config>-<variant>.
# LineageOS 24.0 (Android 17) uses the `cp2a` release config.
COMMON_LUNCH_CHOICES := \
    lineage_poplar-cp2a-user \
    lineage_poplar-cp2a-userdebug \
    lineage_poplar-cp2a-eng
