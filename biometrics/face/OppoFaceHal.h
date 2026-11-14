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
 * So the only viable design is a source-built AOSP face@1.0 service (this
 * module) whose implementation proxies the AOSP calls onto the OPPO vendor
 * service. This class is that proxy. It is deliberately the ONLY place that
 * knows about the vendor interface, mirroring how biometrics/fingerprint/
 * is the only place that knows about the Silead module.
 *
 * STATUS: SCAFFOLD. The vendor interface has since been reconstructed from the
 * stock interface library (the reference .hal files are under
 * biometrics/face/hal/), but there is still no backend to talk to: the two
 * system-side interface libraries the stock service DT_NEEDEDs are not
 * imported and the stock service itself is disabled. Until the forwarding is
 * implemented every method reports Status::OPERATION_NOT_SUPPORTED and logs
 * once. This compiles and registers the AOSP interface, so the plumbing is
 * ready; it does not claim face unlock works.
 *
 * TO FINISH (reverse-engineering checklist)
 * -----------------------------------------
 *   1. The vendor interface has been reconstructed from the interface
 *      library (reference reconstruction under biometrics/face/hal/).
 *      Recovered:
 *
 *        * 22 IBiometricsFace methods, with transaction codes 1..22 in
 *          declaration order, full argument types and return wire types;
 *        * 11 IBiometricsFaceClientCallback methods, codes 1..11;
 *        * the 5 enums (RequestStatus/FaceError/FaceAcquiredInfo/
 *          FaceLogType/SwitchType) with values, and the 3 structs
 *          (RectHal/Point/FaceInfoWrapper) with layouts.
 *
 *      The vendor method set is fingerprint-shaped (setNotify/preEnroll/
 *      postEnroll/getAuthenticatorId/enroll/remove/setActiveGroup/
 *      authenticate/cancel), i.e. derived from the AOSP fingerprint HAL.
 *
 *      NOTE: the HIDL interface hash is SHA256 of the .hal *source file*
 *      (hidl-gen hashing/Hash.cpp), so a hand reconstruction cannot match
 *      the vendor's frozen hash (IBiometricsFace = fb9438a6...). Do NOT
 *      regenerate and ship the interface library; link the prebuilt
 *      vendor.oppo.hardware.biometrics.face@1.0.so instead, which already
 *      carries the correct hash.
 *   2. Import the two system-side interface libraries the stock service
 *      DT_NEEDEDs (system/lib/vendor.oppo.hardware.biometrics.face@1.0.so and
 *      system/lib/android.frameworks.faceservice@1.0.so) and re-enable the
 *      stock vendor service so there is a backend to talk to. The ColorOS
 *      framework side (android.frameworks.faceservice@1.0::IFaceHalService,
 *      declared in the stock *system* manifest) is an OPPO framework extension
 *      absent from LineageOS, so the vendor service's framework handshake may
 *      still not complete.
 *   3. Link the *prebuilt* vendor interface library here (do not regenerate it;
 *      see the NOTE above), replace the stubs with
 *      getService("vendor.oppo.hardware.biometrics.face@1.0::"
 *      "IBiometricsFace") calls, and map the AOSP face@1.0 semantics
 *      (setCallback/setActiveUser/generateChallenge/enroll/revokeChallenge/
 *      setFeature/getFeature/getAuthenticatorId/cancel/enumerate/remove/
 *      authenticate/userActivity/resetLockout) onto the vendor calls.
 *   4. Drop the OPERATION_NOT_SUPPORTED fallbacks and test on hardware.
 */

#ifndef ANDROID_HARDWARE_BIOMETRICS_FACE_V1_0_OPPOFACEHAL_H
#define ANDROID_HARDWARE_BIOMETRICS_FACE_V1_0_OPPOFACEHAL_H

#include <android/hardware/biometrics/face/1.0/IBiometricsFace.h>
#include <android/hardware/biometrics/face/1.0/IBiometricsFaceClientCallback.h>

namespace android {
namespace hardware {
namespace biometrics {
namespace face {
namespace V1_0 {
namespace implementation {

/*
 * Proxy to the stock OPPO face service.
 *
 * The method names here are the *AOSP* face@1.0 operations (what Face calls);
 * the doc comment on each records the vendor call it is intended to forward
 * to once the vendor HAL is available. Keeping the AOSP signatures here means
 * Face.cpp is a pure pass-through and the vendor mapping lives in one file.
 */
class OppoFaceHal {
  public:
    OppoFaceHal();
    ~OppoFaceHal();

    /* Connects to the vendor service. Returns true once the backend is usable.
     * Scaffold: always false (the vendor HAL is not linked in yet). */
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

    /* AOSP setFeature()              -> vendor updateSettingSwitchStatus() */
    Status setFeature(Feature feature, bool enabled, const hidl_vec<uint8_t>& hat, uint32_t faceId);

    /* AOSP getFeature()              -> vendor get() */
    OptionalBool getFeature(Feature feature, uint32_t faceId);

    /* AOSP getAuthenticatorId()      -> vendor getAuthenticatorId() */
    OptionalUint64 getAuthenticatorId();

    /* AOSP cancel()                  -> vendor cancelEnrollment()/cancelAuthentication()/cancelCommand() */
    Status cancel();

    /* AOSP enumerate()               -> vendor get() */
    Status enumerate();

    /* AOSP remove()                  -> vendor remove() */
    Status remove(uint32_t faceId);

    /* AOSP authenticate()            -> vendor authenticate()/verifyFace() */
    Status authenticate(uint64_t operationId);

    /* AOSP userActivity()            -> vendor (no direct equivalent) */
    Status userActivity();

    /* AOSP resetLockout()            -> vendor (no direct equivalent) */
    Status resetLockout(const hidl_vec<uint8_t>& hat);

  private:
    /* True once a connection to the vendor service has been established.
     * Scaffold: never set. */
    bool mConnected;
};

}  // namespace implementation
}  // namespace V1_0
}  // namespace face
}  // namespace biometrics
}  // namespace hardware
}  // namespace android

#endif  // ANDROID_HARDWARE_BIOMETRICS_FACE_V1_0_OPPOFACEHAL_H
