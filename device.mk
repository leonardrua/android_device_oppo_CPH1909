#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/oppo/CPH1909

# Soong namespaces: let Soong resolve the Android.bp modules in this device
# tree (biometrics/, interfaces/, etc.). Adapted from xiaomi-lotus-devs
# commit 3ac3eb8; Android.bp in this directory declares soong_namespace {}.
#
# Use DEVICE_PATH, not LOCAL_PATH: LOCAL_PATH is only defined while an
# Android.mk is being parsed, so in a product makefile it expands to nothing
# (and any stale value left by another makefile would point somewhere else).
PRODUCT_SOONG_NAMESPACES += $(DEVICE_PATH)

# Screen density: 720x1520 panel
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xhdpi

TARGET_SCREEN_HEIGHT := 1520
TARGET_SCREEN_WIDTH := 720

# The device launched on 8.1 (API 27) with 8.1-era vendor blobs.
# PRODUCT_SHIPPING_API_LEVEL := 27 comes from the product configuration
# (lineage_CPH1909.mk inherits product/product_launched_with_o_mr1.mk, the
# same mechanism LineageOS 17.1 trees of other 8.1-launched devices use).

# Framework resource overlay
#
# Extracted from the stock CPH1909 framework-res.apk and limited to
# resources that LineageOS 17.1 still defines:
#
#   values/config.xml        device configuration (brightness, display
#                            cutout, telephony, Wi-Fi, Bluetooth, ...)
#   values/dimens.xml        stock status_bar_height for the 55px notch
#                            and the 82px hardware corner radius
#   xml/power_profile.xml    energy model for BatteryStats, with the 8.1
#                            CPU keys mapped to the names Android 10 reads
#
# overlay/README.md records the provenance (input hashes), the complete
# accounting of the 603 stock resources that LineageOS 17.1 also defines,
# and every excluded ROM-policy value with its reason.
DEVICE_PACKAGE_OVERLAYS += \
    $(DEVICE_PATH)/overlay

# Permissions
#
# android.hardware.microphone.xml is deliberately absent: AOSP 10 ships no
# standalone file of that name (the feature is declared by
# handheld_core_hardware.xml), so listing it breaks the vendor image build.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.audio.low_latency.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.audio.low_latency.xml \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.camera.flash-autofocus.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.flash-autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.front.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.front.xml \
    frameworks/native/data/etc/android.hardware.camera.full.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.full.xml \
    frameworks/native/data/etc/android.hardware.camera.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.xml \
    frameworks/native/data/etc/android.hardware.faketouch.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.faketouch.xml \
    frameworks/native/data/etc/android.hardware.biometrics.face.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.biometrics.face.xml \
    frameworks/native/data/etc/android.hardware.fingerprint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.fingerprint.xml \
    frameworks/native/data/etc/android.hardware.location.gps.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.location.gps.xml \
    frameworks/native/data/etc/android.hardware.opengles.aep.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.opengles.aep.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.compass.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.compass.xml \
    frameworks/native/data/etc/android.hardware.sensor.gyroscope.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.gyroscope.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/android.hardware.sensor.proximity.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.proximity.xml \
    frameworks/native/data/etc/android.hardware.sensor.stepcounter.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.stepcounter.xml \
    frameworks/native/data/etc/android.hardware.sensor.stepdetector.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.stepdetector.xml \
    frameworks/native/data/etc/android.hardware.telephony.gsm.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.gsm.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.distinct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.distinct.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
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
#   power@1.0    AOSP HIDL service that serves android.hardware.power@1.0 and
#                forwards to the legacy libhardware power module (power.mt6765).
#                Lineage 17.1 PowerManagerService calls IPower@1.0 setFeature for
#                double-tap-to-wake; the shim writes TARGET_TAP_TO_WAKE_NODE.
#
# libdrmclearkeyplugin and libclearkeycasplugin are already part of
# base_vendor.mk, so the DRM/CAS software plugins come from AOSP as well.
PRODUCT_PACKAGES += \
    android.hardware.drm@1.2-service.clearkey \
    android.hardware.health@2.0-service \
    android.hardware.power@1.0-service \
    android.hardware.usb@1.0-service.basic \
    power.mt6765

