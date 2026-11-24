// Compatibility shims for Android 8.1 camera HAL libraries.
//
// 1) hidl::base::V1_0::toString(const DebugInfo&) was removed from Android 10's
//    libhidlbase; the 8.1 camera provider HAL still imports it.
// 2) GraphicBufferMapper::lock(const native_handle*, uint32_t, const Rect&,
//    void**) became a 6-argument function in Android 10; the 8.1 MTK camera
//    callbackclient HAL still imports the old 4-argument form. Forward that
//    call to the current libui implementation.

#include <cstdint>
#include <string>

struct native_handle;

namespace android {

class Rect;

class GraphicBufferMapper {
 public:
    int lock(const native_handle* handle, uint32_t usage, const Rect& region,
             void** vptr, int* stride, int* generation);
};

namespace hidl {
namespace base {
namespace V1_0 {

struct DebugInfo {};

std::string toString(const DebugInfo& info) {
    (void)info;
    return std::string("DebugInfo");
}

}  // namespace V1_0
}  // namespace base
}  // namespace hidl

}  // namespace android

// Old ABI: this is a member function, so the object is passed as the first
// argument. extern "C" keeps the exact legacy mangled symbol name.
extern "C" int
_ZN7android19GraphicBufferMapper4lockEPK13native_handlejRKNS_4RectEPPv(
        void* thiz, const native_handle* handle, uint32_t usage,
        const android::Rect& region, void** vptr) {
    int stride = 0;
    int generation = 0;
    return static_cast<android::GraphicBufferMapper*>(thiz)->lock(
            handle, usage, region, vptr, &stride, &generation);
}
