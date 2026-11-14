/*
 * Copyright (C) 2026 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Forwarding implementation of the OPPO face boundary.
 *
 * See OppoFaceHal.h for the rationale, the vendor-interface provenance and the
 * per-operation mapping. Every AOSP face@1.0 call is translated onto the stock
 * vendor.oppo.hardware.biometrics.face@1.0 interface reconstructed under
 * interfaces/vendor/hardware/biometrics/face/1.0/, and the vendor callback
 * is relayed back to the AOSP
 * callback through OppoFaceCallback below.
 *
 * The vendor mapping is reverse-engineered and UNVERIFIED. Where there is no
 * faithful vendor equivalent the call intentionally reports
 * OPERATION_NOT_SUPPORTED instead of guessing.
 */

#define LOG_TAG "OppoFaceHal"

#include "OppoFaceHal.h"

#include <inttypes.h>
#include <log/log.h>

#include <algorithm>
#include <cstring>

namespace android {
namespace hardware {
namespace biometrics {
namespace face {
namespace V1_0 {
namespace implementation {

using ::android::hardware::hidl_array;
using ::android::hardware::hidl_string;
using ::android::hardware::hidl_vec;
using ::android::hardware::Return;
using ::android::hardware::Void;

namespace {

/* The FQName of the stock vendor service this proxy forwards to. */
constexpr const char* kOppoFaceServiceName =
        "vendor.oppo.hardware.biometrics.face@1.0::IBiometricsFace";

/* The vendor enroll() takes a fixed-size HAT array; AOSP takes a variable
 * vec<uint8_t>. The AOSP face HAL sizes its HAT to fit a gatekeeper HMAC. */
constexpr size_t kHatSize = 69;

OptionalUint64 optU64(Status status, uint64_t value) {
    OptionalUint64 result;
    result.status = status;
    result.value = value;
    return result;
}

OptionalBool optBool(Status status, bool value) {
    OptionalBool result;
    result.status = status;
    result.value = value;
    return result;
}

/* Vendor RequestStatus is a Linux-errno-like int32_t; AOSP Status is a small
 * uint32_t enum. Only the meanings that clearly overlap are mapped. */
Status toAospStatus(vface::RequestStatus status) {
    switch (status) {
        case vface::RequestStatus::SYS_OK:
            return Status::OK;
        case vface::RequestStatus::SYS_EINVAL:
            return Status::ILLEGAL_ARGUMENT;
        case vface::RequestStatus::SYS_ENOENT:
            return Status::NOT_ENROLLED;
        default:
            return Status::INTERNAL_ERROR;
    }
}

/* Vendor acquired-info -> AOSP acquired-info. The two enums do not share a
 * numbering; this is an approximate correspondence. Anything not clearly
 * equivalent is reported as VENDOR with the raw vendor value as vendorCode. */
FaceAcquiredInfo toAospAcquired(vface::FaceAcquiredInfo info, int32_t* vendorCode) {
    *vendorCode = 0;
    switch (info) {
        case vface::FaceAcquiredInfo::ACQUIRED_GOOD:
            return FaceAcquiredInfo::GOOD;
        case vface::FaceAcquiredInfo::ACQUIRED_INSUFFICIENT:
            return FaceAcquiredInfo::INSUFFICIENT;
        case vface::FaceAcquiredInfo::ACQUIRED_IMAGER_DIRTY:
            return FaceAcquiredInfo::SENSOR_DIRTY;
        case vface::FaceAcquiredInfo::ACQUIRED_FAR_FACE:
            return FaceAcquiredInfo::TOO_FAR;
        case vface::FaceAcquiredInfo::ACQUIRED_NEAR_FACE:
            return FaceAcquiredInfo::TOO_CLOSE;
        case vface::FaceAcquiredInfo::ACQUIRED_NO_FACE:
            return FaceAcquiredInfo::NOT_DETECTED;
        case vface::FaceAcquiredInfo::ACQUIRED_DARK:
            return FaceAcquiredInfo::TOO_DARK;
        case vface::FaceAcquiredInfo::ACQUIRED_BRIGHT:
            return FaceAcquiredInfo::TOO_BRIGHT;
        case vface::FaceAcquiredInfo::ACQUIRED_SHIFTING:
            return FaceAcquiredInfo::TOO_MUCH_MOTION;
        case vface::FaceAcquiredInfo::ACQUIRED_LEFT:
            return FaceAcquiredInfo::FACE_TOO_LEFT;
        case vface::FaceAcquiredInfo::ACQUIRED_RIGHT:
            return FaceAcquiredInfo::FACE_TOO_RIGHT;
        case vface::FaceAcquiredInfo::ACQUIRED_UP:
            return FaceAcquiredInfo::FACE_TOO_HIGH;
        case vface::FaceAcquiredInfo::ACQUIRED_DOWN:
            return FaceAcquiredInfo::FACE_TOO_LOW;
        default:
            *vendorCode = static_cast<int32_t>(info);
            return FaceAcquiredInfo::VENDOR;
    }
}

/* Vendor error -> AOSP error. Values 1..6 line up by meaning; anything else is
 * reported as VENDOR with the raw vendor value as vendorCode. */
FaceError toAospError(vface::FaceError error, int32_t* vendorCode) {
    *vendorCode = 0;
    switch (error) {
        case vface::FaceError::ERROR_HW_UNAVAILABLE:
            return FaceError::HW_UNAVAILABLE;
        case vface::FaceError::ERROR_UNABLE_TO_PROCESS:
            return FaceError::UNABLE_TO_PROCESS;
        case vface::FaceError::ERROR_TIMEOUT:
            return FaceError::TIMEOUT;
        case vface::FaceError::ERROR_NO_SPACE:
            return FaceError::NO_SPACE;
        case vface::FaceError::ERROR_CANCELED:
            return FaceError::CANCELED;
        case vface::FaceError::ERROR_UNABLE_TO_REMOVE:
            return FaceError::UNABLE_TO_REMOVE;
        default:
            *vendorCode = static_cast<int32_t>(error);
            return FaceError::VENDOR;
    }
}

}  // namespace

/*
 * The AOSP client callback type. It must be spelled out in full because inside
 * OppoFaceCallback the unqualified name IBiometricsFaceClientCallback resolves
 * to the inherited *vendor* interface (a base class's injected-class-name),
 * which would silently wire the adapter to the wrong (vendor) interface. The
 * Realme RMX1801 fingerprint proxy fully qualifies for the same reason.
 */
using AospFaceClientCallback =
        ::android::hardware::biometrics::face::V1_0::IBiometricsFaceClientCallback;

/*
 * Relay for the stock vendor IBiometricsFaceClientCallback. The vendor service
 * calls these on its own binder thread; each is translated to the matching
 * AOSP callback registered by setNotify().
 *
 * UNVERIFIED: the vendor callback interface is a reconstruction, so both the
 * argument semantics (e.g. whether the vendor "groupId" is the AOSP userId,
 * and whether the vendor "hat" is the AOSP token) and the oneway-ness are
 * best-effort. Methods with no AOSP counterpart are logged and dropped.
 */
class OppoFaceCallback : public vface::IBiometricsFaceClientCallback {
  public:
    OppoFaceCallback(const sp<AospFaceClientCallback>& clientCallback, int32_t userId)
        : mClientCallback(clientCallback), mUserId(userId) {}

