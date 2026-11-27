// Compatibility shims for Android 8.1 camera HAL libraries.
//
// 1) hidl::base::V1_0::toString(const DebugInfo&) was removed from Android 10's
//    libhidlbase; the 8.1 camera provider HAL still imports it.
// 2) android.hardware.camera.device@3.2's free toString() helpers were
//    dropped in Android 10; libmtkcam_device3_app.so still imports them.
// 3) GraphicBufferMapper::lock(const native_handle*, uint32_t, const Rect&,
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

namespace hardware {
namespace camera {
namespace device {
namespace V3_2 {

// Android 10's generated android.hardware.camera.device@3.2.so no longer
// exports the free toString() helpers that the 8.1 MTK camera HAL imports.
// These are only used for logging/error strings, so opaque types are enough.
enum ErrorCode : int32_t {};
struct StreamConfiguration {};
struct HalStreamConfiguration {};
struct Stream {};

std::string toString(ErrorCode code) {
    (void)code;
    return std::string("ErrorCode");
}

std::string toString(const StreamConfiguration& config) {
    (void)config;
    return std::string("StreamConfiguration");
}

std::string toString(const HalStreamConfiguration& config) {
    (void)config;
    return std::string("HalStreamConfiguration");
}

std::string toString(const Stream& stream) {
    (void)stream;
    return std::string("Stream");
}

}  // namespace V3_2
}  // namespace device
}  // namespace camera
}  // namespace hardware

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
