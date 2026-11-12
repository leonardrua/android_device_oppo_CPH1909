#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first, matching the layout used
# by LineageOS 17.1 trees of other devices that launched with 8.1 stock
# (product_launched_with_o_mr1.mk sets PRODUCT_SHIPPING_API_LEVEL := 27).
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base_telephony.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/product_launched_with_o_mr1.mk)

# Inherit some common LineageOS stuff
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# Inherit from the CPH1909 device
$(call inherit-product, device/oppo/CPH1909/device.mk)

PRODUCT_NAME := lineage_CPH1909
PRODUCT_DEVICE := CPH1909
PRODUCT_MANUFACTURER := OPPO
PRODUCT_BRAND := OPPO
PRODUCT_MODEL := CPH1909
PRODUCT_RELEASE_NAME := A5s

PRODUCT_GMS_CLIENTID_BASE := android-oppo

# Build fingerprint of the stock ROM the vendor blobs came from.
# Keeps the 8.1 vendor blobs happy (they check ro.build.* in a few places) and
# lets SafetyNet basic attestation work.
PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_NAME=CPH1909 \
    PRIVATE_BUILD_DESC="full_oppo6765_18511-user 8.1.0 O11019 1616154336 release-keys"

BUILD_FINGERPRINT := OPPO/CPH1909/CPH1909:8.1.0/O11019/1616154336:user/release-keys