# power.mt6765 is defined in power/Android.mk. That subdirectory makefile is
# only reachable through the all-makefiles-under() include at the end of the
# top-level Android.mk: Soong's finder stops descending once it finds an
# Android.mk in a directory, so without that include this module was never
# parsed, PRODUCT_PACKAGES silently resolved to nothing, and the image shipped
# AOSP's power.default.so (whose power_module_t has no setFeature member) --
# making IPower::setFeature(DOUBLE_TAP_TO_WAKE) a no-op. Verify after a build:
#   ls out/target/product/CPH1909/vendor/lib{,64}/hw/power.mt6765.so

# First-stage ramdisk fstab.
#
# The kernel DT no longer carries firmware/android/fstab (kernel commit 8e24bd2,
# "ARM64: dts: Switch mt6765 to 2-stage-init"), so first-stage init falls back
# to GetFstabPath() and needs /fstab.mt6765 in the boot ramdisk. The module is
# defined in the top-level Android.mk because this tree has no rootdir/Android.mk
# and the build only includes the device's top-level makefile (confirmed in the
# CI log: the only "including device/oppo/CPH1909/Android.mk" line is the
# top-level one).
PRODUCT_PACKAGES += \
    fstab.mt6765_ramdisk

# Use the LineageOS "basic" USB HAL (hardware/lineage/interfaces/usb/1.0-basic,
# adapted from xiaomi-lotus-devs commit 738c188) instead of the AOSP default:
# both register the init service vendor.usb-hal-1-0, and this device ships no
# usb.mt6765.so module for the AOSP service to load.

# DRM: build the HIDL 1.0 stack and the software plugins from source (adapted
# from xiaomi-lotus-devs commit b54eded, same MT6765 tree). Verified in LOS 17.1
# hardware/interfaces/drm/1.0/default/Android.mk and
# frameworks/av/drm/mediadrm/plugins/{clearkey,mock}. android.hardware.drm@1.0-
# service.clearkey from the source commit is not a LOS 17.1 module, so the
# already-enabled @1.2 clearkey service is kept instead.
PRODUCT_PACKAGES += \
    android.hardware.drm@1.0-impl \
    android.hardware.drm@1.0-service \
    libdrmclearkeyplugin \
    libmockdrmcryptoplugin

# Gatekeeper: build the default HIDL 1.0 service/impl from source (adapted from
# xiaomi-lotus-devs commit dec7ba5, same MT6765 tree). Verified in LOS 17.1
# hardware/interfaces/gatekeeper/1.0/default/Android.bp:2,21. The stock
# gatekeeper.mt6765.so legacy module is kept; the source impl loads it as a
# passthrough. The vendor copies only produced duplicate-rule warnings.
PRODUCT_PACKAGES += \
    android.hardware.gatekeeper@1.0-service \
    android.hardware.gatekeeper@1.0-impl

# Keymaster: source-build the HIDL 3.0 service instead of copying the stock 8.1
# blobs (adapted from xiaomi-lotus-devs commit f469325, "lotus: Build keymaster
# from source", for the same MT6765 / Android 8.1 -> 10 bring-up). The keystore
# Wi-Fi HIDL libraries are consumers of the source-built keymaster service.
PRODUCT_PACKAGES += \
    android.hardware.keymaster@3.0-service \
    android.hardware.keymaster@3.0-impl \
    libkeystore-engine-wifi-hidl \
    libkeystore-wifi-hidl

# Sensors: build libsensorndkbridge from source instead of copying the stock 8.1
# blobs (adapted from xiaomi-lotus-devs commit ac058b0, same MT6765 tree). The
# Platform build already defines the target; the vendor copies only caused
# duplicate-rule warnings and shadowed it.
PRODUCT_PACKAGES += \
    libsensorndkbridge

# Thermal: build the HIDL 1.0 HAL from source (adapted from xiaomi-lotus-devs
# commit bc8ad0a, same MT6765 tree). Confirmed in LOS 17.1
# hardware/interfaces/thermal/1.0/default/Android.bp. The vendor copies only
# produced duplicate-rule warnings and shadowed the source target.
PRODUCT_PACKAGES += \
    android.hardware.thermal@1.0-impl \
    android.hardware.thermal@1.0-service

