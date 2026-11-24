// Compatibility shim for the Android 8.1 broadcastradio HIDL 1.0 interface.
// Android 10 dropped broadcastradio::V1_0::toString(Band), which the 8.1
// vendor broadcastradio@1.1-service still imports. Same failure class as the
// audio toString(Result) shim in this library.
//
// This symbol is only used for error strings; the rest of the HIDL interface
// still comes from the platform VNDK libraries.

#include <cstdint>
#include <string>

namespace android {
namespace hardware {
namespace broadcastradio {
namespace V1_0 {

enum Band : int32_t {
    FM = 0,
    AM = 1,
    DAB = 2,
};

enum Class : int32_t {
    CLASS_AM_FM = 0,
    CLASS_DAB = 1,
};

std::string toString(Band val) {
    switch (val) {
        case FM:
            return "FM";
        case AM:
            return "AM";
        case DAB:
            return "DAB";
        default:
            return "UNKNOWN";
    }
}

std::string toString(Class val) {
    switch (val) {
        case CLASS_AM_FM:
            return "AM_FM";
        case CLASS_DAB:
            return "DAB";
        default:
            return "UNKNOWN";
    }
}

}  // namespace V1_0
}  // namespace broadcastradio
}  // namespace hardware
}  // namespace android
