DEVICE_PATH := device/oppo/CPH1909

TARGET_BOARD_PLATFORM := mt6765
TARGET_BOOTLOADER_BOARD_NAME := MT6765
TARGET_NO_BOOTLOADER := true
TARGET_NO_RADIOIMAGE := true

# Recovery-only bring-up: allow building without a populated vendor/ tree.
ALLOW_MISSING_DEPENDENCIES := true

TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := generic

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv7-a-neon
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := generic

# These two are for MTK chipsets only.
BOARD_USES_MTK_HARDWARE := true
BOARD_HAS_MTK_HARDWARE := true

# APEX
OVERRIDE_TARGET_FLATTEN_APEX := true

# Kernel source reference: https://github.com/yeojhenrie/A5S-8.1-kernel-source
# (cloned to /tmp/a5s_kernel). Verified: arch/arm64/configs/oppo6765_18511_defconfig
# and arch/arm64/boot/dts/mediatek/oppo6765_18511.dts exist; defconfig sets
# CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE=y with mediatek/mt6765, so Image.gz-dtb
# = gzip Image + single 92534-byte mt6765 base DTB trailer (measured on the
# prebuilt kernel; identical to the A.46 dump kernel). The board overlay
# (oppo6765_18511) is merged at boot by LK from the odmdtbo partition — its
# overlay build toggle is off in the defconfig; twrp.fstab carries /odmdtbo.
# Device kernel is "4.9.77+" built with Linaro GCC 6.3.1 (2021-03-19, the
# same image as dump A.46); this source's Makefile is at 4.9.80 (same tree,
# minor bump).
# Touch drivers in the defconfig: ILI9881H, NT36xxx (novatek) host-dl SPI,
# Himax HX83112, FT8006P — matching the vendored firmware set.
TARGET_KERNEL_SOURCE := kernel/oppo/CPH1909
TARGET_KERNEL_CONFIG := oppo6765_18511_defconfig
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb

# Display (same panel family as CPH1920 reference: 720x1520, density 480).
TARGET_SCREEN_DENSITY := 480

# Recovery image configuration
TARGET_NO_KERNEL := false
TARGET_NO_RECOVERY := false
# build/core/config.mk: PRODUCT_SHIPPING_API_LEVEL >= 27 (Android 8.1)
# requires mke2fs (e2fsprogs) for ext4 image tooling instead of make_ext4fs.
TARGET_USES_MKE2FS := true
BOARD_BUILD_SYSTEM_ROOT_IMAGE := false
BOARD_USES_RECOVERY_AS_BOOT := false
AB_OTA_UPDATER := false
BOARD_HAS_LARGE_FILESYSTEM := true
BOARD_HAS_NO_SELECT_BUTTON := true
BOARD_SUPPRESS_SECURE_ERASE := true
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
RECOVERY_VARIANT := twrp

# Stock security patch from recovery prop.default (anti-rollback dodge kept).
VENDOR_SECURITY_PATCH := 2020-10-05
PLATFORM_SECURITY_PATCH := 2099-12-31
# Pinned platform version. PLATFORM_VERSION only feeds
# ro.build.version.release -- it does NOT set PLATFORM_SDK_VERSION, which comes
# from the platform branch in the manifest. That SDK level is what gates the
# TWRP crypto paths (FDE at >= 24, FBE metadata decrypt at >= 28) and the
# mke2fs image tooling (shipping API >= 27), so the manifest branch is the real
# pin: twrp-8.1 -> SDK 27. Keep this value in agreement with that branch for
# ro.build.version.release and OTA asserts; CI cross-checks the two. (The J0shua
# reference pins PLATFORM_VERSION := 16.1.0 and still compiles at SDK 27, which
# is the proof that these are independent.)
PLATFORM_VERSION := 8.1.0

# Values decoded from the stock recovery.img header (header v0, pagesize 2048)
# and confirmed identical in the ROM dump boot.img (tmp/cph1909-rom-dump,
# CPH1909EX_11.A.46: base 0x40078000, offsets, cmdline all match).
# Stock cmdline carries only bootopt + buildvariant (verified: no usbconfig).
# buildvariant is NOT included here: the build system appends
# buildvariant=$(TARGET_BUILD_VARIANT) at mkbootimg time, and keeping the
# stock buildvariant=user too produced a duplicated pair on the image
# (buildvariant=user buildvariant=eng).
BOARD_KERNEL_BASE := 0x40078000
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x14f88000
BOARD_KERNEL_TAGS_OFFSET := 0x13f88000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)

# Kernel - prebuilt
# Kernel extracted from the working TWRP 3.7.0_9-1 recovery for this device
# (tmp/oppo_a5s_twrp1_kernel.zip): kernel.gz is the complete Image.gz-dtb
# (9979567 = gzip Image + 92534-byte mt6765 DTB), byte-identical to the
# A.46 dump boot kernel (Linux 4.9.77+, built 2021-03-19; config identical
# to stock recovery per the zip's INFO.txt).
TARGET_FORCE_PREBUILT_KERNEL := true
ifeq ($(TARGET_FORCE_PREBUILT_KERNEL),true)
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_KERNEL_SEPARATED_DTBO :=
endif

