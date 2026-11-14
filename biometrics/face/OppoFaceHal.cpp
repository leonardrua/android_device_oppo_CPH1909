/*
 * Copyright (C) 2026 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Scaffold implementation of the OPPO face forwarding boundary.
 *
 * See OppoFaceHal.h for the full rationale and the reverse-engineering
 * checklist. Every method below is a placeholder that returns
 * Status::OPERATION_NOT_SUPPORTED (or an Optional* carrying that status) so the
 * service registers cleanly without pretending to work.
 */

#define LOG_TAG "OppoFaceHal"

#include "OppoFaceHal.h"

#include <log/log.h>

namespace android {
namespace hardware {
namespace biometrics {
namespace face {
namespace V1_0 {
namespace implementation {

using ::android::hardware::hidl_string;
using ::android::hardware::hidl_vec;

namespace {

/* The FQName the proxy will look up once the vendor HAL is linked in. Kept as
 * a constant so the intended wiring is visible even while the backend is a
 * stub. */
constexpr const char* kOppoFaceServiceName = "vendor.oppo.hardware.biometrics.face@1.0::IBiometricsFace";

OptionalUint64 notSupportedU64() {
    OptionalUint64 result;
    result.status = Status::OPERATION_NOT_SUPPORTED;
    result.value = 0;
    return result;
}

OptionalBool notSupportedBool() {
    OptionalBool result;
    result.status = Status::OPERATION_NOT_SUPPORTED;
    result.value = false;
    return result;
}

}  // namespace

OppoFaceHal::OppoFaceHal() : mConnected(false) {}

OppoFaceHal::~OppoFaceHal() = default;

bool OppoFaceHal::initialize() {
    /* Scaffold: no vendor interface library is linked in yet, so there is
     * nothing to connect to. Log the intended target and report failure. */
    ALOGI("OPPO face backend scaffold active; will proxy to %s once the vendor "
          "HAL is imported (see OppoFaceHal.h)", kOppoFaceServiceName);
    mConnected = false;
    return mConnected;
}

OptionalUint64 OppoFaceHal::setNotify(const sp<IBiometricsFaceClientCallback>& callback) {
    (void)callback;
    ALOGW("setNotify: vendor forwarding not implemented yet");
    return notSupportedU64();
}

Status OppoFaceHal::setActiveUser(int32_t userId, const hidl_string& storePath) {
    (void)userId;
    (void)storePath;
    ALOGW("setActiveUser: vendor forwarding not implemented yet");
    return Status::OPERATION_NOT_SUPPORTED;
}

OptionalUint64 OppoFaceHal::preEnroll() {
    ALOGW("preEnroll: vendor forwarding not implemented yet");
    return notSupportedU64();
}

Status OppoFaceHal::enroll(const hidl_vec<uint8_t>& hat, uint32_t timeoutSec,
                           const hidl_vec<Feature>& disabledFeatures) {
    (void)hat;
    (void)timeoutSec;
    (void)disabledFeatures;
    ALOGW("enroll: vendor forwarding not implemented yet");
    return Status::OPERATION_NOT_SUPPORTED;
}

Status OppoFaceHal::postEnroll() {
    ALOGW("postEnroll: vendor forwarding not implemented yet");
    return Status::OPERATION_NOT_SUPPORTED;
}

Status OppoFaceHal::setFeature(Feature feature, bool enabled, const hidl_vec<uint8_t>& hat,
                               uint32_t faceId) {
    (void)feature;
    (void)enabled;
    (void)hat;
    (void)faceId;
    ALOGW("setFeature: vendor forwarding not implemented yet");
    return Status::OPERATION_NOT_SUPPORTED;
}

OptionalBool OppoFaceHal::getFeature(Feature feature, uint32_t faceId) {
    (void)feature;
    (void)faceId;
    ALOGW("getFeature: vendor forwarding not implemented yet");
    return notSupportedBool();
}

OptionalUint64 OppoFaceHal::getAuthenticatorId() {
    ALOGW("getAuthenticatorId: vendor forwarding not implemented yet");
    return notSupportedU64();
}

Status OppoFaceHal::cancel() {
    ALOGW("cancel: vendor forwarding not implemented yet");
    return Status::OPERATION_NOT_SUPPORTED;
}

Status OppoFaceHal::enumerate() {
    ALOGW("enumerate: vendor forwarding not implemented yet");
    return Status::OPERATION_NOT_SUPPORTED;
}

Status OppoFaceHal::remove(uint32_t faceId) {
    (void)faceId;
    ALOGW("remove: vendor forwarding not implemented yet");
    return Status::OPERATION_NOT_SUPPORTED;
}

Status OppoFaceHal::authenticate(uint64_t operationId) {
    (void)operationId;
    ALOGW("authenticate: vendor forwarding not implemented yet");
    return Status::OPERATION_NOT_SUPPORTED;
}

Status OppoFaceHal::userActivity() {
    ALOGW("userActivity: vendor forwarding not implemented yet");
    return Status::OPERATION_NOT_SUPPORTED;
}

Status OppoFaceHal::resetLockout(const hidl_vec<uint8_t>& hat) {
    (void)hat;
    ALOGW("resetLockout: vendor forwarding not implemented yet");
    return Status::OPERATION_NOT_SUPPORTED;
}

}  // namespace implementation
}  // namespace V1_0
}  // namespace face
}  // namespace biometrics
}  // namespace hardware
}  // namespace android
