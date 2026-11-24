// Compatibility shim for the Android 8.1 audio HIDL 2.0 interface.
//
// The 8.1 vendor audio HAL (and vendor.mediatek.hardware.audio@2.1_vendor.so)
// call android::hardware::audio::V2_0::toString(Result). That generated helper
// was dropped from Android 10's audio@2.0 VNDK library, so BIND_NOW fails with
// "cannot locate symbol _ZN7android8hardware5audio4V2_08toStringENS2_6ResultE"
// and audio-hal-2-0 restarts forever, leaving media.audio_policy unregistered.
//
// Only the symbol is needed (the HAL uses it for error strings); the rest of
// the HIDL 2.0 interface still comes from the platform VNDK library.

#include <cstdint>
#include <string>

namespace android {
namespace hardware {
namespace audio {
namespace V2_0 {

enum Result : int32_t {
    OK = 0,
    NOT_FOUND = 1,
    INVALID_ARGUMENT = 2,
};

std::string toString(Result val) {
    switch (val) {
        case OK:
            return "OK";
        case NOT_FOUND:
            return "NOT_FOUND";
        case INVALID_ARGUMENT:
            return "INVALID_ARGUMENT";
        default:
            return "UNKNOWN";
    }
}

}  // namespace V2_0
}  // namespace audio
}  // namespace hardware
}  // namespace android