# Sizes from the supplied MT6765 EMMC scatter file; values are bytes.
# Recovery-only: only boot/recovery sizes are needed to build the image.
BOARD_FLASH_BLOCK_SIZE := 131072
BOARD_BOOTIMAGE_PARTITION_SIZE := 33554432
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 67108864

# Separate /vendor partition (as in twrp.fstab). Lets the build system
# create proper root/vendor directory rules in the recovery ramdisk
# (fixes ninja mkdir ENOENT on root/vendor/app); does not force a
# vendor.img build for the recoveryimage target.
BOARD_USES_VENDORIMAGE := true
TARGET_COPY_OUT_VENDOR := vendor

TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Recovery uses the TWRP mount table directly.
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/etc/twrp.fstab

# Team Win Recovery Project settings
RECOVERY_SDCARD_ON_DATA := true
TARGET_OTA_ASSERT_DEVICE := CPH1909
TW_THEME := portrait_hdpi
TW_EXTRA_LANGUAGES := true
TW_SCREEN_BLANK_ON_BOOT := true
TW_INPUT_BLACKLIST := "hbtp_vm"
TW_USE_TOOLBOX := true
# ConfigFS-based USB with FunctionFS MTP (CPH1920 MTP fix).
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_NO_USB_STORAGE := false
TARGET_USE_CUSTOM_LUN_FILE_PATH := /config/usb_gadget/g1/functions/mass_storage.0/lun.%d/file
TW_EXTERNAL_STORAGE_PATH := /external_sd
TW_USB_STORAGE_PATH := /usb_otg
TW_INCLUDE_NTFS_3G := true
TW_INCLUDE_FUSE_EXFAT := true
TW_Y_OFFSET := 50
TW_H_OFFSET := -50
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true

# Decryption: stock /data is forceencrypt (FDE) against the metadata partition
# (confirmed in the stock recovery.fstab and the A.46 vendor/etc/fstab.mt6765).
#
# On the pinned twrp-8.1 manifest PLATFORM_SDK_VERSION is 27, so TWRP's
# recovery/Android.mk compiles:
#   TW_INCLUDE_CRYPTO -> FDE path (crypto/fde + crypto/scrypt, libcryptfsfde)
#   TW_INCLUDE_CRYPTO_FBE -> force-enabled for SDK >= 24 (-DTW_INCLUDE_FBE,
#                        links libe4crypt)
#   TW_INCLUDE_FBE_METADATA_DECRYPT -> NOT set (needs SDK >= 28)
# There is no TW_INCLUDE_FBE variable in TWRP 3.x, and neither FBE flag can
# be turned off from BoardConfig -- both are gated on the SDK version alone.
# So this device gets working FDE decrypt plus FBE-without-metadata-decrypt;
# do not try to disable FBE by setting a variable here.
TW_INCLUDE_CRYPTO := true
BOARD_USES_METADATA_PARTITION := true

# EXPERIMENT: hand decryption to the device's own vold.
#
# TWRP's own FDE path is built (crypto/fde) but has never been shown to decrypt
# on this device; the only public report for the A5s (XDA, "Oppo A5S (CPH1909)
# Custom recovery and device Tree") is that decryption does not work. This knob
# makes TWRP mount /system and let the OEM Oreo vold do the work, which is the
# documented fallback for proprietary OEM crypto.
#
# TWRP picks the services by prefix in vold_decrypt.cpp: sys_* for /system
# binaries, ven_* for /vendor ones. TWRP ships defaults for keymaster-3-0 and
# hwservicemanager; mobicore is supplied by this tree because the OEM keymaster
# lives in the Trustonic TEE. All three need a matching .rc: the first two come
# from TWRP, the third from recovery/root/.
#
# Also required, and provided by this tree:
#   recovery/root/fstab.mt6765 -- vold/fs_mgr cannot parse the v2 twrp.fstab, so
#   TWRP points /etc/recovery.fstab at /fstab.${ro.hardware} while vold runs.
#
# gatekeeper-1-0 is deliberately left out: TWRP only enables a listed service if
# a matching sys_*/ven_* definition exists, and there is no default rc for it.
# TWRP stops and restarts its own recovery-domain keymaster-3-0 and
# hwservicemanager around vold_decrypt, so nothing conflicts.
#
# To revert: comment out the line below and drop the two PRODUCT_COPY_FILES
# entries for fstab.mt6765 and init.recovery.vold_decrypt.mobicore.rc.
TW_CRYPTO_USE_SYSTEM_VOLD := keymaster-3-0 hwservicemanager mobicore

# Reboot menu (CPH1920 reference disables bootloader reboot on this platform).
TW_HAS_DOWNLOAD_MODE := false
TW_NO_REBOOT_BOOTLOADER := true

