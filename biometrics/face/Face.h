/*
 * Copyright (C) 2026 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * android.hardware.biometrics.face@1.0 implementation for the OPPO CPH1909.
 *
 * Face is a pure pass-through onto OppoFaceHal, which owns the forwarding to
 * the OPPO vendor face backend. See OppoFaceHal.h; the stock backend is
 * disabled in this build, so operations report OPERATION_NOT_SUPPORTED.
 */

#ifndef ANDROID_HARDWARE_BIOMETRICS_FACE_V1_0_FACE_H
#define ANDROID_HARDWARE_BIOMETRICS_FACE_V1_0_FACE_H

#include <android/hardware/biometrics/face/1.0/IBiometricsFace.h>
#include <android/hardware/biometrics/face/1.0/IBiometricsFaceClientCallback.h>

#include <memory>

#include "OppoFaceHal.h"

namespace android {
namespace hardware {
namespace biometrics {
namespace face {
namespace V1_0 {
namespace implementation {

class Face : public IBiometricsFace {
  public:
    Face();
    virtual ~Face();

    /* hidl-gen only elides the callback for scalar/enum returns; the
     * Optional* returns are unions, so the generated pure virtual is the
     * callback form. Match it exactly or it hides the base virtual. */
    Return<void> setCallback(const sp<IBiometricsFaceClientCallback>& clientCallback,
                             setCallback_cb _hidl_cb) override;
    Return<Status> setActiveUser(int32_t userId, const hidl_string& storePath) override;
    Return<void> generateChallenge(uint32_t challengeTimeoutSec,
                                   generateChallenge_cb _hidl_cb) override;
    Return<Status> enroll(const hidl_vec<uint8_t>& hat, uint32_t timeoutSec,
                          const hidl_vec<Feature>& disabledFeatures) override;
    Return<Status> revokeChallenge() override;
    Return<Status> setFeature(Feature feature, bool enabled, const hidl_vec<uint8_t>& hat,
                              uint32_t faceId) override;
    Return<void> getFeature(Feature feature, uint32_t faceId, getFeature_cb _hidl_cb) override;
    Return<void> getAuthenticatorId(getAuthenticatorId_cb _hidl_cb) override;
    Return<Status> cancel() override;
    Return<Status> enumerate() override;
    Return<Status> remove(uint32_t faceId) override;
    Return<Status> authenticate(uint64_t operationId) override;
    Return<Status> userActivity() override;
    Return<Status> resetLockout(const hidl_vec<uint8_t>& hat) override;

  private:
    std::unique_ptr<OppoFaceHal> mOppo;
    sp<IBiometricsFaceClientCallback> mClientCallback;
    int32_t mUserId;
};

}  // namespace implementation
}  // namespace V1_0
}  // namespace face
}  // namespace biometrics
}  // namespace hardware
}  // namespace android

#endif  // ANDROID_HARDWARE_BIOMETRICS_FACE_V1_0_FACE_H
