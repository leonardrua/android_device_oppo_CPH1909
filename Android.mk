#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),CPH1909)

# Keymaster / gatekeeper module aliases.
#
# The legacy HAL loader, hw_get_module_by_class(), probes candidates in this
# order:
#
#   1. ro.hardware.<class>  (class-specific override, when set)
#   2. ro.hardware, ro.product.board, ro.board.platform, ro.arch
#   3. "<class>.default.so"
#
# It looks for "<class>.<variant>.so" in /odm/lib[64]/hw, /vendor/lib[64]/hw
# and /system/lib[64]/hw. Here ro.hardware=mt6765 (from androidboot.hardware),
# so keymaster probes keystore.mt6765.so and gatekeeper probes
# gatekeeper.mt6765.so.
#
# The vendor blobs ship the MediaTek/Trustonic TEE implementations under their
# own names -- libMcTeeKeymaster.so, libMcGatekeeper.so and, for software
# gatekeeper, libSoftGatekeeper.so -- so nothing matches and:
#
#   keymaster:  logs "Could not find any keystore module, using software-only
#               implementation." and falls back to libsoftkeymasterdevice.so.
#   gatekeeper: logs "Unable to open GateKeeper HAL" from
#               LOG_ALWAYS_FATAL_IF; it has no software fallback and aborts.
#
# Install the names the loader expects as symlinks to the shipped modules.
# The blobs' HMI ids are already "keystore" and "gatekeeper", so the loader's
# id check passes.
#
# gatekeeper.default.so is only used when no variant candidate exists at all:
# hw_get_module_by_class() commits to the first candidate whose file is
# readable and does not retry .default if dlopen() or the module's open()
# fails. It is a safety net for a missing variant alias/blob, not a fallback
# for a TEE module that fails at runtime.
#
# kmsetkey needs no alias here: ro.hardware.kmsetkey=trustonic (vendor.prop)
# takes the class-specific branch above and opens the shipped
# kmsetkey.trustonic.so directly.

KEYSTORE_SYMLINK += $(TARGET_OUT_VENDOR)/lib/hw/keystore.mt6765.so
KEYSTORE_SYMLINK += $(TARGET_OUT_VENDOR)/lib64/hw/keystore.mt6765.so

$(KEYSTORE_SYMLINK):
	@mkdir -p $(dir $@)
	$(hide) ln -sf libMcTeeKeymaster.so $@

ALL_DEFAULT_INSTALLED_MODULES += $(KEYSTORE_SYMLINK)

GATEKEEPER_SYMLINK += $(TARGET_OUT_VENDOR)/lib/hw/gatekeeper.mt6765.so
GATEKEEPER_SYMLINK += $(TARGET_OUT_VENDOR)/lib64/hw/gatekeeper.mt6765.so

$(GATEKEEPER_SYMLINK):
	@mkdir -p $(dir $@)
	$(hide) ln -sf libMcGatekeeper.so $@

ALL_DEFAULT_INSTALLED_MODULES += $(GATEKEEPER_SYMLINK)

GATEKEEPER_DEFAULT_SYMLINK += $(TARGET_OUT_VENDOR)/lib/hw/gatekeeper.default.so
GATEKEEPER_DEFAULT_SYMLINK += $(TARGET_OUT_VENDOR)/lib64/hw/gatekeeper.default.so

$(GATEKEEPER_DEFAULT_SYMLINK):
	@mkdir -p $(dir $@)
	$(hide) ln -sf libSoftGatekeeper.so $@

ALL_DEFAULT_INSTALLED_MODULES += $(GATEKEEPER_DEFAULT_SYMLINK)

# Fingerprint module aliases.
#
# There is deliberately NO fingerprint.default.so alias.
#
# hw_get_module_by_class() probes in this order (hardware.c:variant_keys[]):
#
#   ro.hardware, ro.product.board, ro.board.platform, ro.arch, then "default"
#
# On this device ro.hardware=mt6765 (from androidboot.hardware=mt6765 in
# BOARD_KERNEL_CMDLINE) and ro.board.platform=mt6765, so the probe finds
# fingerprint.mt6765.so -- the shim built from biometrics/fingerprint/ and
# listed in PRODUCT_PACKAGES -- on the very first variant key and never
# reaches fingerprint.default.so. The alias was unreachable dead weight.
#
# It was also actively harmful: hardware/libhardware/modules/fingerprint/
# builds a real `fingerprint.default` module (cc_library_shared,
# proprietary: true, relative_install_path: "hw") that installs to the exact
# same vendor/lib[64]/hw/ path. Defining a second rule for that output made
# GNU make print
#     Android.mk:88: warning: overriding commands for target
#         .../vendor/lib/hw/fingerprint.default.so
#     build/make/core/base_rules.mk:510: warning: ignoring old commands ...
# and kept whichever rule it evaluated last instead of the one intended.
#
# gatekeeper.default.so below is different and is kept: gatekeeper has no
# mt6765 variant module, so its .default probe is reachable and the
# libSoftGatekeeper.so alias is the only thing that answers it.

include $(CLEAR_VARS)

# First-stage ramdisk fstab.
#
# The kernel DT no longer carries firmware/android/fstab, so Android 10 first
# stage init uses GetFstabPath(), which probes /odm/etc/fstab.<hw>,
# /vendor/etc/fstab.<hw> and /fstab.<hw>. Neither /odm nor /vendor is mounted
# that early, so the file has to live in the boot ramdisk at /fstab.mt6765.
# Adapted from xiaomi-lotus-devs commit dd70e2e ("lotus: Switch to 2SI").
LOCAL_MODULE := fstab.mt6765_ramdisk
LOCAL_MODULE_STEM := fstab.mt6765
LOCAL_SRC_FILES := rootdir/etc/fstab.mt6765
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_RAMDISK_OUT)
include $(BUILD_PREBUILT)

# Partition mount points inside the vendor partition.
#
# fstab.mt6765 mounts protect1, protect2, nvdata, nvcfg and persist on
# /vendor/protect_f, /vendor/protect_s, /vendor/nvdata, /vendor/nvcfg and
# /vendor/persist. The stock vendor image contains those directories, but this
# build assembles vendor/ from the extracted blobs, so they have to be created
# explicitly. init.mt6765.rc's `on init` block and fs_mgr's __mount() both
# mkdir() them, but init is not allowed to create directories under /vendor:
# vendor_file_type is excluded from the broad init rules in AOSP's init.te.
VENDOR_MOUNT_POINTS += $(TARGET_OUT_VENDOR)/protect_f
VENDOR_MOUNT_POINTS += $(TARGET_OUT_VENDOR)/protect_s
VENDOR_MOUNT_POINTS += $(TARGET_OUT_VENDOR)/nvdata
VENDOR_MOUNT_POINTS += $(TARGET_OUT_VENDOR)/nvcfg
VENDOR_MOUNT_POINTS += $(TARGET_OUT_VENDOR)/persist

$(VENDOR_MOUNT_POINTS):
	@mkdir -p $@

ALL_DEFAULT_INSTALLED_MODULES += $(VENDOR_MOUNT_POINTS)

endif
