/*
 * Copyright (C) 2026 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Entry point for the OPPO CPH1909 android.hardware.biometrics.face@1.0
 * service. Registers the AOSP interface so the Lineage biometric stack can
 * bind to it; the implementation forwards to the (disabled) OPPO backend, so
 * operations report OPERATION_NOT_SUPPORTED (see OppoFaceHal.h).
 */

#define LOG_TAG "android.hardware.biometrics.face@1.0-service"

#include <android/hardware/biometrics/face/1.0/IBiometricsFace.h>
#include <android/log.h>
#include <hidl/HidlSupport.h>
#include <hidl/HidlTransportSupport.h>
#include <log/log.h>
#include <utils/Errors.h>

#include "Face.h"

using android::hardware::configureRpcThreadpool;
using android::hardware::joinRpcThreadpool;
using android::hardware::biometrics::face::V1_0::IBiometricsFace;
using android::hardware::biometrics::face::V1_0::implementation::Face;
using android::sp;
using android::status_t;

int main() {
    configureRpcThreadpool(1, true);

    sp<IBiometricsFace> face = new Face();
    status_t status = face->registerAsService();
    if (status != android::OK) {
        ALOGE("Could not register android.hardware.biometrics.face@1.0 service: %d", status);
        return 1;
    }

    ALOGI("android.hardware.biometrics.face@1.0 service ready (backend disabled)");
    joinRpcThreadpool();

    /* joinRpcThreadpool() should never return. */
    return 1;
}