# Vibrator: build the HIDL 1.0 HAL from source instead of copying the stock 8.1
# blobs (adapted from xiaomi-lotus-devs commit 5181c28, same MT6765 tree). The
# vendor copies only produced duplicate-rule warnings and shadowed the source
# target.
PRODUCT_PACKAGES += \
    android.hardware.vibrator@1.0-impl \
    android.hardware.vibrator@1.0-service

# Graphics: vendor variant of libgui for 8.1 HALs
#
# vendor blobs such as hwcomposer.mt6765.so DT_NEEDED libgui.so, which is not
# in the vendor namespace. Build the vendor variant and symlink it as
# /vendor/lib{,64}/libgui.so in the top-level Android.mk. Adapted from
# xiaomi-lotus-devs commit dd5519c; confirmed in LOS 17.1
# frameworks/native/libs/gui/Android.bp (libgui_vendor, vendor: true).
PRODUCT_PACKAGES += \
    libgui_vendor

# VNDK
#
# 8.1 vendor blobs were linked against the v28 libbase ABI. Copy the v28
# vndk-sp libbase into /vendor and the blob_fixup above rewrites their
# DT_NEEDED to libbase-v28.so. Paths verified in AOSP 10
# (prebuilts/vndk/v28/...). Adapted from xiaomi-lotus-devs commit 5e805fb.
PRODUCT_COPY_FILES += \
    prebuilts/vndk/v28/arm64/arch-arm-armv8-a/shared/vndk-sp/libbase.so:$(TARGET_COPY_OUT_VENDOR)/lib/libbase-v28.so \
    prebuilts/vndk/v28/arm64/arch-arm64-armv8-a/shared/vndk-sp/libbase.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libbase-v28.so \
    prebuilts/vndk/v28/arm64/arch-arm-armv8-a/shared/vndk-sp/libbase.so:$(TARGET_COPY_OUT_SYSTEM)/lib/libbase-v28.so \
    prebuilts/vndk/v28/arm64/arch-arm64-armv8-a/shared/vndk-sp/libbase.so:$(TARGET_COPY_OUT_SYSTEM)/lib64/libbase-v28.so

