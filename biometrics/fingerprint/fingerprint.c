/*
 * Copyright (C) 2026 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Legacy HAL shim for the OPPO CPH1909 (A5s, MT6765) Silead fingerprint sensor.
 *
 * Android 10's android.hardware.biometrics.fingerprint@2.1-service opens the
 * legacy fingerprint HAL with hw_get_module(FINGERPRINT_HARDWARE_MODULE_ID),
 * which probes fingerprint.<ro.hardware>.so -- fingerprint.mt6765.so here.
 *
 * The stock vendor image ships the real implementation as
 * fingerprint.silead.default.so (HMI id "fingerprint.silead", API 2.1, backed
 * by libsl_fp_impl.so and /dev/silead_fp). hw_get_module rejects a module whose
 * HMI id does not match the requested class id, so a plain symlink to the
 * Silead module cannot satisfy the "fingerprint" class probe.
 *
 * This module exports a "fingerprint"-id HMI that the AOSP service accepts,
 * then dlopens the Silead module directly and forwards open() to it. The Silead
 * module's own version and methods are used unchanged.
 */

#define LOG_TAG "FingerprintShim"

#include <dlfcn.h>
#include <errno.h>
#include <string.h>

#include <log/log.h>
#include <hardware/fingerprint.h>
#include <hardware/hardware.h>

#define SILEAD_FINGERPRINT_PATH "/vendor/lib64/hw/fingerprint.silead.default.so"
#define SILEAD_FINGERPRINT_PATH_32 "/vendor/lib/hw/fingerprint.silead.default.so"

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
        .name               = "CPH1909 Silead Fingerprint HAL shim",
        .author             = "The LineageOS Project",
        .methods            = &fingerprint_module_methods,
    },
};

static int fingerprint_open(const hw_module_t *module, const char *id,
                            hw_device_t **device) {
    const char *path;
    void *handle;
    const hw_module_t *real_module;
    int err;

    /* AOSP 10's global base flags pass -Wunused-parameter with -Werror
     * (seen in the failing CI build's clang command line). We do not
     * need the module pointer: the Silead module is opened via dlopen. */
    (void)module;

    if (device == NULL) {
        return -EINVAL;
    }
    *device = NULL;

#if defined(__LP64__)
    path = SILEAD_FINGERPRINT_PATH;
#else
    path = SILEAD_FINGERPRINT_PATH_32;
#endif

    handle = dlopen(path, RTLD_NOW);
    if (handle == NULL) {
        ALOGE("Failed to dlopen %s: %s", path, dlerror());
        return -EINVAL;
    }

    real_module = (const hw_module_t *)dlsym(handle, HAL_MODULE_INFO_SYM_AS_STR);
    if (real_module == NULL) {
        ALOGE("Failed to find %s in %s: %s", HAL_MODULE_INFO_SYM_AS_STR, path, dlerror());
        dlclose(handle);
        return -EINVAL;
    }

    if (real_module->methods == NULL || real_module->methods->open == NULL) {
        ALOGE("Silead fingerprint module has no open method");
        dlclose(handle);
        return -EINVAL;
    }

    ALOGI("Forwarding fingerprint open to %s (id=%s)", path, real_module->id);
    err = real_module->methods->open(real_module, id, device);
    if (err != 0) {
        ALOGE("Silead fingerprint open failed: %d", err);
        dlclose(handle);
        return err;
    }

    /* Keep the Silead module loaded for the lifetime of the process; the
     * AOSP fingerprint service is long-lived and the dlopen handle is not
     * needed after the device is open. */
    return 0;
}
