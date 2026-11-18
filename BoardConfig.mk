#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/oppo/CPH1909

# Device profile
#
#   - A-only: one system/vendor slot, no slotselect in the fstab, no
#     AB_OTA_UPDATER and no A/B boot control.
#   - Non-system-as-root boot: the legacy boot image carries a ramdisk and
#     BOARD_BUILD_SYSTEM_ROOT_IMAGE is intentionally unset. Android 10 still
#     builds system.img in the system-as-root layout (root files are merged
#     into it), but first-stage init mounts that image at /system and pivots
#     the root to it.
#   - Legacy Treble: the vendor interface is O-MR1 (API 27, FCM level 2), so
#     manifest.xml declares target-level="2" and the build uses VNDK-lite.
#
# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a53

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a53

TARGET_USES_64_BIT_BINDER := true

# Bootloader / platform
TARGET_BOARD_PLATFORM := mt6765
TARGET_BOARD_PLATFORM_GPU := PowerVR-GE8320
TARGET_BOOTLOADER_BOARD_NAME := mt6765
BOARD_HAS_MTK_HARDWARE := true
BOARD_USES_MTK_HARDWARE := true
MTK_HARDWARE := true
TARGET_NO_BOOTLOADER := true
TARGET_NO_RADIOIMAGE := true

# Kernel
#
# The kernel is built from the checked-out source tree at kernel/oppo/CPH1909,
# not from a stock prebuilt payload. Keep the source and config explicit so the
# build compiles the OPPO/MediaTek 4.9 tree and the
# generated_kernel_includes step can run `make -C $(TARGET_KERNEL_SOURCE)
# headers_install` for generated_kernel_headers.
# TARGET_PREBUILT_KERNEL is deliberately never set here: the device tree carries
# no kernel image, and LineageOS clears TARGET_KERNEL_SOURCE when it is.
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb
TARGET_KERNEL_SOURCE := kernel/oppo/CPH1909
# The kernel build uses the A.46 firmware defconfig (a46_defconfig), matching
# the A.46 baseline the kernel/oppo/CPH1909 lineageos branch carries.
TARGET_KERNEL_CONFIG := a46_defconfig
TARGET_KERNEL_CLANG_COMPILE := false
TARGET_KERNEL_CROSS_COMPILE_PREFIX := $(abspath .)/prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05/bin/aarch64-linux-gnu-
TARGET_KERNEL_ADDITIONAL_FLAGS += ODM_WT_EDIT=yes

# Values decoded from the stock legacy boot image (header v0).
BOARD_KERNEL_BASE := 0x40078000
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x14f88000
BOARD_KERNEL_TAGS_OFFSET := 0x13f88000
BOARD_KERNEL_PAGESIZE := 2048

# androidboot.hardware=mt6765 gives us ro.hardware=mt6765. Second-stage init
# uses it to import the stock /vendor/etc/init/hw/init.mt6765.rc:
#   import /vendor/etc/init/hw/init.${ro.hardware}.rc
# Every MediaTek service and the mount_all for this device live in that file,
# and fs_mgr uses the same property to locate /vendor/etc/fstab.mt6765.
#
# First-stage mount does not depend on it here: init prefers the kernel DT
# fstab, which is present in mt6765.dts (see fstab.mt6765 for the full path).
# Without the property, however, second-stage init has no MediaTek services and
# the device boots to an empty init and hangs.
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 androidboot.hardware=mt6765

# If init fails fatally, reboot into recovery instead of hanging at the boot
# logo. This makes a broken bring-up (a HAL that never starts, for instance)
# recoverable and is the target the stock boot image uses.
BOARD_KERNEL_CMDLINE += androidboot.init_fatal_reboot_target=recovery

# BRING-UP ONLY -- remove before shipping. Initial bring-up builds run SELinux
# in permissive mode so early boot can get past policy/sepolicy gaps without a
# functional ROM. init reads androidboot.selinux from the kernel command line
# (StatusFromCmdline() in system/core/init/selinux.cpp) and switches the policy
# to permissive before any actions run, which also makes the permissive
# domains in sepolicy/vendor/device.te redundant. Only builds compiled with
# ALLOW_PERMISSIVE_SELINUX -- debuggable builds, i.e. userdebug/eng (the CI
# default is userdebug) -- honour this; user builds ignore it. Do not ship a
# release image with this line.
BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive

BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET)
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)
BOARD_MKBOOTIMG_ARGS += --header_version 0