# System-side VNDK: the 8.1 /system MTK blobs were linked when the system
# namespace still searched /vendor/${LIB}. Android 10's [system] namespace is
# isolated (search /system/${LIB}, links runtime,resolv), so a /system blob's
# DT_NEEDED on a vendor-only lib cannot resolve. Ship the vendor-only libs that
# the system blobs need into /system/${LIB} as well; the /vendor copies stay
# for the vendor processes. Affected system blobs:
#   audio:  libbessound_hd_mtk.so, libmtklimiter.so, libmtkshifter.so
#   DRM:    libdrmmtkutil.so, mtkdrm/libdrmmtkplugin.so       -> libmtk_drvb.so
#   VT:     libmtk_vt_service.so, libimsma.so, libsink.so,
#           libsource.so, libmtk_vt_wrapper.so ...             -> libvcodec_cap.so
# libmtk_drvb.so and the libvcodec_cap closure have only LLNDK deps.
PRODUCT_COPY_FILES += \
    vendor/oppo/CPH1909/proprietary/vendor/lib/libmtk_drvb.so:$(TARGET_COPY_OUT_SYSTEM)/lib/libmtk_drvb.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib64/libmtk_drvb.so:$(TARGET_COPY_OUT_SYSTEM)/lib64/libmtk_drvb.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib/libbwc.so:$(TARGET_COPY_OUT_SYSTEM)/lib/libbwc.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib64/libbwc.so:$(TARGET_COPY_OUT_SYSTEM)/lib64/libbwc.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib/libion_mtk.so:$(TARGET_COPY_OUT_SYSTEM)/lib/libion_mtk.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib64/libion_mtk.so:$(TARGET_COPY_OUT_SYSTEM)/lib64/libion_mtk.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib/libion_ulit.so:$(TARGET_COPY_OUT_SYSTEM)/lib/libion_ulit.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib64/libion_ulit.so:$(TARGET_COPY_OUT_SYSTEM)/lib64/libion_ulit.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib/libmp4enc_sa.ca7.so:$(TARGET_COPY_OUT_SYSTEM)/lib/libmp4enc_sa.ca7.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib/libpowerhalwrap.so:$(TARGET_COPY_OUT_SYSTEM)/lib/libpowerhalwrap.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib64/libpowerhalwrap.so:$(TARGET_COPY_OUT_SYSTEM)/lib64/libpowerhalwrap.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib/libvc1dec_sa.ca7.so:$(TARGET_COPY_OUT_SYSTEM)/lib/libvc1dec_sa.ca7.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib/libvcodec_cap.so:$(TARGET_COPY_OUT_SYSTEM)/lib/libvcodec_cap.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib64/libvcodec_cap.so:$(TARGET_COPY_OUT_SYSTEM)/lib64/libvcodec_cap.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib/libvcodec_capenc.so:$(TARGET_COPY_OUT_SYSTEM)/lib/libvcodec_capenc.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib64/libvcodec_capenc.so:$(TARGET_COPY_OUT_SYSTEM)/lib64/libvcodec_capenc.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib/libvcodec_oal.so:$(TARGET_COPY_OUT_SYSTEM)/lib/libvcodec_oal.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib64/libvcodec_oal.so:$(TARGET_COPY_OUT_SYSTEM)/lib64/libvcodec_oal.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib/libvcodec_utility.so:$(TARGET_COPY_OUT_SYSTEM)/lib/libvcodec_utility.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib64/libvcodec_utility.so:$(TARGET_COPY_OUT_SYSTEM)/lib64/libvcodec_utility.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib/libvcodecdrv.so:$(TARGET_COPY_OUT_SYSTEM)/lib/libvcodecdrv.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib64/libvcodecdrv.so:$(TARGET_COPY_OUT_SYSTEM)/lib64/libvcodecdrv.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib/libvp8dec_sa.ca7.so:$(TARGET_COPY_OUT_SYSTEM)/lib/libvp8dec_sa.ca7.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib/libvp8enc_sa.ca7.so:$(TARGET_COPY_OUT_SYSTEM)/lib/libvp8enc_sa.ca7.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib/vendor.mediatek.hardware.power@1.1_vendor.so:$(TARGET_COPY_OUT_SYSTEM)/lib/vendor.mediatek.hardware.power@1.1_vendor.so \
    vendor/oppo/CPH1909/proprietary/vendor/lib64/vendor.mediatek.hardware.power@1.1_vendor.so:$(TARGET_COPY_OUT_SYSTEM)/lib64/vendor.mediatek.hardware.power@1.1_vendor.so

# Audio: build generic audio modules from source (adapted from
# xiaomi-lotus-devs commit 8610177, same MT6765 tree). audio.a2dp.default is
# already enabled above. audio.bluetooth.default is a real LineageOS 17.1
# module (system/bt/audio_bluetooth_hw/Android.bp). The vendor copies of these
# targets only produced duplicate-rule warnings and shadowed the source modules.
PRODUCT_PACKAGES += \
    audio.bluetooth.default \
    audio.usb.default \
    audio.r_submix.default \
    audio_policy.stub \
    android.hardware.soundtrigger@2.0 \
    libaudiopreprocessing \
    libtinycompress \
    libtinyxml

