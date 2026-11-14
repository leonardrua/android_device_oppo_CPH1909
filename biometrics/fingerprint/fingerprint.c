/*
 * Copyright (C) 2026 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Legacy HAL shim for the OPPO CPH1909 (A5s, MT6765) fingerprint sensors.
 *
 * Android 10's android.hardware.biometrics.fingerprint@2.1-service opens the
 * legacy fingerprint HAL with hw_get_module(FINGERPRINT_HARDWARE_MODULE_ID),
 * which probes fingerprint.<ro.hardware>.so -- fingerprint.mt6765.so here.
 *
 * The stock vendor image ships the real implementations per sensor vendor,
 * e.g. fingerprint.silead.default.so (HMI id "fingerprint.silead", API 2.1,
 * backed by libsl_fp_impl.so and /dev/silead_fp) and
 * fingerprint.egis.default.so (HMI id "fingerprint.egis", API 2.1, backed by
 * vendor.egistec.hardware.fingerprint@4.0.so + libRbsFlow.so).  hw_get_module
 * rejects a module whose HMI id does not match the requested class id, so a
 * plain symlink to a vendor module cannot satisfy the "fingerprint" class
 * probe.
 *
 * This module exports a "fingerprint"-id HMI that the AOSP service accepts,
 * then dlopens the vendor modules and forwards open() to the first one that
 * actually works.  The selection mirrors the stock OPPO service
 * (vendor.oppo.hardware.biometrics.fingerprint@2.1-service), which iterates a
 * table of {vendor, module id, model} in order -- "silead" then "egis" -- and
 * stops at the first module that reports API 2.1 and whose open() succeeds;
 * it then records the winner in persist.sys.fp.vendor.  Silead is first
 * because it is the CPH1909's primary sensor (Egis is the alternate build).
 * The vendor module's own version and methods are used unchanged.
 */

#define LOG_TAG "FingerprintShim"

#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>

#include <cutils/properties.h>
#include <log/log.h>
#include <hardware/fingerprint.h>
#include <hardware/hardware.h>

/* Property the stock service uses to record the detected vendor. */
#define FP_VENDOR_PROP "persist.sys.fp.vendor"

struct fp_vendor {
    /* Value written to persist.sys.fp.vendor. */
    const char *name;
    /* hw module base name: <module>.<variant>.so in /vendor/lib[64]/hw. */
    const char *module;
    /* Model string, log-only (matches the stock service's table). */
    const char *model;
};

/*
 * Ordered probe list; add an entry for any other vendor whose legacy module
 * the vendor tree installs (there are only these two in the CPH1909 dump).
 */
static const struct fp_vendor kFpVendors[] = {
    { "silead", "fingerprint.silead", "silead_sil-5180" },
    { "egis",   "fingerprint.egis",   "egis-et520" },
};

#define FP_VENDOR_COUNT (sizeof(kFpVendors) / sizeof(kFpVendors[0]))

static int fingerprint_open(const hw_module_t *module, const char *id,
                            hw_device_t **device);

static struct hw_module_methods_t fingerprint_module_methods = {
    .open = fingerprint_open,
};

fingerprint_module_t HAL_MODULE_INFO_SYM = {
    .common = {
        .tag                = HARDWARE_MODULE_TAG,
        .module_api_version = FINGERPRINT_MODULE_API_VERSION_2_1,
        .hal_api_version    = HARDWARE_HAL_API_VERSION,
        .id                 = FINGERPRINT_HARDWARE_MODULE_ID,
        .name               = "CPH1909 Fingerprint HAL shim",
        .author             = "The LineageOS Project",
        .methods            = &fingerprint_module_methods,
    },
};

static int vendor_module_path(char *path, size_t size, const char *module) {
    int written;

#if defined(__LP64__)
    written = snprintf(path, size, "/vendor/lib64/hw/%s.default.so", module);
#else
    written = snprintf(path, size, "/vendor/lib/hw/%s.default.so", module);
#endif

    if (written < 0 || (size_t)written >= size) {
        return -1;
    }

    return 0;
}

static int fingerprint_open(const hw_module_t *module, const char *id,
                            hw_device_t **device) {
    size_t i;

    /* AOSP 10's global base flags pass -Wunused-parameter with -Werror
     * (seen in the failing CI build's clang command line). We do not
     * need the module pointer: the vendor module is opened via dlopen. */
    (void)module;

    if (device == NULL) {
        return -EINVAL;
    }
    *device = NULL;

    for (i = 0; i < FP_VENDOR_COUNT; i++) {
        const struct fp_vendor *vendor = &kFpVendors[i];
        const hw_module_t *real_module;
        char path[256];
        void *handle;
        int err;

        if (vendor_module_path(path, sizeof(path), vendor->module) != 0) {
            ALOGE("Fingerprint module path for %s is too long", vendor->module);
            continue;
        }

        handle = dlopen(path, RTLD_NOW);
        if (handle == NULL) {
            ALOGD("%s not available: %s", path, dlerror());
            continue;
        }

        real_module = (const hw_module_t *)dlsym(handle, HAL_MODULE_INFO_SYM_AS_STR);
        if (real_module == NULL) {
            ALOGE("Failed to find %s in %s: %s", HAL_MODULE_INFO_SYM_AS_STR, path,
                  dlerror());
            dlclose(handle);
            continue;
        }

        /* The AOSP 2.1 service drives a fingerprint_device_t, so only accept
         * 2.1 vendor modules (the stock service makes the same check). */
        if (real_module->module_api_version != FINGERPRINT_MODULE_API_VERSION_2_1) {
            ALOGE("%s is fingerprint HAL API 0x%x, need 0x%x", path,
                  (unsigned)real_module->module_api_version,
                  (unsigned)FINGERPRINT_MODULE_API_VERSION_2_1);
            dlclose(handle);
            continue;
        }

        if (real_module->methods == NULL || real_module->methods->open == NULL) {
            ALOGE("%s (%s) has no open method", path, vendor->model);
            dlclose(handle);
            continue;
        }

        ALOGI("Trying %s (%s)", path, vendor->model);
        err = real_module->methods->open(real_module, id, device);
        if (err != 0) {
            ALOGE("%s open failed: %d", path, err);
            *device = NULL;
            dlclose(handle);
            continue;
        }

        if (property_set(FP_VENDOR_PROP, vendor->name) != 0) {
            ALOGW("Could not set %s=%s (non-fatal)", FP_VENDOR_PROP, vendor->name);
        }

        ALOGI("Forwarding fingerprint to %s (%s)", path, vendor->model);

        /* Keep the vendor module loaded for the lifetime of the process; the
         * AOSP fingerprint service is long-lived and the dlopen handle is not
         * needed after the device is open. */
        return 0;
    }

    ALOGE("No usable fingerprint vendor module found");
    return -EINVAL;
}