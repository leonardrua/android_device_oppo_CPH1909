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

endif
