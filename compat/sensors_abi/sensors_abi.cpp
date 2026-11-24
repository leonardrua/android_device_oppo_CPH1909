// Compatibility shim for android::AppOpsManager, used by the platform-built
// libsensor.so that is shipped into /vendor for libFactoryHALSensor.so.
//
// Android 10 hides AppOpsManager's symbols behind libbinder's version script,
// so a vendor copy of libsensor.so cannot resolve them. Both the constructor
// and permissionToOpCode are trivial without binder access:
//   * the constructor only default-constructs a Mutex and a null sp<>
//     (Android 10 AppOpsManager.cpp has an empty body), so zeroing the object
//     reproduces its state (bionic Mutex is already all-zero initialized);
//   * permissionToOpCode() returns -1 when the op service is unavailable,
//     which is exactly the behaviour we provide.
//
// Layout comes from frameworks/native/libs/binder/include/binder/AppOpsManager.h
//   class AppOpsManager { Mutex mLock; sp<IAppOpsService> mService; };
// bionic pthread_mutex_t is 40 bytes on both ABIs, sp<> is one pointer.

#include <stdint.h>
#include <string.h>

namespace {

#if defined(__LP64__)
constexpr size_t kAppOpsManagerSize = 48;  // Mutex(40) + sp(8)
#else
constexpr size_t kAppOpsManagerSize = 44;  // Mutex(40) + sp(4)
#endif

}  // namespace

extern "C" {

// android::AppOpsManager::AppOpsManager()
void _ZN7android13AppOpsManagerC1Ev(void* self) {
    memset(self, 0, kAppOpsManagerSize);
}

// int32_t android::AppOpsManager::permissionToOpCode(const android::String16&)
int32_t _ZN7android13AppOpsManager18permissionToOpCodeERKNS_8String16E(const void* permission) {
    (void)permission;
    return -1;
}

}  // extern "C"
