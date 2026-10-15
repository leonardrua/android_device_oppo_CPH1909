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
# = gzip Image + single 92534-byte mt6765 base DTB trailer (measured on both
# the J0shua prebuilt and the A.46 dump kernel). The board overlay
# (oppo6765_18511) is merged at boot by LK from the odmdtbo partition — its
# overlay build toggle is off in the defconfig; twrp.fstab carries /odmdtbo.
# Device kernels are "4.9.77+" built with Linaro GCC 6.3.1 (J0shua prebuilt,
# dump A.46); this source's Makefile is at 4.9.80 (same tree, minor bump).
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
PLATFORM_VERSION := 8.1.0

# Values decoded from the stock recovery.img header (header v0, pagesize 2048)
# and confirmed identical in the ROM dump boot.img (tmp/cph1909-rom-dump,
# CPH1909EX_11.A.46: base 0x40078000, offsets, cmdline all match).
# Stock cmdline carries only bootopt + buildvariant (verified: no usbconfig).
BOARD_KERNEL_BASE := 0x40078000
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x14f88000
BOARD_KERNEL_TAGS_OFFSET := 0x13f88000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 buildvariant=user
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)

# Kernel - prebuilt
# J0shua reference ships prebuilt/Image.gz-dtb (9.3M, stock-derived);
# copied here as prebuilt/kernel and enabled by default like his tree.
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

# Decryption: stock /data is forceencrypt (FDE) with the metadata partition.
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_FBE := false
TW_INCLUDE_FBE_METADATA_DECRYPT := false
BOARD_USES_METADATA_PARTITION := true

# Reboot menu (CPH1920 reference disables bootloader reboot on this platform).
TW_HAS_DOWNLOAD_MODE := false
TW_NO_REBOOT_BOOTLOADER := true

