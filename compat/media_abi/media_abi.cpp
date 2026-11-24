// Compatibility shim for the Android 8.1 media_xmlparser ABI.
//
// The 8.1 vendor OMX service and its libmediacodecservice.so reference
// MediaCodecsXmlParser::defaultSearchDirs, which Android 10 removed from
// libstagefright_xmlparser. Only the symbol is needed; provide an equivalent
// search path list so the codec XML parser still works.

#include <string>
#include <vector>

namespace android {

class MediaCodecsXmlParser {
 public:
    static std::vector<std::string> defaultSearchDirs;
};

std::vector<std::string> MediaCodecsXmlParser::defaultSearchDirs = {
    "/vendor/etc/media_codecs.xml",
    "/vendor/etc/media_codecs_vendor.xml",
    "/system/etc/media_codecs.xml",
    "/system/etc/media_codecs_performance.xml",
};

}  // namespace android
