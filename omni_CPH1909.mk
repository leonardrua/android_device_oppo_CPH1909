#
# Copyright (C) 2024 The Android Open Source Project
# Copyright (C) 2024 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

$(call inherit-product, vendor/omni/config/common.mk)
$(call inherit-product, device/oppo/CPH1909/device.mk)

PRODUCT_DEVICE := CPH1909
PRODUCT_NAME := omni_CPH1909
PRODUCT_BRAND := OPPO
PRODUCT_MODEL := CPH1909
PRODUCT_MANUFACTURER := OPPO
PRODUCT_RELEASE_NAME := A5s

PRODUCT_SHIPPING_API_LEVEL := 27
PRODUCT_USE_DYNAMIC_PARTITIONS := false
PRODUCT_FULL_TREBLE_OVERRIDE := false

# Stock fingerprint from recovery prop.default (CPH1909EX_11_A.42,
# Android 8.1.0, patch 2020-10-05, project 18511).
PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="full_oppo6765_18511-user 8.1.0 O11019 1603200649 release-keys"

BUILD_FINGERPRINT := OPPO/CPH1909/CPH1909:8.1.0/O11019/1603200649:user/release-keys