# Biometrics / fingerprint
#
# The CPH1909 uses a Silead sensor behind /dev/silead_fp (CONFIG_SILEAD_FP=y in
# the authoritative 8.1 kernel; Goodix DTS is commented out, Egis is present but
# secondary). The stock vendor image ships both legacy HALs,
# fingerprint.silead.default.so (backed by libsl_fp_impl.so) and
# fingerprint.egis.default.so (backed by vendor.egistec...@4.0.so/libRbsFlow.so,
# /dev/esfp0), plus a stock HIDL service that registers the *vendor* interface
# vendor.oppo.hardware.biometrics.fingerprint@2.1, not the AOSP one that the
# Lineage/Android 10 framework binds to.
#
# hw_get_module("fingerprint") probes fingerprint.<ro.hardware>.so with
# ro.hardware=mt6765, but libhardware rejects a module whose HMI id does not
# match the requested class id (the vendor HMI ids are "fingerprint.silead" and
# "fingerprint.egis"). fingerprint.mt6765 is therefore a tiny shim (built from
# biometrics/fingerprint/) that exports a "fingerprint"-id HMI and forwards
# open() via dlopen to the first vendor module that works, in the same order as
# the stock service: Silead, then Egis. The AOSP default 2.1 service then
# registers android.hardware.biometrics.fingerprint@2.1::IBiometricsFingerprint.
#
# Face unlock is userspace-only on this device (stock megface/stface libs and
# vendor.oppo.hardware.biometrics.face@1.0-service; no face driver in the
# authoritative CPH1909 kernel). Android 10 ships no AOSP face@1.0 default
# service and the vendor ships no legacy face HAL module, so unlike fingerprint
# there is nothing to wrap: android.hardware.biometrics.face@1.0-service is
# built from source (biometrics/face/) to provide the interface the Lineage
# stack binds to, and forwards to the OPPO backend through OppoFaceHal. The
# vendor interface is rebuilt from a reconstruction of the stock library
# (interfaces/vendor/hardware/biometrics/face/1.0/). The stock face_hal service
# is enabled (its rc no longer marks it disabled) and the ColorOS-only
# android.frameworks.faceservice@1.0.so it needs is shipped into /vendor/lib{,64};
# OppoFaceHal connects to the late_start backend with a blocking getService.
# The forwarding is reverse-engineered and UNVERIFIED; see
# biometrics/face/OppoFaceHal.h. This does not claim face unlock works.
PRODUCT_PACKAGES += \
    android.hardware.biometrics.face@1.0-service \
    android.hardware.biometrics.fingerprint@2.1-service \
    fingerprint.mt6765

# HIDL transport compatibility for 8.1 vendor blobs
#
# Android 10 merged libhidltransport and libhwbinder into libhidlbase and
# removed them from base_system.mk. The stock 8.1 vendor binaries
# (camerahalserver, mtkfusionrild, every vendor.mediatek.hardware.* service,
# etc.) have explicit DT_NEEDED entries for both libraries. Without these
# packages the dynamic linker aborts every vendor HAL with
# "library \"libhidltransport.so\" not found", causing a total boot failure.
PRODUCT_PACKAGES += \
    libhidltransport \
    libhidltransport.vendor \
    libhwbinder \
    libhwbinder.vendor

# libstdc++ for the 8.1 vendor blobs
#
# 126 vendor ELFs DT_NEEDED libstdc++.so (camera stack, IMS/modem daemons,
# libhwuiext, libmediatek_exceptionlog, ...). Under full VNDK the vendor
# namespace no longer searches /system/${LIB}, so request the Soong vendor
# variant of bionic's libstdc++ (vendor_available: true in
# bionic/libc/Android.bp) to install /vendor/lib{,64}/libstdc++.so.
PRODUCT_PACKAGES += \
    libstdc++.vendor

# Bluetooth A2DP audio HAL
PRODUCT_PACKAGES += \
    audio.a2dp.default

# Configs
#
# Two copies of the fstab. The ramdisk copy (fstab.mt6765_ramdisk, defined in
# the top-level Android.mk) is what first-stage init reads from /fstab.mt6765
# now that the kernel DT no longer carries a firmware/android/fstab node: Q's
# GetFstabPath() probes /odm/etc/fstab.<hw>, /vendor/etc/fstab.<hw> and
# /fstab.<hw>, so the ramdisk root is the only one reachable before /system and
# /vendor are mounted. The entries used there carry first_stage_mount, so init
# mounts /system, pivots to it, then mounts /vendor.
#
# This /vendor copy serves the second-stage mount_all from the stock
# init.mt6765.rc and recovery (TARGET_RECOVERY_FSTAB). fs_mgr skips entries that
# already carry first_stage_mount and are mounted, so nothing is mounted twice.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/rootdir/etc/fstab.mt6765:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6765

# OPPO init scripts from the stock boot ramdisk
#
# The stock vendor init.mt6765.rc imports init.oppo.debug.rc and
# init.oppo.engineermode.rc by relative name, and the debug script imports
# init.oppo.reserve.rc the same way. Relative imports resolve against init's
# working directory, which is the system image root after first-stage init
# pivots to it. Install the three adapted scripts there. The boot ramdisk stays
# minimal (init only) and is freed after the pivot, so a ramdisk copy would not
# be visible when the vendor scripts are parsed.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/rootdir/init.oppo.debug.rc:$(TARGET_COPY_OUT_ROOT)/init.oppo.debug.rc \
    $(DEVICE_PATH)/rootdir/init.oppo.engineermode.rc:$(TARGET_COPY_OUT_ROOT)/init.oppo.engineermode.rc \
    $(DEVICE_PATH)/rootdir/init.oppo.reserve.rc:$(TARGET_COPY_OUT_ROOT)/init.oppo.reserve.rc

