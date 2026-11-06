#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),CPH1909)

# Keymaster / gatekeeper module aliases.
#
# Android's hw_get_module_by_class() looks for "<class>.<ro.hardware>.so" first
# (ro.hardware=mt6765, from androidboot.hardware) and only falls back to
# "<class>.default.so" afterwards. The vendor blobs ship the MediaTek TEE
# implementations under their own names -- libMcTeeKeymaster.so and
# libMcGatekeeper.so, with libSoftGatekeeper.so as the software fallback -- so
# the HAL loader cannot find them and both services start in their degraded
# software-only mode:
#
#   keymaster:  "Could not find any keystore module, using software-only
#                implementation."
#   gatekeeper: "Unable to open GateKeeper HAL"
#
# Install the names the loader expects as symlinks to the shipped modules.
#
# kmsetkey needs no alias here: ro.hardware.kmsetkey=trustonic (vendor.prop)
# makes the loader open the shipped kmsetkey.trustonic.so directly.

KEYSTORE_SYMLINK += $(TARGET_OUT_VENDOR)/lib/hw/keystore.mt6765.so
KEYSTORE_SYMLINK += $(TARGET_OUT_VENDOR)/lib64/hw/keystore.mt6765.so

$(KEYSTORE_SYMLINK): $(LOCAL_INSTALLED_MODULE)
	@mkdir -p $(dir $@)
	$(hide) ln -sf libMcTeeKeymaster.so $@

ALL_DEFAULT_INSTALLED_MODULES += $(KEYSTORE_SYMLINK)

GATEKEEPER_SYMLINK += $(TARGET_OUT_VENDOR)/lib/hw/gatekeeper.mt6765.so
GATEKEEPER_SYMLINK += $(TARGET_OUT_VENDOR)/lib64/hw/gatekeeper.mt6765.so

$(GATEKEEPER_SYMLINK): $(LOCAL_INSTALLED_MODULE)
	@mkdir -p $(dir $@)
	$(hide) ln -sf libMcGatekeeper.so $@

ALL_DEFAULT_INSTALLED_MODULES += $(GATEKEEPER_SYMLINK)

GATEKEEPER_DEFAULT_SYMLINK += $(TARGET_OUT_VENDOR)/lib/hw/gatekeeper.default.so
GATEKEEPER_DEFAULT_SYMLINK += $(TARGET_OUT_VENDOR)/lib64/hw/gatekeeper.default.so

$(GATEKEEPER_DEFAULT_SYMLINK): $(LOCAL_INSTALLED_MODULE)
	@mkdir -p $(dir $@)
	$(hide) ln -sf libSoftGatekeeper.so $@

ALL_DEFAULT_INSTALLED_MODULES += $(GATEKEEPER_DEFAULT_SYMLINK)

endif
