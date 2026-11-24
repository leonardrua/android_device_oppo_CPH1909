// Shim for the Android 10 android::base string_view helpers.
//
// Several vendor blobs are rewritten to libbase-v28.so because they import
// the v28 LogMessage constructor. Their process also loads Android 10 VNDK-SP
// libraries (libhidlbase.so, libcutils.so) which import the current
// StartsWith/EndsWith(string_view) overloads that v28 libbase does not export.
// Providing those two symbols in a separate small library satisfies both
// sides without downgrading the whole process to the v28 libbase ABI.

#include <string_view>

namespace android {
namespace base {

bool StartsWith(std::string_view str, std::string_view prefix) {
    return str.size() >= prefix.size() &&
           str.compare(0, prefix.size(), prefix) == 0;
}

bool EndsWith(std::string_view str, std::string_view suffix) {
    return str.size() >= suffix.size() &&
           str.compare(str.size() - suffix.size(), suffix.size(), suffix) == 0;
}

}  // namespace base
}  // namespace android
