#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/oppo/CPH1909

# Screen density: 720x1520 panel
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xhdpi

TARGET_SCREEN_HEIGHT := 1520
TARGET_SCREEN_WIDTH := 720

# API level: the device launched on 8.1 (API 27) with 8.1-era vendor blobs
PRODUCT_SHIPPING_API_LEVEL := 27

# Framework resource overlay
#
# power_profile.xml supplies the energy-use model BatteryStats needs to estimate
# battery drain (per-cluster CPU speeds and power for the 4x2.3 GHz + 4x1.8 GHz
# Helio P35, plus the 4230 mAh battery). AOSP ships only deliberately bogus
# placeholder values, so every battery statistic the framework reports is
# meaningless without a device profile.
DEVICE_PACKAGE_OVERLAYS += \
    $(DEVICE_PATH)/overlay

# Permissions
#
# android.hardware.microphone.xml is deliberately absent: AOSP 10 ships no
# standalone file of that name (the feature is declared by
# handheld_core_hardware.xml), so listing it breaks the vendor image build.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.camera.flash-autofocus.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.flash-autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.front.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.front.xml \
    frameworks/native/data/etc/android.hardware.camera.full.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.full.xml \
    frameworks/native/data/etc/android.hardware.fingerprint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.fingerprint.xml \
    frameworks/native/data/etc/android.hardware.location.gps.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.location.gps.xml \
    frameworks/native/data/etc/android.hardware.opengles.aep.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.opengles.aep.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.compass.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.compass.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/android.hardware.sensor.proximity.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.proximity.xml \
    frameworks/native/data/etc/android.hardware.telephony.gsm.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.gsm.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.software.midi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.midi.xml \
    frameworks/native/data/etc/handheld_core_hardware.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/handheld_core_hardware.xml

# Hardware key layouts
#
# AOSP 10 ships neither the MediaTek accessory-detect headset-button map
# (ACCDET.kl) nor its keypad map (mtk-kpd.kl). Without them the wired headset
# buttons (hook, media transport, VOICE_ASSIST) and the mtk-kpd key map fall
# back to Generic.kl, so the stock files are copied into the system keylayout
# directory unchanged.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/configs/keylayout/ACCDET.kl:$(TARGET_COPY_OUT_SYSTEM)/usr/keylayout/ACCDET.kl \
    $(DEVICE_PATH)/configs/keylayout/mtk-kpd.kl:$(TARGET_COPY_OUT_SYSTEM)/usr/keylayout/mtk-kpd.kl

# HALs that Android 10 needs and an 8.1 vendor image never shipped.
#
# The stock vendor partition provides every MediaTek service listed in
# manifest.xml (audio, bluetooth, camera, graphics, sensors, wifi, radio,
# keymaster, gatekeeper, drm@1.0, ...). What it cannot provide are the HALs that
# Android 10 itself started to require, so those are built from source here and
# also declared in manifest.xml:
#
#   health@2.0   8.1 used the in-system healthd; Q wants a vendor HAL service
#   usb@1.0      8.1 used the legacy USB gadget init scripts only
#   drm@1.2      clearkey instance; the stock 1.0 service keeps default/widevine
#
# libdrmclearkeyplugin and libclearkeycasplugin are already part of
# base_vendor.mk, so the DRM/CAS software plugins come from AOSP as well.
PRODUCT_PACKAGES += \
    android.hardware.drm@1.2-service.clearkey \
    android.hardware.health@2.0-service \
    android.hardware.usb@1.0-service

# Bluetooth A2DP audio HAL
PRODUCT_PACKAGES += \
    audio.a2dp.default

# Configs
#
# Only the /vendor copy is installed. On this non-system-as-root device the
# kernel DT fstab (mt6765.dts) is authoritative for first-stage mount: init
# mounts /system from it, pivots the root to /system, then mounts /vendor from
# the new root, all before this file is ever parsed. The same file then serves
# the second-stage mount_all from the stock init.mt6765.rc and recovery
# (TARGET_RECOVERY_FSTAB).
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/rootdir/etc/fstab.mt6765:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6765

# zram helper started by the stock init.mt6765.rc from its `on fs` block.
# See the header of the script for why this is a rewrite, not the stock copy.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/rootdir/bin/swap_enable.sh:$(TARGET_COPY_OUT_SYSTEM)/etc/swap_enable.sh

# Default properties
#
# ro.mtkrc.path is read while parsing /vendor/etc/init/hw/init.mt6765.rc to
# expand its `import ${ro.mtkrc.path}init.*.rc` lines. Properties from
# prop.default are loaded before the boot scripts are parsed, so it has to be a
# default property, not one set later from an init action.
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.mtkrc.path=/vendor/etc/init/hw/

# Generated by the proprietary-blob extraction step when vendor/oppo/CPH1909 is
# populated from the matching CPH1909 Android 8.1 firmware.
$(call inherit-product-if-exists, vendor/oppo/CPH1909/CPH1909-vendor.mk)
