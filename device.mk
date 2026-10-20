DEVICE_PATH := device/oppo/CPH1909
LOCAL_PATH := $(DEVICE_PATH)

# No device-tree MTP packages: TWRP's own recovery tree builds its MTP
# module in-tree and adds it to the ramdisk itself. Which one it is depends
# on PLATFORM_SDK_VERSION, not on the recovery tree's branch: SDK 28 and above
# links libtwrpmtp-ffs (FunctionFS), lower levels link libtwrpmtp-legacy. The
# legacy AOSP libmtp + mtp_server modules are stripped from the pinned minimal
# twrp-9.0 manifest (remove-minimal.xml removes platform/external/libmtp
# and platform/external/mtpd, and external/mtp is never included), so
# naming them here fails the build. The CPH1920 reference needed them on
# older TWRP; this tree does not.

# Recovery ramdisk init scripts (TARGET_RECOVERY_FSTAB supplies twrp.fstab).
# ueventd.reserve.rc carries the stock opporeserve1 partition rules.
# etc/mke2fs.conf is the stock AOSP mke2fs configuration, read when TWRP
# formats an ext4 filesystem on the device; without it mke2fs uses its own
# compiled-in defaults, which do not match the stock image feature set.
# vendor/ blobs (gatekeeper/keymaster services, mcRegistry, touch firmware,
# manifest) are copied from the J0shua CPH1909 reference into recovery ramdisk.
# sbin/ + system/ + vendor/lib64 crypto support libs come from the CPH1920
# MTP-fix reference (SQR11211, tag MTP-fix, cloned to /tmp/sqr_cph1920):
# hwservicemanager + binder/crypto/cutils/hidl/hwbinder/utils/vndksupport and
# gatekeeper/keymaster runtime libs.
#
# The root/system/lib64 + root/sbin entries are ADDITIVE, not a replacement
# of platform output: TWRP's recovery tree installs its own modules into
# root/sbin (LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/sbin in both
# its android-8.1 and android-9.0 Android.mk), which is why the proven ramdisk
# keeps ~90 libs in /sbin and has no /system/lib64 at all. These copies give the
# keymaster/gatekeeper/hwservicemanager stack an explicit Oreo-vintage runtime
# (all 8 libs verified byte-identical to the A.46 ROM dump) instead of leaving
# it to whatever the platform emits for the SDK. Note init.recovery.mt6765.rc
# puts /sbin ahead of /system/lib64 in LD_LIBRARY_PATH, so a matching library
# in /sbin is preferred over the copy here.
# Do not add 32-bit (lib/) counterparts -- the recovery userspace built from
# this tree is arm64-only, and an unpaired lib/ dir would just bloat the image.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/recovery/root/init.recovery.mt6765.rc:root/init.recovery.mt6765.rc \
    $(DEVICE_PATH)/recovery/root/init.recovery.usb.rc:root/init.recovery.usb.rc \
    $(DEVICE_PATH)/recovery/root/trustonic.rc:root/trustonic.rc \
    $(DEVICE_PATH)/recovery/root/ueventd.reserve.rc:root/ueventd.reserve.rc \
    $(DEVICE_PATH)/recovery/root/etc/mke2fs.conf:root/etc/mke2fs.conf \
    $(DEVICE_PATH)/recovery/root/sbin/hwservicemanager:root/sbin/hwservicemanager \
    $(DEVICE_PATH)/recovery/root/vendor/manifest.xml:root/vendor/manifest.xml \
    $(DEVICE_PATH)/recovery/root/vendor/bin/mcDriverDaemon:root/vendor/bin/mcDriverDaemon \
    $(DEVICE_PATH)/recovery/root/vendor/bin/hw/android.hardware.gatekeeper@1.0-service:root/vendor/bin/hw/android.hardware.gatekeeper@1.0-service \
    $(DEVICE_PATH)/recovery/root/vendor/bin/hw/android.hardware.keymaster@3.0-service:root/vendor/bin/hw/android.hardware.keymaster@3.0-service \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/hw/android.hardware.gatekeeper@1.0-impl.so:root/vendor/lib64/hw/android.hardware.gatekeeper@1.0-impl.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/hw/android.hardware.keymaster@3.0-impl.so:root/vendor/lib64/hw/android.hardware.keymaster@3.0-impl.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/hw/libMcTeeKeymaster.so:root/vendor/lib64/hw/libMcTeeKeymaster.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/hw/kmsetkey.trustonic.so:root/vendor/lib64/hw/kmsetkey.trustonic.so \
    $(DEVICE_PATH)/recovery/root/vendor/bin/kmsetkey_ca.trustonic:root/vendor/bin/kmsetkey_ca.trustonic \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/hw/gatekeeper.mt6765.so:root/vendor/lib64/hw/gatekeeper.mt6765.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/hw/vendor.mediatek.hardware.keymaster_attestation@1.1-impl.so:root/vendor/lib64/hw/vendor.mediatek.hardware.keymaster_attestation@1.1-impl.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/vendor.mediatek.hardware.keymaster_attestation@1.0_vendor.so:root/vendor/lib64/vendor.mediatek.hardware.keymaster_attestation@1.0_vendor.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/vendor.mediatek.hardware.keymaster_attestation@1.1_vendor.so:root/vendor/lib64/vendor.mediatek.hardware.keymaster_attestation@1.1_vendor.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/vendor.oppo.hardware.cryptoeng@1.0_vendor.so:root/vendor/lib64/vendor.oppo.hardware.cryptoeng@1.0_vendor.so \
    $(DEVICE_PATH)/recovery/root/vendor/bin/hw/vendor.mediatek.hardware.keymaster_attestation@1.1-service:root/vendor/bin/hw/vendor.mediatek.hardware.keymaster_attestation@1.1-service \
    $(DEVICE_PATH)/recovery/root/vendor/bin/hw/vendor.oppo.hardware.cryptoeng@1.0-service:root/vendor/bin/hw/vendor.oppo.hardware.cryptoeng@1.0-service \
    $(DEVICE_PATH)/recovery/root/system/lib64/libkmsetkey.so:root/system/lib64/libkmsetkey.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/vendor.mediatek.hardware.keymaster_attestation@1.0.so:root/system/lib64/vendor.mediatek.hardware.keymaster_attestation@1.0.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/vendor.mediatek.hardware.keymaster_attestation@1.1.so:root/system/lib64/vendor.mediatek.hardware.keymaster_attestation@1.1.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/vendor.oppo.hardware.cryptoeng@1.0.so:root/system/lib64/vendor.oppo.hardware.cryptoeng@1.0.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/libgatekeeper.so:root/vendor/lib64/libgatekeeper.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/libion.so:root/vendor/lib64/libion.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/libkeymaster_messages.so:root/vendor/lib64/libkeymaster_messages.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/libkeymaster_portable.so:root/vendor/lib64/libkeymaster_portable.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/libsoftkeymasterdevice.so:root/vendor/lib64/libsoftkeymasterdevice.so \
    $(DEVICE_PATH)/recovery/root/vendor/lib64/libMcClient.so:root/vendor/lib64/libMcClient.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/libbinder.so:root/system/lib64/libbinder.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/libcrypto.so:root/system/lib64/libcrypto.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/libcutils.so:root/system/lib64/libcutils.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/libhidlbase.so:root/system/lib64/libhidlbase.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/libhidltransport.so:root/system/lib64/libhidltransport.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/libhwbinder.so:root/system/lib64/libhwbinder.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/libkeymaster_staging.so:root/system/lib64/libkeymaster_staging.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/libutils.so:root/system/lib64/libutils.so \
    $(DEVICE_PATH)/recovery/root/system/lib64/libvndksupport.so:root/system/lib64/libvndksupport.so \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/020f0000000000000000000000000000.drbin:root/vendor/app/mcRegistry/020f0000000000000000000000000000.drbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/020f0000000000000000000000000000.tlbin:root/vendor/app/mcRegistry/020f0000000000000000000000000000.tlbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/030b0000000000000000000000000000.drbin:root/vendor/app/mcRegistry/030b0000000000000000000000000000.drbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/030b0000000000000000000000000000.tlbin:root/vendor/app/mcRegistry/030b0000000000000000000000000000.tlbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/030d0000000000000000000000000000.drbin:root/vendor/app/mcRegistry/030d0000000000000000000000000000.drbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/030d0000000000000000000000000000.tlbin:root/vendor/app/mcRegistry/030d0000000000000000000000000000.tlbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/04320000000000000000000000000000.tlbin:root/vendor/app/mcRegistry/04320000000000000000000000000000.tlbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/05060000000000000000000000000000.tabin:root/vendor/app/mcRegistry/05060000000000000000000000000000.tabin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/05070000000000000000000000000000.drbin:root/vendor/app/mcRegistry/05070000000000000000000000000000.drbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/05070000000000000000000000000000.tlbin:root/vendor/app/mcRegistry/05070000000000000000000000000000.tlbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/05110000000000000000000000000000.tabin:root/vendor/app/mcRegistry/05110000000000000000000000000000.tabin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/05120000000000000000000000000000.drbin:root/vendor/app/mcRegistry/05120000000000000000000000000000.drbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/05120000000000000000000000000000.tlbin:root/vendor/app/mcRegistry/05120000000000000000000000000000.tlbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/07010000000000000000000000000000.tlbin:root/vendor/app/mcRegistry/07010000000000000000000000000000.tlbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/0706000000000000000000000000004d.tlbin:root/vendor/app/mcRegistry/0706000000000000000000000000004d.tlbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/07061000000000000000000000000000.tlbin:root/vendor/app/mcRegistry/07061000000000000000000000000000.tlbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/070f0000000000000000000000000a0a.tlbin:root/vendor/app/mcRegistry/070f0000000000000000000000000a0a.tlbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/07150000000000000000000000000000.drbin:root/vendor/app/mcRegistry/07150000000000000000000000000000.drbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/07150000000000000000000000000000.tlbin:root/vendor/app/mcRegistry/07150000000000000000000000000000.tlbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/07170000000000000000000000000000.drbin:root/vendor/app/mcRegistry/07170000000000000000000000000000.drbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/07170000000000000000000000000000.tlbin:root/vendor/app/mcRegistry/07170000000000000000000000000000.tlbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/08010203000000000000000000000000.tabin:root/vendor/app/mcRegistry/08010203000000000000000000000000.tabin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/08030000000000000000000000000000.tabin:root/vendor/app/mcRegistry/08030000000000000000000000000000.tabin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/08080000000000000000000000000000.tlbin:root/vendor/app/mcRegistry/08080000000000000000000000000000.tlbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/09070000000000000000000000000000.drbin:root/vendor/app/mcRegistry/09070000000000000000000000000000.drbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/09070000000000000000000000000000.tlbin:root/vendor/app/mcRegistry/09070000000000000000000000000000.tlbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/09080000000000000000000000000000.tlbin:root/vendor/app/mcRegistry/09080000000000000000000000000000.tlbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/09080000000000000000000000000001.tlbin:root/vendor/app/mcRegistry/09080000000000000000000000000001.tlbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/09190000000000000000000000000000.tlbin:root/vendor/app/mcRegistry/09190000000000000000000000000000.tlbin \
    $(DEVICE_PATH)/recovery/root/vendor/app/mcRegistry/511ead0a000000000000000000000000.tabin:root/vendor/app/mcRegistry/511ead0a000000000000000000000000.tabin \
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


