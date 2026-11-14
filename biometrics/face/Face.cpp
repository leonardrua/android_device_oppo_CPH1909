/*
 * Copyright (C) 2026 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * android.hardware.biometrics.face@1.0 implementation for the OPPO CPH1909.
 *
 * Each AOSP operation is forwarded to OppoFaceHal, the single boundary that
 * owns the (currently scaffold) connection to the OPPO vendor face backend.
 */

#define LOG_TAG "android.hardware.biometrics.face@1.0-service"

#include "Face.h"

#include <log/log.h>

namespace android {
namespace hardware {
namespace biometrics {
namespace face {
namespace V1_0 {
namespace implementation {

/* UserHandle is a HIDL scoped enum (hidl-gen emits "enum class"), so the
 * sentinel must be cast to the int32_t member. */
Face::Face() : mOppo(new OppoFaceHal()), mUserId(static_cast<int32_t>(UserHandle::NONE)) {
    if (!mOppo->initialize()) {
        ALOGW("OPPO face backend is a scaffold: the AOSP face@1.0 interface is "
              "registered but every operation reports OPERATION_NOT_SUPPORTED "
              "until the vendor interface is wired in (see OppoFaceHal.h)");
    }
}

Face::~Face() = default;

Return<void> Face::setCallback(const sp<IBiometricsFaceClientCallback>& clientCallback,
                               setCallback_cb _hidl_cb) {
    mClientCallback = clientCallback;
    _hidl_cb(mOppo->setNotify(clientCallback));
    return Void();
}

Return<Status> Face::setActiveUser(int32_t userId, const hidl_string& storePath) {
    mUserId = userId;
    return mOppo->setActiveUser(userId, storePath);
}

Return<void> Face::generateChallenge(uint32_t challengeTimeoutSec,
                                     generateChallenge_cb _hidl_cb) {
    (void)challengeTimeoutSec;
    _hidl_cb(mOppo->preEnroll());
    return Void();
}

Return<Status> Face::enroll(const hidl_vec<uint8_t>& hat, uint32_t timeoutSec,
                            const hidl_vec<Feature>& disabledFeatures) {
    return mOppo->enroll(hat, timeoutSec, disabledFeatures);
}

Return<Status> Face::revokeChallenge() {
    return mOppo->postEnroll();
}

Return<Status> Face::setFeature(Feature feature, bool enabled, const hidl_vec<uint8_t>& hat,
                                uint32_t faceId) {
    return mOppo->setFeature(feature, enabled, hat, faceId);
}

Return<void> Face::getFeature(Feature feature, uint32_t faceId, getFeature_cb _hidl_cb) {
    _hidl_cb(mOppo->getFeature(feature, faceId));
    return Void();
}

Return<void> Face::getAuthenticatorId(getAuthenticatorId_cb _hidl_cb) {
    _hidl_cb(mOppo->getAuthenticatorId());
    return Void();
}

Return<Status> Face::cancel() {
    return mOppo->cancel();
}

Return<Status> Face::enumerate() {
    return mOppo->enumerate();
}

Return<Status> Face::remove(uint32_t faceId) {
    return mOppo->remove(faceId);
}

Return<Status> Face::authenticate(uint64_t operationId) {
    return mOppo->authenticate(operationId);
}

Return<Status> Face::userActivity() {
    return mOppo->userActivity();
}

Return<Status> Face::resetLockout(const hidl_vec<uint8_t>& hat) {
    return mOppo->resetLockout(hat);
}

}  // namespace implementation
}  // namespace V1_0
}  // namespace face
}  // namespace biometrics
}  // namespace hardware
}  // namespace android
