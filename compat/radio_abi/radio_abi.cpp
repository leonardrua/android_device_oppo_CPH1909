// Compatibility shim for the Android 8.1 radio HIDL struct helpers.
//
// android.hardware.radio@1.0 on Android 10 no longer exports the generated
// operator==/operator!= helpers nor the toString() debug helpers that the
// stock 8.1 vendor RIL (vendor.mediatek.hardware.radio@2.0_vendor.so) imports.
// The library is BIND_NOW, so the whole radio stack fails to load without
// them.
//
// Each function carries an __asm__ label with the exact mangled identifier
// from the blob's dynamic symbol table. C++ linkage (rather than extern "C")
// is required for the toString helpers, which return std::string. Struct
// layouts mirror radio/1.0/types.hal and use the real hidl_string/hidl_vec
// for guaranteed layout.

#include <hidl/HidlSupport.h>

#include <cstring>
#include <string>

using android::hardware::hidl_string;

namespace shim {

enum OperatorStatus : int32_t {
    OPERATOR_UNKNOWN = 0,
    OPERATOR_AVAILABLE = 1,
    OPERATOR_CURRENT = 2,
    OPERATOR_FORBIDDEN = 3,
};

struct OperatorInfo {
    hidl_string alphaLong;
    hidl_string alphaShort;
    hidl_string operatorNumeric;
    int32_t status;
};

struct DataProfileInfo {
    int32_t profileId;
    hidl_string apn;
    hidl_string protocol;
    hidl_string roamingProtocol;
    int32_t authType;
    hidl_string user;
    hidl_string password;
    int32_t type;
    int32_t maxConnsTime;
    int32_t maxConns;
    int32_t waitTime;
    bool enabled;
    uint32_t supportedApnTypesBitmap;
    uint32_t bearerBitmap;
    int32_t mtu;
    int32_t mvnoType;
    hidl_string mvnoMatchData;
};

struct SetupDataCallResult {
    int32_t status;
    int32_t suggestedRetryTime;
    int32_t cid;
    int32_t active;
    hidl_string type;
    hidl_string ifname;
    hidl_string addresses;
    hidl_string dnses;
    hidl_string gateways;
    hidl_string pcscf;
    int32_t mtu;
};

const char* clirName(uint32_t v) {
    switch (v) {
        case 0: return "DEFAULT";
        case 1: return "INVOCATION";
        case 2: return "SUPPRESSION";
        default: return "UNKNOWN";
    }
}

const char* forwardStatusName(uint32_t v) {
    switch (v) {
        case 0: return "DISABLE";
        case 1: return "ENABLE";
        case 2: return "INTERROGATE";
        case 3: return "REGISTRATION";
        case 4: return "ERASURE";
        default: return "UNKNOWN";
    }
}

const char* operatorStatusName(uint32_t v) {
    switch (v) {
        case 0: return "UNKNOWN";
        case 1: return "AVAILABLE";
        case 2: return "CURRENT";
        case 3: return "FORBIDDEN";
        default: return "UNKNOWN";
    }
}

bool sameString(const hidl_string& a, const hidl_string& b) {
    return a.size() == b.size() && memcmp(a.c_str(), b.c_str(), a.size()) == 0;
}

}  // namespace shim

using namespace shim;

// operator== / operator!=
bool rEqOperator(const OperatorInfo& a, const OperatorInfo& b)
        __asm__("_ZN7android8hardware5radio4V1_0eqERKNS2_12OperatorInfoES5_");
bool rNeOperator(const OperatorInfo& a, const OperatorInfo& b)
        __asm__("_ZN7android8hardware5radio4V1_0neERKNS2_12OperatorInfoES5_");
bool rEqProfile(const DataProfileInfo& a, const DataProfileInfo& b)
        __asm__("_ZN7android8hardware5radio4V1_0eqERKNS2_15DataProfileInfoES5_");
bool rNeProfile(const DataProfileInfo& a, const DataProfileInfo& b)
        __asm__("_ZN7android8hardware5radio4V1_0neERKNS2_15DataProfileInfoES5_");
bool rEqCall(const SetupDataCallResult& a, const SetupDataCallResult& b)
        __asm__("_ZN7android8hardware5radio4V1_0eqERKNS2_19SetupDataCallResultES5_");
