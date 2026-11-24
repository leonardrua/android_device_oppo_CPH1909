// Compatibility shim for android::HidlUtils::audioConfigToHal.
//
// The 8.1 vendor audio@2.0 HAL imports this helper. In LineageOS 17.1 it lives
// in /system/lib/libaudiohal@2.0.so, which is not reachable from the vendor
// namespace (and its dependency closure is system-only), so BIND_NOW fails
// with "cannot locate symbol". The helper only overwrites the caller's
// audio_config_t with the HAL's suggested config; leaving the caller's
// requested config intact is a safe bring-up fallback.

extern "C" void
_ZN7android9HidlUtils16audioConfigToHalERKNS_8hardware5audio6common4V2_011AudioConfigEP12audio_config(
        const void* suggestedConfig, void* halConfig) {
    (void)suggestedConfig;
    (void)halConfig;
}