    void setUserId(int32_t userId) { mUserId = userId; }

    Return<void> onEnrollResult(uint64_t deviceId, uint32_t faceId, uint32_t groupId,
                                uint32_t remaining) override {
        ALOGI("onEnrollResult deviceId=%" PRIu64 " faceId=%u groupId=%u remaining=%u", deviceId,
              faceId, groupId, remaining);
        if (mClientCallback != nullptr) {
            mClientCallback->onEnrollResult(deviceId, faceId, static_cast<int32_t>(groupId),
                                            remaining);
        }
        return Void();
    }

    Return<void> onAcquired(uint64_t deviceId, vface::FaceAcquiredInfo acquiredInfo) override {
        int32_t vendorCode = 0;
        FaceAcquiredInfo aospInfo = toAospAcquired(acquiredInfo, &vendorCode);
        ALOGI("onAcquired deviceId=%" PRIu64 " acquiredInfo=%d", deviceId,
              static_cast<int32_t>(acquiredInfo));
        if (mClientCallback != nullptr) {
            mClientCallback->onAcquired(deviceId, mUserId, aospInfo, vendorCode);
        }
        return Void();
    }

    Return<void> onAuthenticated(uint64_t deviceId, uint32_t faceId, uint32_t groupId,
                                 uint32_t token, const hidl_vec<uint8_t>& hat) override {
        (void)token;
        ALOGI("onAuthenticated deviceId=%" PRIu64 " faceId=%u groupId=%u", deviceId, faceId,
              groupId);
        if (mClientCallback != nullptr) {
            /* The AOSP callback carries the HAT as the token; the vendor passes
             * it in the trailing vec<uint8_t>. */
            mClientCallback->onAuthenticated(deviceId, faceId, static_cast<int32_t>(groupId), hat);
        }
        return Void();
    }