# Partitions (bytes, from the supplied MT6765 eMMC scatter file)
BOARD_FLASH_BLOCK_SIZE := 131072
BOARD_BOOTIMAGE_PARTITION_SIZE := 33554432
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 67108864
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 4513071104
BOARD_VENDORIMAGE_PARTITION_SIZE := 1409286144
BOARD_ODMIMAGE_PARTITION_SIZE := 268435456
BOARD_CACHEIMAGE_PARTITION_SIZE := 268435456
BOARD_USERDATAIMAGE_PARTITION_SIZE := 3221225472

BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4

TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
TARGET_USES_MKE2FS := true
BOARD_HAS_LARGE_FILESYSTEM := true

# Separate /vendor and /odm partitions.
#
# build/make requires TARGET_COPY_OUT_VENDOR == vendor whenever
# BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE is set, and TARGET_COPY_OUT_ODM == odm
# whenever BOARD_ODMIMAGE_FILE_SYSTEM_TYPE is set; anything else is a hard error
# in core/board_config.mk.
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_ODM := odm

# Metadata partition: FDE key storage on this device.
BOARD_USES_METADATA_PARTITION := true

# Directories that must exist in the root of the system image so that
# second-stage init has somewhere to mount the extra MediaTek partitions
# listed in fstab.mt6765 (/opporeserve and friends live at the filesystem root,
# not under /vendor).
BOARD_ROOT_EXTRA_FOLDERS := opporeserve mnt/cd-rom custom

# The stock MTK init.mt6765.rc loaded the FPSGO companion module from
# /lib/modules/fpsgo.ko. Android 10's system image root has no /lib, and rather
# than add a legacy /lib -> /system/lib alias for a single insmod line, the
# vendor rc is pointed at the real path (/system/lib/modules/fpsgo.ko) where
# device.mk installs it. See the note in the vendor tree's init.mt6765.rc.
#
# /persist is a legacy alias for the `persist` partition, which the fstab
# mounts at /vendor/persist. The stock 8.1 init.mt6765.rc creates the alias at
# `on init` (symlink /vendor/persist /persist) and the stock blobs use the
# /persist/... spelling -- camera calibration (libcamwaist / westalgo),
# mcRegistry failure records and the silead fingerprint store. Android 10's
# rootdir does not create /persist, and unlike a directory it cannot be made
# with BOARD_ROOT_EXTRA_FOLDERS, so the root symlink is declared here. Format
# is <target>:<link_name>.
BOARD_ROOT_EXTRA_SYMLINKS := /vendor/persist:persist
#
# Encryption: the device ships FDE, backed by the Trustonic Kinibi TEE, not FBE.
# Android 10 still supports FDE for legacy devices. The fstab uses
# `encryptable=` (not the stock `forceencrypt=`) so an already-encrypted /data is
# decrypted through the metadata key while an unencrypted /data is mounted as-is
# instead of being force-encrypted on first boot. Nothing here enables FBE.

# Verified boot: the bootloader is locked to OPPO's keys and this build is not
# signed by them, so neither dm-verity nor AVB can be satisfied. This is a
# non-A/B device with no vbmeta partition.
BOARD_AVB_ENABLE := false

# Vendor security patch level
#
# The stock CPH1909 system build.prop reports
# ro.build.version.security_patch=2021-04-05 and the 8.1 vendor blobs it supplies
# are frozen at that level. Declaring it makes ro.vendor.build.security_patch
# report the truth instead of the AOSP default.
VENDOR_SECURITY_PATCH := 2021-04-05

# Display
TARGET_SCREEN_DENSITY := 320

# HIDL / VINTF
#
# This is a legacy-Treble device: the vendor interface is O-MR1 (FCM level 2),
# matching PRODUCT_SHIPPING_API_LEVEL=27. manifest.xml declares
# target-level="2", so the Android 10 framework validates the vendor HALs
# against the frozen O-MR1 framework compatibility matrix. That matrix will
# otherwise be selected at runtime from ro.product.first_api_level=27, and
# assemble_vintf infers the same level at build time when the attribute is
# missing, so declaring it explicitly is the honest description.
#
# The stock 8.1 compatibility_matrix.xml (the old vendor->framework device
# matrix) is deliberately not shipped: it was written for the 8.1 framework and
# would reject Android 10. Only the device manifest is supplied.
DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/manifest.xml
DEVICE_MATRIX_FILE := $(DEVICE_PATH)/compatibility_matrix.xml