bool rNeCall(const SetupDataCallResult& a, const SetupDataCallResult& b)
        __asm__("_ZN7android8hardware5radio4V1_0neERKNS2_19SetupDataCallResultES5_");

// toString helpers
std::string rToStringClir(uint32_t v)
        __asm__("_ZN7android8hardware5radio4V1_08toStringENS2_4ClirE");
std::string rToStringForwardStatus(uint32_t v)
        __asm__("_ZN7android8hardware5radio4V1_08toStringENS2_21CallForwardInfoStatusE");
std::string rToStringOperator(const OperatorInfo& info)
        __asm__("_ZN7android8hardware5radio4V1_08toStringERKNS2_12OperatorInfoE");
std::string rToStringProfile(const DataProfileInfo& info)
        __asm__("_ZN7android8hardware5radio4V1_08toStringERKNS2_15DataProfileInfoE");
std::string rToStringCall(const SetupDataCallResult& res)
        __asm__("_ZN7android8hardware5radio4V1_08toStringERKNS2_19SetupDataCallResultE");

bool rEqOperator(const OperatorInfo& a, const OperatorInfo& b) {
    return sameString(a.alphaLong, b.alphaLong) &&
           sameString(a.alphaShort, b.alphaShort) &&
           sameString(a.operatorNumeric, b.operatorNumeric) && a.status == b.status;
}

bool rNeOperator(const OperatorInfo& a, const OperatorInfo& b) { return !rEqOperator(a, b); }

bool rEqProfile(const DataProfileInfo& a, const DataProfileInfo& b) {
    return a.profileId == b.profileId && sameString(a.apn, b.apn) &&
           sameString(a.protocol, b.protocol) &&
           sameString(a.roamingProtocol, b.roamingProtocol) &&
           a.authType == b.authType && sameString(a.user, b.user) &&
           sameString(a.password, b.password) && a.type == b.type &&
           a.maxConnsTime == b.maxConnsTime && a.maxConns == b.maxConns &&
           a.waitTime == b.waitTime && a.enabled == b.enabled &&
           a.supportedApnTypesBitmap == b.supportedApnTypesBitmap &&
           a.bearerBitmap == b.bearerBitmap && a.mtu == b.mtu &&
           a.mvnoType == b.mvnoType && sameString(a.mvnoMatchData, b.mvnoMatchData);
}

bool rNeProfile(const DataProfileInfo& a, const DataProfileInfo& b) { return !rEqProfile(a, b); }

bool rEqCall(const SetupDataCallResult& a, const SetupDataCallResult& b) {
    return a.status == b.status && a.suggestedRetryTime == b.suggestedRetryTime &&
           a.cid == b.cid && a.active == b.active && sameString(a.type, b.type) &&
           sameString(a.ifname, b.ifname) && sameString(a.addresses, b.addresses) &&
           sameString(a.dnses, b.dnses) && sameString(a.gateways, b.gateways) &&
           sameString(a.pcscf, b.pcscf) && a.mtu == b.mtu;
}

bool rNeCall(const SetupDataCallResult& a, const SetupDataCallResult& b) { return !rEqCall(a, b); }

std::string rToStringClir(uint32_t v) { return clirName(v); }

std::string rToStringForwardStatus(uint32_t v) { return forwardStatusName(v); }

std::string rToStringOperator(const OperatorInfo& info) {
    return "{alphaLong: " + std::string(info.alphaLong.c_str(), info.alphaLong.size()) +
           ", alphaShort: " + std::string(info.alphaShort.c_str(), info.alphaShort.size()) +
           ", numeric: " + std::string(info.operatorNumeric.c_str(), info.operatorNumeric.size()) +
           ", status: " + operatorStatusName(info.status) + "}";
}

std::string rToStringProfile(const DataProfileInfo& info) {
    return "{profileId: " + std::to_string(info.profileId) +
           ", apn: " + std::string(info.apn.c_str(), info.apn.size()) +
           ", protocol: " + std::string(info.protocol.c_str(), info.protocol.size()) + "}";
}

std::string rToStringCall(const SetupDataCallResult& res) {
    return "{status: " + std::to_string(res.status) +
           ", cid: " + std::to_string(res.cid) +
           ", ifname: " + std::string(res.ifname.c_str(), res.ifname.size()) + "}";
}