    Return<void> onError(uint64_t deviceId, vface::FaceError error) override {
        int32_t vendorCode = 0;
        FaceError aospError = toAospError(error, &vendorCode);
        ALOGI("onError deviceId=%" PRIu64 " error=%d", deviceId, static_cast<int32_t>(error));
        if (mClientCallback != nullptr) {
            mClientCallback->onError(deviceId, mUserId, aospError, vendorCode);
        }
        return Void();
    }

    Return<void> onRemoved(uint64_t deviceId, uint32_t faceId, uint32_t groupId) override {
        ALOGI("onRemoved deviceId=%" PRIu64 " faceId=%u groupId=%u", deviceId, faceId, groupId);
        if (mClientCallback != nullptr) {
            mClientCallback->onRemoved(deviceId, hidl_vec<uint32_t>{faceId},
                                       static_cast<int32_t>(groupId));
        }
        return Void();
    }

    Return<void> onEnumerate(uint64_t deviceId, const hidl_vec<uint32_t>& faceIds,
                             uint32_t groupId) override {
        ALOGI("onEnumerate deviceId=%" PRIu64 " count=%zu groupId=%u", deviceId, faceIds.size(),
              groupId);
        if (mClientCallback != nullptr) {
            mClientCallback->onEnumerate(deviceId, faceIds, static_cast<int32_t>(groupId));
        }
        return Void();
    }

    /* Vendor-only callbacks with no AOSP face@1.0 counterpart: log and drop. */
    Return<void> onCommandResult(uint64_t deviceId, const hidl_vec<uint32_t>& result,
                                 const hidl_vec<hidl_string>& data) override {
        ALOGI("onCommandResult deviceId=%" PRIu64 " result=%zu data=%zu (dropped)", deviceId,
              result.size(), data.size());
        return Void();
    }

    Return<void> onFilterFailedAcquired(uint64_t deviceId, uint32_t info) override {
        ALOGI("onFilterFailedAcquired deviceId=%" PRIu64 " info=%u (dropped)", deviceId, info);
        return Void();
    }

    Return<void> onFailReasonAcquired(uint64_t deviceId, uint32_t info) override {
        ALOGI("onFailReasonAcquired deviceId=%" PRIu64 " info=%u (dropped)", deviceId, info);
        return Void();
    }

    Return<void> unlockRawImageDelivery(uint32_t value) override {
        ALOGI("unlockRawImageDelivery value=%u (dropped)", value);
        return Void();
    }

    Return<void> onStaticsReport(uint32_t arg1, uint32_t arg2) override {
        ALOGI("onStaticsReport %u %u (dropped)", arg1, arg2);
        return Void();
    }

