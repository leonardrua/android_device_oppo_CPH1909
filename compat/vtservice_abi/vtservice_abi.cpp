// Compatibility shim for the Android 8.1 MediaSource destructor thunk.
//
// The 8.1 MTK ViLTE libraries (libsource.so, libsink.so,
// libstagefright_wfd_mtk.so, libmtkavenhancements.so) were built when
// MediaSource was a multiple-inheritance base at offset +4, so they import
// the non-virtual thunk _ZThn4_N7android11MediaSourceD0Ev. Android 10's
// libstagefright.so exports the real MediaSource deleting destructor but no
// longer generates that thunk, so BIND_NOW fails and /system/bin/vtservice
// cannot start.
//
// Resolve the real destructor at runtime (it lives in libstagefright, which
// is already loaded in this process) and adjust `this` back by 4 bytes.

#include <dlfcn.h>

// Complete-object destructor thunk: same behaviour as the deleting one on the
// adjusted pointer. libsource.so/libsink.so import this form as well.
extern "C" void _ZThn4_N7android11MediaSourceD1Ev(void* self) {
    extern void _ZThn4_N7android11MediaSourceD0Ev(void*);
    _ZThn4_N7android11MediaSourceD0Ev(self);
}

extern "C" void _ZThn4_N7android11MediaSourceD0Ev(void* self) {
    using DeleteDtor = void (*)(void*);
    static DeleteDtor real = reinterpret_cast<DeleteDtor>(
            dlsym(RTLD_DEFAULT, "_ZN7android11MediaSourceD0Ev"));
    if (real != nullptr) {
        real(static_cast<char*>(self) - 4);
    }
}

// Android 10 removed these two debug/trace helpers from libutils/libcutils;
// the kanged MT6765 ViLTE stack imports them. They only report an sp<> misuse
// or return the enabled atrace tag mask, so no-ops are safe.

extern "C" void _ZN7android23sp_report_stack_pointerEv() {}

extern "C" unsigned long long atrace_get_enabled_tags() {
    return 0;  // tracing disabled
}
