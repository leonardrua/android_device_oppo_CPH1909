//
// Copyright (C) 2026 The LineageOS Project
//
// SPDX-License-Identifier: Apache-2.0
//
// Compatibility shim for the Android 8.1 broadcastradio HIDL helper functions.
//
// Android 10's android.hardware.broadcastradio@1.0/1.1 libraries no longer
// export the struct helpers (eq) and the toString() debug helpers that the
// stock 8.1 vendor service imports. The service is BIND_NOW, so every one of
// them must resolve at load time or the HAL never starts.
//
// Each function carries an __asm__ label with the exact mangled identifier
// observed in the blob's dynamic symbol table. C++ linkage (rather than
// extern "C") is required because these helpers return std::string, which
// Clang rejects as an extern "C" return type. Struct layouts mirror the HIDL
// definitions in hardware/interfaces/broadcastradio/{1.0,1.1}/types.hal;
// hidl_string and hidl_vec come from the real libhidlbase headers.

#include <hidl/HidlSupport.h>

#include <string>

using android::hardware::hidl_string;
using android::hardware::hidl_vec;

namespace shim {

// --- broadcastradio@1.0 layouts -------------------------------------------
struct AmBandConfig {
    bool stereo;
};

struct FmBandConfig {
    uint32_t deemphasis;
    bool stereo;
    uint32_t rds;
    bool ta;
    bool af;
    bool ea;
};

// --- broadcastradio@1.1 layouts -------------------------------------------
struct ProgramIdentifier {
    uint32_t type;
    uint64_t value;
};

struct VendorKeyValue {
    hidl_string key;
    hidl_string value;
};

struct ProgramSelector {
    uint32_t programType;
    ProgramIdentifier primaryId;
    hidl_vec<ProgramIdentifier> secondaryIds;
    hidl_vec<uint64_t> vendorIds;
};

const char* bandName(uint32_t v) {
    switch (v) {
        case 0: return "AM";
        case 1: return "FM";
        case 2: return "FM_HD";
        case 3: return "AM_HD";
        default: return "UNKNOWN";
    }
}

const char* className(uint32_t v) {
    switch (v) {
        case 0: return "AM_FM";
        case 1: return "SAT";
        case 2: return "DT";
        default: return "UNKNOWN";
    }
}

const char* programTypeName(uint32_t v) {
    switch (v) {
        case 1: return "AM";
        case 2: return "FM";
        case 3: return "AM_HD";
        case 4: return "FM_HD";
        case 5: return "DAB";
        case 6: return "DRMO";
        case 7: return "SXM";
        default: return "VENDOR";
    }
}

const char* identifierTypeName(uint32_t v) {
    switch (v) {
        case 1: return "AMFM_FREQUENCY";
        case 2: return "RDS_PI";
        case 3: return "HD_STATION_ID_EXT";
        case 4: return "HD_SUBCHANNEL";
        case 5: return "DAB_SIDECC";
        case 6: return "DAB_ENSEMBLE";
        case 7: return "DAB_SCID";
        case 8: return "DAB_FREQUENCY";
        case 9: return "DRMO_SERVICE_ID";
        case 10: return "DRMO_FREQUENCY";
        case 11: return "DRMO_MODULATION";
        case 12: return "SXM_SERVICE_ID";
        case 13: return "SXM_CHANNEL";
        default: return "VENDOR_PRIMARY";
    }
}

}  // namespace shim

using namespace shim;

// V1_0::toString helpers
std::string brToStringBand(uint32_t v)
        __asm__("_ZN7android8hardware14broadcastradio4V1_08toStringENS2_4BandE");
std::string brToStringClass(uint32_t v)
        __asm__("_ZN7android8hardware14broadcastradio4V1_08toStringENS2_5ClassE");
std::string brToStringDirection(uint32_t v)
        __asm__("_ZN7android8hardware14broadcastradio4V1_08toStringENS2_9DirectionE");

// V1_1::toString helpers
std::string brToStringProgramType(uint32_t v)
        __asm__("_ZN7android8hardware14broadcastradio4V1_18toStringENS2_11ProgramTypeE");
std::string brToStringIdentifierType(uint32_t v)
        __asm__("_ZN7android8hardware14broadcastradio4V1_18toStringENS2_14IdentifierTypeE");
std::string brToStringVendorKeyValue(const VendorKeyValue& kv)
        __asm__("_ZN7android8hardware14broadcastradio4V1_18toStringERKNS2_14VendorKeyValueE");
std::string brToStringProgramSelector(const ProgramSelector& sel)
        __asm__("_ZN7android8hardware14broadcastradio4V1_18toStringERKNS2_15ProgramSelectorE");

// V1_0::eq helpers
bool brEqAm(const AmBandConfig& a, const AmBandConfig& b)
        __asm__("_ZN7android8hardware14broadcastradio4V1_0eqERKNS2_12AmBandConfigES5_");
bool brEqFm(const FmBandConfig& a, const FmBandConfig& b)
        __asm__("_ZN7android8hardware14broadcastradio4V1_0eqERKNS2_12FmBandConfigES5_");

std::string brToStringBand(uint32_t v) { return bandName(v); }

std::string brToStringClass(uint32_t v) { return className(v); }

std::string brToStringDirection(uint32_t v) { return v == 1 ? "DOWN" : "UP"; }

std::string brToStringProgramType(uint32_t v) { return programTypeName(v); }

std::string brToStringIdentifierType(uint32_t v) { return identifierTypeName(v); }

std::string brToStringVendorKeyValue(const VendorKeyValue& kv) {
    return "{" + std::string(kv.key.c_str(), kv.key.size()) + ": "
               + std::string(kv.value.c_str(), kv.value.size()) + "}";
}

std::string brToStringProgramSelector(const ProgramSelector& sel) {
    std::string out = "{";
    out += programTypeName(sel.programType);
    out += ", ";
    out += identifierTypeName(sel.primaryId.type);
    out += ": ";
    out += std::to_string(sel.primaryId.value);
    for (size_t i = 0; i < sel.secondaryIds.size(); ++i) {
        const auto& id = sel.secondaryIds[i];
        out += ", ";
        out += identifierTypeName(id.type);
        out += ": ";
        out += std::to_string(id.value);
    }
    out += "}";
    return out;
}

bool brEqAm(const AmBandConfig& a, const AmBandConfig& b) {
    return a.stereo == b.stereo;
}

bool brEqFm(const FmBandConfig& a, const FmBandConfig& b) {
    return a.deemphasis == b.deemphasis && a.stereo == b.stereo &&
           a.rds == b.rds && a.ta == b.ta && a.af == b.af && a.ea == b.ea;
}