  private:
    sp<AospFaceClientCallback> mClientCallback;
    int32_t mUserId;
};

OppoFaceHal::OppoFaceHal() : mUserId(-1) {}

OppoFaceHal::~OppoFaceHal() = default;

bool OppoFaceHal::initialize() {
    /* tryGetService() is non-blocking: the stock vendor service is disabled in
     * this build, so this returns null immediately and every operation falls
     * back to OPERATION_NOT_SUPPORTED. If the backend is ever enabled, switch
     * to the blocking getService() (or retry, as the Realme/OPPO fingerprint
     * adapters do, since face_hal is a late_start service). */
    mBackend = vface::IBiometricsFace::tryGetService();
    if (mBackend == nullptr) {
        ALOGW("OPPO vendor face service (%s) is not available; registering the "
              "AOSP face@1.0 interface with no backend "
              "(OPERATION_NOT_SUPPORTED until it is enabled)",
              kOppoFaceServiceName);
        return false;
    }
    ALOGI("connected to %s", kOppoFaceServiceName);
    return true;
}

OptionalUint64 OppoFaceHal::setNotify(const sp<IBiometricsFaceClientCallback>& callback) {
    if (mBackend == nullptr) {
        ALOGW("setNotify: no vendor backend");
        return optU64(Status::OPERATION_NOT_SUPPORTED, 0);
    }
    mCallback = new OppoFaceCallback(callback, mUserId);
    Return<uint64_t> ret = mBackend->setNotify(mCallback, false);
    if (!ret.isOk()) {
        ALOGE("setNotify: vendor call failed (%s)", ret.description().c_str());
        mCallback = nullptr;
        return optU64(Status::INTERNAL_ERROR, 0);
    }
    uint64_t deviceId = ret.withDefault(0);
    ALOGI("setNotify: vendor deviceId=%" PRIu64, deviceId);
    return optU64(Status::OK, deviceId);
}

Status OppoFaceHal::setActiveUser(int32_t userId, const hidl_string& storePath) {
    mUserId = userId;
    if (mCallback != nullptr) {
        mCallback->setUserId(userId);
    }
    if (mBackend == nullptr) {
        ALOGW("setActiveUser: no vendor backend");
        return Status::OPERATION_NOT_SUPPORTED;
    }
    return toAospStatus(mBackend->setActiveGroup(static_cast<uint32_t>(userId), storePath)
                                .withDefault(vface::RequestStatus::SYS_UNKNOWN));
}

OptionalUint64 OppoFaceHal::preEnroll() {
    if (mBackend == nullptr) {
        ALOGW("preEnroll: no vendor backend");
        return optU64(Status::OPERATION_NOT_SUPPORTED, 0);
    }
    Return<uint64_t> ret = mBackend->preEnroll();
    if (!ret.isOk()) {
        ALOGE("preEnroll: vendor call failed (%s)", ret.description().c_str());
        return optU64(Status::INTERNAL_ERROR, 0);
    }
    return optU64(Status::OK, ret.withDefault(0));
}

Status OppoFaceHal::enroll(const hidl_vec<uint8_t>& hat, uint32_t timeoutSec,
                           const hidl_vec<Feature>& disabledFeatures) {
    /* The vendor enroll() has no disabledFeatures parameter; AOSP features are
     * not forwarded here (see setFeature()). */
    (void)disabledFeatures;
    if (mBackend == nullptr) {
        ALOGW("enroll: no vendor backend");
        return Status::OPERATION_NOT_SUPPORTED;
    }
    hidl_array<uint8_t, kHatSize> vendorHat;
    std::memset(vendorHat.data(), 0, vendorHat.size());
    size_t copy = std::min(hat.size(), vendorHat.size());
    if (copy > 0) {
        std::memcpy(vendorHat.data(), hat.data(), copy);
    }
    if (hat.size() != vendorHat.size()) {
        ALOGW("enroll: HAT size %zu does not match vendor HAT size %zu", hat.size(),
              vendorHat.size());
    }
    return toAospStatus(
            mBackend->enroll(vendorHat, static_cast<uint32_t>(mUserId), timeoutSec)
                    .withDefault(vface::RequestStatus::SYS_UNKNOWN));
}

Status OppoFaceHal::postEnroll() {
    if (mBackend == nullptr) {
        ALOGW("postEnroll: no vendor backend");
        return Status::OPERATION_NOT_SUPPORTED;
    }
    return toAospStatus(
            mBackend->postEnroll().withDefault(vface::RequestStatus::SYS_UNKNOWN));
}

Status OppoFaceHal::setFeature(Feature feature, bool enabled, const hidl_vec<uint8_t>& hat,
                               uint32_t faceId) {
    /* The only vendor switch is SwitchType::TYPE_CLOSE_EYE_DETECT, which has no
     * AOSP face@1.0 Feature equivalent (REQUIRE_ATTENTION/REQUIRE_DIVERSITY).
     * Guessing would silently change security behaviour, so refuse. */
    (void)enabled;
    (void)hat;
    (void)faceId;
    ALOGW("setFeature(feature=%d): no faithful vendor mapping; reporting "
          "OPERATION_NOT_SUPPORTED",
          static_cast<int>(feature));
    return Status::OPERATION_NOT_SUPPORTED;
}

OptionalBool OppoFaceHal::getFeature(Feature feature, uint32_t faceId) {
    (void)faceId;
    ALOGW("getFeature(feature=%d): no faithful vendor mapping; reporting "
          "OPERATION_NOT_SUPPORTED",
          static_cast<int>(feature));
    return optBool(Status::OPERATION_NOT_SUPPORTED, false);
}

OptionalUint64 OppoFaceHal::getAuthenticatorId() {
    if (mBackend == nullptr) {
        ALOGW("getAuthenticatorId: no vendor backend");
        return optU64(Status::OPERATION_NOT_SUPPORTED, 0);
    }
    Return<uint64_t> ret = mBackend->getAuthenticatorId();
    if (!ret.isOk()) {
        ALOGE("getAuthenticatorId: vendor call failed (%s)", ret.description().c_str());
        return optU64(Status::INTERNAL_ERROR, 0);
    }
    return optU64(Status::OK, ret.withDefault(0));
}

Status OppoFaceHal::cancel() {
    if (mBackend == nullptr) {
        ALOGW("cancel: no vendor backend");
        return Status::OPERATION_NOT_SUPPORTED;
    }
    /* AOSP cancel() covers enroll/authenticate/remove/enumerate; the vendor
     * splits this into cancelEnrollment()/cancelAuthentication(). Issue both
     * (best-effort, unverified) and report success. The Return<RequestStatus>
     * results are deliberately discarded with (void): cancel() reports only
     * that the request was accepted, and Return<> is not [[nodiscard]]. */
    (void)mBackend->cancelAuthentication();
    (void)mBackend->cancelEnrollment();
    return Status::OK;
}

Status OppoFaceHal::enumerate() {
    if (mBackend == nullptr) {
        ALOGW("enumerate: no vendor backend");
        return Status::OPERATION_NOT_SUPPORTED;
    }
    /* The vendor has no explicit enumerate(); get(gid) is presumed to trigger
     * the onEnumerate() callback. Unverified. */
    return toAospStatus(mBackend->get(static_cast<uint32_t>(mUserId))
                                .withDefault(vface::RequestStatus::SYS_UNKNOWN));
}

Status OppoFaceHal::remove(uint32_t faceId) {
    if (mBackend == nullptr) {
        ALOGW("remove: no vendor backend");
        return Status::OPERATION_NOT_SUPPORTED;
    }
    /* AOSP remove(faceId) uses 0 to mean "all faces"; the vendor remove() takes
     * (gid, fid) with the same convention, so it passes through. */
    return toAospStatus(mBackend->remove(static_cast<uint32_t>(mUserId), faceId)
                                .withDefault(vface::RequestStatus::SYS_UNKNOWN));
}

Status OppoFaceHal::authenticate(uint64_t operationId) {
    if (mBackend == nullptr) {
        ALOGW("authenticate: no vendor backend");
        return Status::OPERATION_NOT_SUPPORTED;
    }
    /* Vendor authenticate(operationId, gid, arg3) has an extra trailing
     * argument of unknown meaning; pass 0. Unverified. */
    return toAospStatus(mBackend
                                ->authenticate(operationId, static_cast<uint32_t>(mUserId), 0)
                                .withDefault(vface::RequestStatus::SYS_UNKNOWN));
}

Status OppoFaceHal::userActivity() {
    /* No vendor equivalent. AOSP itself allows OPERATION_NOT_SUPPORTED here. */
    ALOGW("userActivity: no vendor equivalent");
    return Status::OPERATION_NOT_SUPPORTED;
}

Status OppoFaceHal::resetLockout(const hidl_vec<uint8_t>& hat) {
    /* No vendor equivalent (the vendor interface has no lockout reset). */
    (void)hat;
    ALOGW("resetLockout: no vendor equivalent");
    return Status::OPERATION_NOT_SUPPORTED;
}

}  // namespace implementation
}  // namespace V1_0
}  // namespace face
}  // namespace biometrics
}  // namespace hardware
}  // namespace android
