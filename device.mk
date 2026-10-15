DEVICE_PATH := device/oppo/CPH1909
LOCAL_PATH := $(DEVICE_PATH)

# MTP helpers (same as proven CPH1920 reference: libmtp + mtp_server).
PRODUCT_PACKAGES += \
    libmtp \
    mtp_server

# Recovery ramdisk init scripts (TARGET_RECOVERY_FSTAB supplies twrp.fstab).
# ueventd.reserve.rc carries the stock opporeserve1 partition rules.
# vendor/ blobs (gatekeeper/keymaster services, mcRegistry, touch firmware,
# manifest) are copied from the J0shua CPH1909 reference into recovery ramdisk.
# sbin/ + system/ + vendor/lib64 crypto support libs come from the CPH1920
# MTP-fix reference (SQR11211, tag MTP-fix, cloned to /tmp/sqr_cph1920):
# hwservicemanager + binder/crypto/cutils/hidl/hwbinder/utils/vndksupport and
# gatekeeper/keymaster runtime libs.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/recovery/root/init.recovery.mt6765.rc:root/init.recovery.mt6765.rc \
    $(DEVICE_PATH)/recovery/root/init.recovery.usb.rc:root/init.recovery.usb.rc \
    $(DEVICE_PATH)/recovery/root/trustonic.rc:root/trustonic.rc \
    $(DEVICE_PATH)/recovery/root/ueventd.reserve.rc:root/ueventd.reserve.rc \
    $(DEVICE_PATH)/recovery/root/sbin/hwservicemanager:root/sbin/hwservicemanager \
    $(DEVICE_PATH)/recovery/root/vendor/manifest.xml:root/vendor/manifest.xml \
    $(DEVICE_PATH)/recovery/root/vendor/bin/mcDriverDaemon:root/vendor/bin/mcDriverDaemon \
    $(DEVICE_PATH)/recovery/root/vendor/bin/hw/android.hardware.gatekeeper@1.0-service:root/vendor/bin/hw/android.hardware.gatekeeper@1.0-service \
    $(DEVICE_PATH)/recovery/root/vendor/bin/hw/android.hardware.keymaster@3.0-service:root/vendor/bin/hw/android.hardware.keymaster@3.0-service \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/hw/android.hardware.gatekeeper@1.0-impl.so:root/vendor/lib64/hw/android.hardware.gatekeeper@1.0-impl.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/hw/gatekeeper.mt6765.so:root/vendor/lib64/hw/gatekeeper.mt6765.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/libgatekeeper.so:root/vendor/lib64/libgatekeeper.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/libion.so:root/vendor/lib64/libion.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/libkeymaster_messages.so:root/vendor/lib64/libkeymaster_messages.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/libkeymaster_portable.so:root/vendor/lib64/libkeymaster_portable.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/libsoftkeymasterdevice.so:root/vendor/lib64/libsoftkeymasterdevice.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/libbinder.so:root/system/lib64/libbinder.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/libcrypto.so:root/system/lib64/libcrypto.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/libcutils.so:root/system/lib64/libcutils.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/libhidlbase.so:root/system/lib64/libhidlbase.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/libhidltransport.so:root/system/lib64/libhidltransport.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/libhwbinder.so:root/system/lib64/libhwbinder.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/libutils.so:root/system/lib64/libutils.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/libvndksupport.so:root/system/lib64/libvndksupport.so \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/novatek_cost_fw.bin:root/vendor/firmware/novatek_cost_fw.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/novatek_cost_fw_mp.bin:root/vendor/firmware/novatek_cost_fw_mp.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/novatek_skyw_fw.bin:root/vendor/firmware/novatek_skyw_fw.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/novatek_skyw_fw_mp.bin:root/vendor/firmware/novatek_skyw_fw_mp.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/Himax_firmware.bin:root/vendor/firmware/Himax_firmware.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/Himax_firmware_sort.bin:root/vendor/firmware/Himax_firmware_sort.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/ILITEK_FW_HLT.bin:root/vendor/firmware/ILITEK_FW_HLT.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/ILITEK_FW_INX.bin:root/vendor/firmware/ILITEK_FW_INX.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/ILITEK_FW_LEAD_TF.bin:root/vendor/firmware/ILITEK_FW_LEAD_TF.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/ILITEK_FW_TXD.bin:root/vendor/firmware/ILITEK_FW_TXD.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/ILITEK_FW_TXD_TF.bin:root/vendor/firmware/ILITEK_FW_TXD_TF.bin \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/gt1151_default_firmware2.img:root/vendor/firmware/gt1151_default_firmware2.img

# Crypto / keymaster helpers needed by TWRP decryption live in vendor.
# Populate vendor/oppo/CPH1909 from the stock dump when available.
$(call inherit-product-if-exists, vendor/oppo/CPH1909/CPH1909-vendor.mk)