# Stub for the stock /FWUpgradeInit.rc.
#
# init.mt6765.rc imports /FWUpgradeInit.rc by absolute path (line 6 of the
# vendor init script). The stock ramdisk ships it at the filesystem root,
# but the CPH1909 A.46 dump does not contain it and this tree does not
# ship the ColorOS firmware-upgrade binaries it would reference. Without
# this stub, init logs "cannot open /FWUpgradeInit.rc" on every boot.
#
# Install it at the root of the system image (which is the root filesystem
# on this non-system-as-root, ramdisk-booting device), alongside the
# init.oppo.*.rc files above.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/rootdir/FWUpgradeInit.rc:$(TARGET_COPY_OUT_ROOT)/FWUpgradeInit.rc

# Stock ramdisk-only FPSGO kernel module
#
# The stock boot ramdisk ships lib/modules/fpsgo.ko, and the stock init.mt6765.rc
# loaded it with `insmod /lib/modules/fpsgo.ko`. Android 10's system image root
# has no /lib, so the vendor init script in this tree has been edited to load
# /system/lib/modules/fpsgo.ko -- the path used here. Nothing else in the tree
# references /lib, so no compatibility symlink is needed.
#
# NOTE: re-extracting vendor/etc/init/hw/init.mt6765.rc from a stock dump
# restores the old /lib path. Re-apply that one-line edit after any re-extract
# (it is a plain text change in the vendor blob tree).
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/rootdir/modules/fpsgo.ko:$(TARGET_COPY_OUT_SYSTEM)/lib/modules/fpsgo.ko

# Recovery init
#
# Recovery imports /init.recovery.${ro.hardware}.rc from its ramdisk; with
# ro.hardware=mt6765 this supplies the bootdevice alias the by-name fstab paths
# rely on, backlight access, the Trustonic TEE nodes keymaster needs during
# sideload, and the MTK watchdog tweak.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/rootdir/etc/init.recovery.mt6765.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.mt6765.rc

# IMS (VoLTE) permission declarations
#
# Declares the android.hardware.telephony.ims feature (this file ships with
# AOSP's frameworks/native) and allows the two stock IMS applications
# imported in the vendor tree (com.mediatek.ims, com.coloros.simsettings)
# their signature|privileged permissions at install time. Without the
# allowlist the framework refuses those permissions at package scan.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.telephony.ims.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/permissions/android.hardware.telephony.ims.xml \
    $(DEVICE_PATH)/configs/permissions/privapp-permissions-ims.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/permissions/privapp-permissions-ims.xml

# zram helper started by the stock init.mt6765.rc from its `on fs` block.
# See the header of the script for why this is a rewrite, not the stock copy.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/rootdir/bin/swap_enable.sh:$(TARGET_COPY_OUT_SYSTEM)/etc/swap_enable.sh

# Media profiles
#
# Android 10's MediaProfiles only searches /odm/etc and /vendor/etc for
# media_profiles_V1_0.xml (plus /system/etc/media_profiles.xml). The stock 8.1
# vendor image installs its profiles as /vendor/etc/media_profiles.xml, so the
# framework never finds them. Install the same, unmodified stock file under the
# name Android 10 looks for; it carries the device's own 1080p/720p camcorder
# profiles and encoder capabilities.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/configs/media/media_profiles_V1_0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_profiles_V1_0.xml

