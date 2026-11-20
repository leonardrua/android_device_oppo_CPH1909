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

# libgui.so symlink into /vendor
#
# hwcomposer.mt6765.so and other 8.1 HALs DT_NEEDED libgui.so, which the vendor
# namespace does not provide. Point /vendor/lib{,64}/libgui.so at the
# source-built libgui_vendor.so (PRODUCT_PACKAGES in device.mk). Adapted from
# xiaomi-lotus-devs commit dd5519c.
LIBGUI_SYMLINK += $(TARGET_OUT_VENDOR)/lib/libgui.so
LIBGUI_SYMLINK += $(TARGET_OUT_VENDOR)/lib64/libgui.so
$(LIBGUI_SYMLINK): $(LOCAL_INSTALLED_MODULE)
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide) ln -sf libgui_vendor.so $@
ALL_DEFAULT_INSTALLED_MODULES += $(LIBGUI_SYMLINK)

# Vendor-side core-only libs
#
# Several 8.1 vendor blobs DT_NEEDED core-only libs that LOS 17.1 builds
# into /system/lib{,64} (no vendor_available/vndk). The Android 10 vendor
# namespace (isolated, search /odm/${LIB}:/vendor/${LIB}, links
# %LLNDK_LIBRARIES% + %VNDK_*) cannot load them from /system. Ship copies
# in /vendor/lib{,64} so the vendor blobs resolve.
#
# These are all cc_library_shared in LOS 17.1 with no vendor_available,
# vndk.enabled, or vendor: true, and no _vendor variant. Affected blobs:
#   libmedia.so           <- audio.usb.mt6765.so, sound_trigger.primary.mt6765.so, libabfadp.so
#   libcamera_client.so   <- libCustomFeature.so, libcam.hal3a.cctsvr.so, libmtkcam_cct.so
#   libaudioclient.so     <- sound_trigger.primary.mt6765.so
#   libnetd_client.so     <- bin/volte_stack
#   liblogwrap.so         <- bin/ipsec_mon, libmtk-ril.so
#   libsensor.so          <- libFactoryHALSensor.so
#   libhwui.so            <- libhwuiext.so
#   libpixelflinger.so    <- libccap.so
#   libandroid_runtime.so <- libapplypatch_jni.so, libcoloros_sau_applypatch.so, libem_camera_jni.so
#   libandroid_net.so     <- bin/mtk_agpsd
#   libkeystore_binder.so <- bin/hw/vendor.oppo.hardware.biometrics.face@1.0-service, libwapi.so
#   libnativehelper.so    <- libem_camera_jni.so, libwapi_cert.so
#   libprogrambinary.so   <- libhwuiext.so (MTK HWUI program-binary cache)
#   libaed.so             <- libhwuiext.so (MTK exception debug)
#   vendor.mediatek.hardware.camera.device@1.1.so <- libmtkcam_cct.so
#   vendor.qti.hardware.soter@1.0.so <- vendor.trustonic.soter@1.0-service
#
# libskia is NOT in this list: LOS 17.1 builds it as cc_library_static
# (no .so), so the stock 8.1 libskia.so is shipped separately below.
VENDOR_CORE_LIBS := \
	libmedia.so \
	libcamera_client.so \
	libaudioclient.so \
	libnetd_client.so \
	liblogwrap.so \
	libsensor.so \
	libhwui.so \
	libpixelflinger.so \
	libandroid_runtime.so \
	libandroid_net.so \
	libkeystore_binder.so \
	libnativehelper.so \
	libprogrambinary.so \
	libaed.so \
	vendor.mediatek.hardware.camera.device@1.1.so \
	vendor.qti.hardware.soter@1.0.so

VENDOR_CORE_LIB_COPIES :=
$(foreach lib,$(VENDOR_CORE_LIBS),\
	$(eval VENDOR_CORE_LIB_COPIES += \
		$(TARGET_OUT_VENDOR)/lib/$(lib) \
		$(TARGET_OUT_VENDOR)/lib64/$(lib)))

# Generate explicit copy rules: each /vendor/lib{,64}/<lib> depends on
# /system/lib{,64}/<lib> (built by Soong as part of the LOS 17.1 build).
# Use a define with real newlines: backslash continuations inside $(eval)
# collapse to spaces and would merge the recipe into the dependency line
# (making @mkdir a PHONY prerequisite).
define copy-vendor-core-lib
$(TARGET_OUT_VENDOR)/lib/$(1): $(TARGET_OUT)/lib/$(1)
	@mkdir -p $$(dir $$@)
	$$(hide) cp -f $$< $$@
$(TARGET_OUT_VENDOR)/lib64/$(1): $(TARGET_OUT)/lib64/$(1)
	@mkdir -p $$(dir $$@)
	$$(hide) cp -f $$< $$@
endef

$(foreach lib,$(VENDOR_CORE_LIBS),$(eval $(call copy-vendor-core-lib,$(lib))))

ALL_DEFAULT_INSTALLED_MODULES += $(VENDOR_CORE_LIB_COPIES)

# libskia.so: LOS 17.1 builds libskia as cc_library_static (no .so), but
# the 8.1 vendor blob libhwuiext.so DT_NEEDEDs libskia.so. The stock 8.1
# shared lib is shipped into /system/lib{,64} (proprietary-files.txt) and
# copied into /vendor/lib{,64} here so libhwuiext resolves.
SKIA_VENDOR_COPIES := \
	$(TARGET_OUT_VENDOR)/lib/libskia.so \
	$(TARGET_OUT_VENDOR)/lib64/libskia.so

$(TARGET_OUT_VENDOR)/lib/libskia.so: $(TARGET_OUT)/lib/libskia.so
	@mkdir -p $(dir $@)
	$(hide) cp -f $< $@

$(TARGET_OUT_VENDOR)/lib64/libskia.so: $(TARGET_OUT)/lib64/libskia.so
	@mkdir -p $(dir $@)
	$(hide) cp -f $< $@

ALL_DEFAULT_INSTALLED_MODULES += $(SKIA_VENDOR_COPIES)

# Subdirectory module makefiles -- currently power/Android.mk.
#
# This include is load-bearing and its absence silently dropped the power HAL
# from every build. Soong's module finder uses FindFirstNamedAt(), which stops
# descending as soon as it finds an Android.mk in a directory:
#
#     func (f *Finder) FindFirstNamedAt(...) {
#         ...
#         if len(matches) > 0 { return []string{}, matches }   // stop descending
#         return entries.DirNames, matches
#     }
#
# Because this top-level Android.mk exists, power/Android.mk was never added to
# out/.module_paths/Android.mk.list and the build system never parsed it. The
# `power.mt6765` module stayed undefined, `PRODUCT_PACKAGES += power.mt6765` in
# device.mk therefore resolved to nothing, and the image shipped AOSP's
# power.default.so, whose power_module_t has no setFeature member at all.
# android.hardware.power@1.0's Power::setFeature() is guarded by
# `if (mModule->setFeature)`, so IPower::setFeature(DOUBLE_TAP_TO_WAKE) became a
# silent no-op and double-tap-to-wake never worked.
#
# The build system only warns about an unresolved PRODUCT_PACKAGES entry in
# TARGET_BUILD_APPS (sdk) builds, so nothing flagged it on a normal ROM build.
# Hence all-makefiles-under: any future subdirectory module is picked up
# automatically instead of being dropped the same way.
include $(call all-makefiles-under,$(LOCAL_PATH))

endif
