#
# Copyright (C) 2024 The Android Open Source Project
# Copyright (C) 2024 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit some common Omni stuff.
$(call inherit-product, vendor/omni/config/common.mk)

# Inherit from CPH1909 device
$(call inherit-product, device/oppo/CPH1909/device.mk)

PRODUCT_DEVICE := CPH1909
PRODUCT_NAME := omni_CPH1909
PRODUCT_BRAND := OPPO
PRODUCT_MODEL := CPH1909
PRODUCT_MANUFACTURER := OPPO
PRODUCT_RELEASE_NAME := A5s

# Matches the platform the build runs against (twrp-9.0 -> SDK 28). Android 9
# defaults BOARD_SYSTEMSDK_VERSIONS to PLATFORM_SDK_VERSION only when this is
# >= 28, and build/core/config.mk errors out if the shipping level is higher
# than BOARD_SYSTEMSDK_VERSIONS. Treble and VNDK stay off via the explicit
# overrides below, so this only has to be consistent with the platform.
PRODUCT_SHIPPING_API_LEVEL := 28
PRODUCT_USE_DYNAMIC_PARTITIONS := false
PRODUCT_FULL_TREBLE_OVERRIDE := false

# Stock fingerprint from recovery prop.default (CPH1909EX_11_A.42,
# Android 8.1.0, patch 2020-10-05, project 18511).
# CPH1920 reference uses the same oppo6765_18511 base with a newer timestamp
# (1616154336); CPH1909 stock recovery reports 1603200649.
PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="full_oppo6765_18511-user 8.1.0 O11019 1603200649 release-keys"

BUILD_FINGERPRINT := OPPO/CPH1909/CPH1909:8.1.0/O11019/1603200649:user/release-keys
