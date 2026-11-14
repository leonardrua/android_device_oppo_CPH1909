/*
 * Copyright (C) 2026 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Forwarding boundary between the AOSP android.hardware.biometrics.face@1.0
 * service and the stock OPPO face backend on the CPH1909 (A5s, MT6765).
 *
 * WHY THIS FILE EXISTS
 * --------------------
 * The fingerprint bring-up works by wrapping a *legacy* HAL module
 * (fingerprint.silead.default.so) that the AOSP fingerprint@2.1 service loads
 * through hw_get_module(). Face has no equivalent:
 *
 *   * Android 10 ships no android.hardware.biometrics.face@1.0 default service.
 *   * The vendor ships no legacy face HAL module (no face.*.so, no
 *     hw_get_module(FACE_HARDWARE_MODULE_ID) anywhere in the dump).
 *   * The stock face service implements a *custom*, vendor-namespaced HIDL
 *     interface: vendor.oppo.hardware.biometrics.face@1.0::IBiometricsFace,
 *     which the AOSP framework never binds to.
 *
 * So the design is a source-built AOSP face@1.0 service (this module) whose
 * implementation forwards the AOSP calls onto the OPPO vendor service. This
 * class is that proxy. It is deliberately the ONLY place that knows about the
 * vendor interface, mirroring how biometrics/fingerprint/ is the only place
 * that knows about the Silead module.
 *
 * STATUS: FORWARDING IMPLEMENTED, BACKEND DISABLED.
 * ------------------------------------------------
 * The vendor interface is reconstructed under
 * interfaces/vendor/hardware/biometrics/face/1.0/ and built as the
 * vendor.oppo.hardware.biometrics.face@1.0 hidl_interface. This class now
 * calls getService() on it and maps every AOSP face@1.0 operation onto the
 * vendor calls, with a callback adapter in OppoFaceHal.cpp that relays the
 * vendor IBiometricsFaceClientCallback back to the AOSP one.
 *
 * The stock vendor face service (vendor.oppo.hardware.biometrics.face@1.0-
 * service) is still deliberately *disabled* in this build (it DT_NEEDEDs the
 * ColorOS system-side lib android.frameworks.faceservice@1.0.so, whose
 * IFaceHalService handshake is an OPPO framework extension absent from
 * LineageOS). So initialize() finds no backend at runtime, and every method
 * below falls back to Status::OPERATION_NOT_SUPPORTED. The forwarding code is
 * present and compiles; it simply has nothing to talk to yet. This does not
 * claim face unlock works.
 *
 * The vendor method mapping is reverse-engineered and UNVERIFIED (the vendor
 * .hal is a reconstruction, and there are no device logs). Each method's doc
 * comment records the vendor call it targets and how confident that mapping
 * is. Operations with no faithful vendor equivalent (getFeature, setFeature,
 * userActivity, resetLockout) intentionally return OPERATION_NOT_SUPPORTED
 * rather than guessing.
 */

#ifndef ANDROID_HARDWARE_BIOMETRICS_FACE_V1_0_OPPOFACEHAL_H
#define ANDROID_HARDWARE_BIOMETRICS_FACE_V1_0_OPPOFACEHAL_H

#include <android/hardware/biometrics/face/1.0/IBiometricsFace.h>
#include <android/hardware/biometrics/face/1.0/IBiometricsFaceClientCallback.h>

/* Reconstructed OPPO vendor interface; see
 * interfaces/vendor/hardware/biometrics/face/1.0/. */
#include <vendor/oppo/hardware/biometrics/face/1.0/IBiometricsFace.h>
#include <vendor/oppo/hardware/biometrics/face/1.0/IBiometricsFaceClientCallback.h>

namespace android {
namespace hardware {
namespace biometrics {
namespace face {
namespace V1_0 {
namespace implementation {

/* Alias for the vendor package so the AOSP and vendor types of the same name
 * (IBiometricsFace, IBiometricsFaceClientCallback, ...) stay unambiguous. */
namespace vface = ::vendor::oppo::hardware::biometrics::face::V1_0;

class OppoFaceCallback;

/*
 * Proxy to the stock OPPO face service.
 *
 * The method names here are the *AOSP* face@1.0 operations (what Face calls);
 * the doc comment on each records the vendor call it forwards to.
 */
class OppoFaceHal {
  public:
    OppoFaceHal();
    ~OppoFaceHal();

    /* Connects to the vendor service. Returns true once the backend is usable.
     * With the stock vendor service disabled in this build this returns false
     * and every operation below reports OPERATION_NOT_SUPPORTED. */
    bool initialize();

    /* AOSP setCallback()             -> vendor setNotify() */
    OptionalUint64 setNotify(const sp<IBiometricsFaceClientCallback>& callback);

    /* AOSP setActiveUser()           -> vendor setActiveGroup() */
    Status setActiveUser(int32_t userId, const hidl_string& storePath);

    /* AOSP generateChallenge()       -> vendor preEnroll() */
    OptionalUint64 preEnroll();

    /* AOSP enroll()                  -> vendor enroll() */
    Status enroll(const hidl_vec<uint8_t>& hat, uint32_t timeoutSec,
                  const hidl_vec<Feature>& disabledFeatures);

    /* AOSP revokeChallenge()         -> vendor postEnroll() */
    Status postEnroll();

    /* AOSP setFeature()              -> no faithful vendor equivalent */
    Status setFeature(Feature feature, bool enabled, const hidl_vec<uint8_t>& hat, uint32_t faceId);

    /* AOSP getFeature()              -> no faithful vendor equivalent */
    OptionalBool getFeature(Feature feature, uint32_t faceId);

    /* AOSP getAuthenticatorId()      -> vendor getAuthenticatorId() */
    OptionalUint64 getAuthenticatorId();

    /* AOSP cancel()                  -> vendor cancelEnrollment()/cancelAuthentication() */
    Status cancel();

    /* AOSP enumerate()               -> vendor get() */
    Status enumerate();

    /* AOSP remove()                  -> vendor remove() */
    Status remove(uint32_t faceId);

    /* AOSP authenticate()            -> vendor authenticate() */
    Status authenticate(uint64_t operationId);

    /* AOSP userActivity()            -> no vendor equivalent */
    Status userActivity();

    /* AOSP resetLockout()            -> no vendor equivalent */
    Status resetLockout(const hidl_vec<uint8_t>& hat);

  private:
    /* Connection to the stock vendor face service. Null until initialize()
     * succeeds (and null in this build, since the backend is disabled). */
    sp<vface::IBiometricsFace> mBackend;

    /* Adapter that relays the vendor IBiometricsFaceClientCallback to the AOSP
     * callback registered through setNotify(). */
    sp<OppoFaceCallback> mCallback;

    /* Active user id, forwarded as the vendor group id and stamped on the
     * callbacks that do not carry one. -1 until setActiveUser(). */
    int32_t mUserId;
};

}  // namespace implementation
}  // namespace V1_0
}  // namespace face
}  // namespace biometrics
}  // namespace hardware
}  // namespace android

#endif  // ANDROID_HARDWARE_BIOMETRICS_FACE_V1_0_OPPOFACEHAL_H
