DEVICE_PATH := device/oppo/CPH1909

# Allow building without populating vendor/ (recovery-only bring-up).
ALLOW_MISSING_DEPENDENCIES := true

PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xxhdpi

# Recovery ramdisk init scripts (TARGET_RECOVERY_FSTAB supplies twrp.fstab).
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/recovery/root/init.recovery.mt6765.rc:root/init.recovery.mt6765.rc \
    $(DEVICE_PATH)/recovery/root/init.recovery.usb.rc:root/init.recovery.usb.rc \
    $(DEVICE_PATH)/recovery/root/trustonic.rc:root/trustonic.rc

# Crypto / keymaster helpers needed by TWRP decryption live in vendor.
# Populate vendor/oppo/CPH1909 from the stock dump when available.
$(call inherit-product-if-exists, vendor/oppo/CPH1909/CPH1909-vendor.mk)


