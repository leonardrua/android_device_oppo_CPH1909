// Compatibility shim for the Android 8.1 wifi HIDL toString helper.
//
// Android 10 dropped wifi::V1_0::toString(const sp<IWifiChipEventCallback>&)
// but the 8.1 vendor wifi@1.0-service still imports it. It is only used for
// debug strings, so a constant is sufficient.

#include <string>

namespace android {

template <typename T>
class sp {};

namespace hardware {
namespace wifi {
namespace V1_0 {

class IWifiChipEventCallback {};

std::string toString(const sp<IWifiChipEventCallback>& callback) {
    (void)callback;
    return std::string("IWifiChipEventCallback");
}

}  // namespace V1_0
}  // namespace wifi
}  // namespace hardware
}  // namespace android
