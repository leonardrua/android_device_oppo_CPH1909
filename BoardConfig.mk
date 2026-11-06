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
# The kernel tree lives outside this repository at kernel/oppo/CPH1909 and is a
# 4.9 MediaTek kernel with OPPO VENDOR_EDIT patches, so it is built with GCC 4.9
# rather than clang.
TARGET_KERNEL_SOURCE := kernel/oppo/CPH1909
TARGET_KERNEL_CONFIG := oppo6765_18511_defconfig
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_KERNEL_CLANG_COMPILE := false
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb

# Values decoded from rom-dump/boot.img (legacy boot image, header v0).
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
BOARD_ROOT_EXTRA_FOLDERS := opporeserve

# Encryption: the device ships FDE, backed by the Trustonic Kinibi TEE, not FBE.
# Android 10 still supports FDE for legacy devices. The fstab uses
# `encryptable=` (not the stock `forceencrypt=`) so an already-encrypted /data is
# decrypted through the metadata key while an unencrypted /data is mounted as-is
# instead of being force-encrypted on first boot. Nothing here enables FBE.

# Verified boot: the bootloader is locked to OPPO's keys and this build is not
# signed by them, so neither dm-verity nor AVB can be satisfied. This is a
# non-A/B device with no vbmeta partition.
BOARD_AVB_ENABLE := false

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

# GPS
BOARD_USES_MTK_GPS := true

# RIL / Telephony
BOARD_HAS_MTK_RIL := true
ENABLE_VENDOR_RIL_SERVICE := true

# Recovery
TARGET_RECOVERY_PIXEL_FORMAT := "RGBX_8888"
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.mt6765
BOARD_SUPPRESS_SECURE_ERASE := true

# SELinux
BOARD_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

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

# Put PRODUCT_DEFAULT_PROPERTY_OVERRIDES (including ro.mtkrc.path) in
# /vendor/default.prop. init's property_load_boot_defaults() reads that file
# unconditionally, before it parses the boot scripts, which is exactly when the
# ${ro.mtkrc.path} imports in init.mt6765.rc have to resolve.
BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true

# Assert
TARGET_OTA_ASSERT_DEVICE := CPH1909