# VNDK
#
# BOARD_VNDK_VERSION is deliberately left UNSET. PRODUCT_SHIPPING_API_LEVEL is
# 27, so PRODUCT_USE_VNDK stays false and the build does not default the
# variable to "current" (core/config.mk only does that for API 28+). This is
# the legacy-Treble VNDK-lite configuration, not VNDK enforcement.
#
# Setting BOARD_VNDK_VERSION would impose VNDK linkage rules on every vendor
# module built from source and is not needed for the prebuilt O-MR1 blobs.
#
# With the variable unset the build sets ro.vndk.lite=true and the linker uses
# ld.config.vndk_lite.txt. Its vendor namespace includes /system/${LIB} itself
# in addition to the vndk and vndk-sp subdirectories, so the 8.1 blobs resolve
# libhidltransport, libhwbinder, libgui, libpower, libmedia_helper and friends
# against the Android 10 system libraries. Those are VNDK forward-compatible
# with the API 27 libraries the blobs were linked against, which is exactly the
# guarantee the VNDK exists to provide.
#
# PRODUCT_EXTRA_VNDK_VERSIONS is not used: the v27 snapshot phony
# (vndk_snapshot_package) is only defined when BOARD_VNDK_VERSION is set
# (build/make/target/product/gsi/Android.mk), so declaring the extra version on
# this VNDK-lite build would install nothing. The vndk-lite namespace already
# exposes the current system libraries to the 8.1 blobs.

# Audio
USE_XML_AUDIO_POLICY_CONF := 1
AUDIOSERVER_MULTILIB := 32

# WiFi
#
# wpa_supplicant, hostapd and libwifi-hal.so are NOT built from source: the
# vendor tree already ships vendor/bin/hw/wpa_supplicant, vendor/bin/hostapd
# and vendor/lib64/libwifi-hal.so (the stock 8.1 binaries, built against the
# MTK driver). BOARD_WPA_SUPPLICANT_PRIVATE_LIB and BOARD_HOSTAPD_PRIVATE_LIB
# are left unset because their usual MTK value, lib_driver_cmd_mt66xx, has no
# source in this tree -- LineageOS's mt6735 device carries one as a prebuilt
# .a, this tree does not -- so naming it would point the supplicant build at
# a module that cannot be built.
#
# BOARD_WLAN_DEVICE is deliberately NOT set to MediaTek, which is what an MTK
# device would normally use. frameworks/opt/net/wifi/libwifi_hal/Android.mk:99
# turns that value into LIB_WIFI_HAL := libwifi-hal-mt66xx (line 101), and that
# static library has no source or prebuilt in this tree, so vendorimage died
# with
#   ninja: 'STATIC_LIBRARIES/libwifi-hal-mt66xx_intermediates/export_includes',
#   needed by '.../SHARED_LIBRARIES/libwifi-hal_intermediates/export_includes',
#   missing and no known rule to make it
#
# Leaving it unset selects LIB_WIFI_HAL := libwifi-hal-fallback (Android.mk:88),
# whose init_wifi_vendor_hal_func_table returns WIFI_ERROR_NOT_SUPPORTED
# (wifi_hal_fallback.cpp). That costs nothing here: the platform's libwifi-hal
# is only built if something depends on it, and nothing in this product does --
# the MTK combo is driven by the stock android.hardware.wifi@1.0-service, which
# resolves libwifi-hal.so by SONAME at runtime and gets the vendor blob
# (vendor/lib64/libwifi-hal.so), the one that exports
# android::wifi_system::HalTool::InitFunctionTable.
#
# The MTK combo chip is still driven through the WIFI_DRIVER_* values below and
# /dev/wmtWifi. None of those, nor WIFI_HIDL_FEATURE_DUAL_INTERFACE, is gated on
# BOARD_WLAN_DEVICE -- the only readers of that variable in this tree are the
# libwifi_hal switch and the qcom/bcm/wpa_supplicant blocks, none of which apply.
#
# WPA_SUPPLICANT_VERSION is deliberately unset as well. Setting it to VER_0_8_X
# makes external/wpa_supplicant_8/Android.mk:3-9 include
# wpa_supplicant/Android.mk, which builds a platform supplicant and installs it
# over the stock /vendor/bin/hw/wpa_supplicant. That build cannot link here:
# with BOARD_WPA_SUPPLICANT_DRIVER unset there is no CONFIG_DRIVER_NL80211, so
# src/drivers/drivers.mk:45 never sets NEED_AP_MLME, wpa_supplicant/Android.mk:
# 928-935 therefore omits src/ap/ieee802_11.c, and the CONFIG_AP/CONFIG_SAE/
# CONFIG_OWE objects enabled by android.config:473/540/546 reference
# auth_sae_process_commit, sae_clear_retransmit_timer and owe_assoc_req_process.
# The stock vendor binary is the one init.connectivity.rc starts and it is built
# against the MTK driver, so leave this variable unset.
WIFI_DRIVER_FW_PATH_PARAM := "/dev/wmtWifi"
WIFI_DRIVER_FW_PATH_STA := STA
WIFI_DRIVER_FW_PATH_AP := AP
WIFI_DRIVER_FW_PATH_P2P := P2P
WIFI_DRIVER_STATE_CTRL_PARAM := "/dev/wmtWifi"
WIFI_DRIVER_STATE_ON := "1"
WIFI_DRIVER_STATE_OFF := "0"
WIFI_HIDL_FEATURE_DUAL_INTERFACE := true