# xHE-AAC decoder
#
# Instagram and Facebook serve audio as xHE-AAC (mp4a.40.42). Neither the C2
# AAC software decoder nor the stock 8.1 SoftAAC2 OMX decoder can decode it, so
# build AOSP's libxaac-backed OMX decoder (SoftXAAC plus external/libxaac) and
# the platform soft-OMX plugin that hosts it.
#
# Linker note: this is a full VNDK build (BOARD_VNDK_VERSION := current), so the
# 8.1 vendor OMX service does NOT see /system/lib. OMXMaster loads the plugin
# into the isolated "sphal" namespace, whose search paths are only
# /odm/${LIB}, /vendor/${LIB} and /vendor/${LIB}/hw; SoftOMXPlugin then
# dlopen()s the codec in that same namespace. The plugin is vendor_available and
# therefore already present in /vendor/lib, but libstagefright_soft_xaacdec is
# not, so the top-level Android.mk copies the 32-bit codec into /vendor/lib as
# well. (The previous VNDK-lite reasoning -- "no sphal namespace, falls back to
# the default namespace which includes /system/lib" -- no longer applies; both
# ld.config.txt and ld.config.vndk_lite.txt in Android 10 define sphal, and it
# never includes /system/lib.)
#
# The soft codec inherits compile_multilib: "32" from
# libstagefright_softomx-defaults, matching the 32-bit vendor OMX service, and
# libxaacdec is linked statically into libstagefright_soft_xaacdec.
PRODUCT_PACKAGES += \
    libstagefright_softomx \
    libstagefright_softomx_plugin \
    libstagefright_soft_xaacdec

# AOSP's SoftOMXPlugin.cpp registers both OMX.google.aac.decoder
# (libstagefright_soft_aacdec) and OMX.google.xaac.decoder
# (libstagefright_soft_xaacdec) for the audio_decoder.aac role and leaves the
# choice to the vendor media_codecs_google_audio.xml. The device copy in
# configs/media/ names only the xaac node, which then serves the entire
# audio/mp4a-latm type, including the plain-AAC slot.
#
# media_codecs_google_video_le.xml is replaced with an empty <Included>: the
# platform plugin registers Google's software video component names too, but
# none of their libraries are built, and MediaTek's hardware OMX video codecs
# cover every format the stock file lists.
#
# PRODUCT_COPY_FILES keeps the first entry for a destination, so these copies
# must stay before the CPH1909-vendor.mk inherit at the bottom of this file.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/configs/media/media_codecs_google_audio.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_audio.xml \
    $(DEVICE_PATH)/configs/media/media_codecs_google_video_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_video_le.xml

# Default properties
#
# ro.mtkrc.path is read while parsing /vendor/etc/init/hw/init.mt6765.rc to
# expand its `import ${ro.mtkrc.path}init.*.rc` lines. Properties from
# prop.default are loaded before the boot scripts are parsed, so it has to be a
# default property, not one set later from an init action.
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.mtkrc.path=/vendor/etc/init/hw/

# Disable the stock ColorOS fingerprint HIDL services that the blob vendor
# makefile also installs. PRODUCT_COPY_FILES keeps the first entry for a
# destination, so these overrides must stay before the CPH1909-vendor.mk inherit
# below. They stop the stock vendor.oppo fingerprint (fps_hal) and fingerprintpay
# (fpay_hal) services from registering interfaces the Lineage framework does not
# use; fps_hal/fpay_hal would also contend with the AOSP fingerprint@2.1 service
# for /dev/silead_fp.
#
# The stock face service (face_hal) is NOT disabled: since commit d49bb8e its
# override rc dropped the `disabled` keyword and its DT_NEEDED interface
# libraries now ship (see proprietary-files.txt), because the source-built
# AOSP face@1.0 proxy in biometrics/face/ forwards to it as its backend.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/rootdir/etc/init/vendor.oppo.hardware.biometrics.face@1.0-service.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/vendor.oppo.hardware.biometrics.face@1.0-service.rc \
    $(DEVICE_PATH)/rootdir/etc/init/vendor.oppo.hardware.biometrics.fingerprint@2.1-service.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/vendor.oppo.hardware.biometrics.fingerprint@2.1-service.rc \
    $(DEVICE_PATH)/rootdir/etc/init/vendor.oppo.hardware.biometrics.fingerprintpay@1.0-service.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/vendor.oppo.hardware.biometrics.fingerprintpay@1.0-service.rc

# Generated by the proprietary-blob extraction step when vendor/oppo/CPH1909 is
# populated from the matching CPH1909 Android 8.1 firmware.
$(call inherit-product-if-exists, vendor/oppo/CPH1909/CPH1909-vendor.mk)
