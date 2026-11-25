// Shim for the Android 10 android::base string_view helpers.
//
// Several vendor blobs are rewritten to libbase-v28.so because they import
// the v28 LogMessage constructor. Their process also loads Android 10 VNDK-SP
// libraries (libhidlbase.so, libcutils.so) which import the current
// StartsWith/EndsWith(string_view) overloads that v28 libbase does not export.
// Providing those two symbols in a separate small library satisfies both
// sides without downgrading the whole process to the v28 libbase ABI.

#include <string_view>

// Several vendor binaries and Android 10 VNDK-SP libraries (libhidlbase.so,
// libcutils.so) import StartsWith/EndsWith(string_view) using the standard
// mangled symbol names:
//   _ZN7android4base10StartsWithENSt3__117basic_string_viewIcNS1_11char_traitsIcEEEES5_
//   _ZN7android4base8EndsWithENSt3__117basic_string_viewIcNS1_11char_traitsIcEEEES5_
// We use __asm__ labels with C++ linkage so that regardless of libc++ header
// inline namespace settings, the exact target symbol is exported.

namespace android {
namespace base {

bool StartsWith(std::string_view str, std::string_view prefix)
        __asm__("_ZN7android4base10StartsWithENSt3__117basic_string_viewIcNS1_11char_traitsIcEEEES5_");

bool StartsWith(std::string_view str, std::string_view prefix) {
    return str.size() >= prefix.size() &&
           str.compare(0, prefix.size(), prefix) == 0;
}

bool EndsWith(std::string_view str, std::string_view suffix)
        __asm__("_ZN7android4base8EndsWithENSt3__117basic_string_viewIcNS1_11char_traitsIcEEEES5_");

bool EndsWith(std::string_view str, std::string_view suffix) {
    return str.size() >= suffix.size() &&
           str.compare(str.size() - suffix.size(), suffix.size(), suffix) == 0;
}

}  // namespace base
}  // namespace android