# Bluetooth
BOARD_HAVE_BLUETOOTH_MTK := true
BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR := $(DEVICE_PATH)/bluetooth

# Camera
TARGET_USES_MEDIA_EXTENSIONS := true

# Graphics / EGL (PowerVR GE8320)
USE_OPENGL_RENDERER := true
NUM_FRAMEBUFFER_SURFACE_BUFFERS := 3
TARGET_USES_HWC2 := true
BOARD_USES_GRALLOC1 := true
MTK_GRAPHICS_EXT := true

# DRM
TARGET_ENABLE_MEDIADRM_64 := true

# GPS
BOARD_USES_MTK_GPS := true

# RIL / Telephony
BOARD_HAS_MTK_RIL := true
ENABLE_VENDOR_RIL_SERVICE := true

# Recovery
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.mt6765
BOARD_SUPPRESS_SECURE_ERASE := true

# SELinux
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# LEFT UNSET ON PURPOSE -- this is the diagnostic mode. With the flag absent,
# checkpolicy -M and `sepolicy-analyze neverallow -w` run (Android.mk:375-384)
# and each violation is named with the exact rule and line, which is what makes
# the policy fixable. Setting it to true sets NEVERALLOW_ARG := -N (:85-93) and
# hands that to every secilc invocation (:535, :578, :628, :864, :979, :1293),
# so secilc's --disable-neverallow takes over and the assertions are simply not
# enforced -- the build passes, the violations go unreported, and the resulting
# policy can carry allow rules AOSP's assertions exist to prevent. It also drops
# sepolicy_tests and treble_sepolicy_tests_* from LOCAL_REQUIRED_MODULES
# (:242-248), so those CTS checks stop running too.
#
# So the trade is deliberate: unset costs a red build that names every offender,
# set costs a green build and a policy nobody can audit. Fix the rules the
# errors point at; only set this if a violation must be shipped temporarily,
# and then remove it once the rule is corrected.
#
# Note there is no Soong path for this on 17.1: core/soong_config.mk does not
# reference SelinuxIgnoreNeverallows and build/soong has only cil_compat_map.go
# and filegroup.go. The Makefile is the whole mechanism here.
#
# Hard error in user builds if ever set (Android.mk:86-88: "$(error ... cannot
# be used in user builds)"), so a release image cannot carry it even by
# accident. The CI default variant is userdebug, which would permit it.
#
# SELINUX_IGNORE_NEVERALLOWS := true

# Double tap to wake
#
# Himax summer / NT36525B / Ilitek ipio_mmi (OPPO multi-panel SPI touch, see the
# authoritative kernel DTS oppo6765_18511.dts: ili_ts@0 on spi3) expose the OPPO
# touchpanel proc node below. android.hardware.power@1.0-service forwards the
# framework POWER_FEATURE_DOUBLE_TAP_TO_WAKE feature to power.mt6765, which
# writes this node. The setting is surfaced by config_supportDoubleTapWake.
# The node is labelled proc_dt2w by sepolicy/vendor/genfs_contexts and is
# writable by hal_power_default (the AOSP power service's domain), so DT2W
# works with SELinux enforcing, not just during the permissive bring-up.
TARGET_TAP_TO_WAKE_NODE := /proc/touchpanel/double_tap_enable

# Properties
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop

# Build
#
# The vendor blob set and AOSP both install a number of the same paths (the 8.1
# HAL services that AOSP 10 replaces, for instance). The blob wins Make's parse
# order, which is what we want for the MediaTek-specific binaries, so allow the
# duplicate rules instead of chasing each one.
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_PREBUILT_ELF_FILES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_USES_BUILD_COPY_HEADERS := true
BUILD_BROKEN_ENFORCE_SYSPROP_OWNER := true

# Put PRODUCT_DEFAULT_PROPERTY_OVERRIDES (including ro.mtkrc.path) in
# /vendor/default.prop. init's property_load_boot_defaults() reads that file
# unconditionally, before it parses the boot scripts, which is exactly when the
# ${ro.mtkrc.path} imports in init.mt6765.rc have to resolve.
BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true

# Assert
TARGET_OTA_ASSERT_DEVICE := CPH1909
