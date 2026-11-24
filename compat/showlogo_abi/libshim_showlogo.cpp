// Compatibility shim for the stock OPPO libshowlogo.so used by kpoc_charger.
//
// The 8.1 blob imports SurfaceFlinger APIs that Android 10 removed or changed.
// Offline charging itself runs in framebuffer mode, so the deprecated display
// operations are only needed to satisfy BIND_NOW; where a safe modern
// equivalent exists we forward to it.

#include <gui/SurfaceComposerClient.h>
#include <gui/SurfaceControl.h>
#include <ui/Rect.h>
#include <utils/Errors.h>
#include <utils/RefBase.h>
#include <utils/StrongPointer.h>

using namespace android;

// Old createSurface(name, w, h, format, flags, SurfaceControl* parent,
//                   uint32_t, uint32_t) -> current overload taking a token.
sp<SurfaceControl> shim_createSurface(SurfaceComposerClient* self, const String8& name,
                                      uint32_t w, uint32_t h, PixelFormat format,
                                      uint32_t flags, SurfaceControl* parent,
                                      uint32_t, uint32_t)
    __asm__("_ZN7android21SurfaceComposerClient13createSurfaceERKNS_7String8EjjijPNS_14SurfaceControlEjj");

sp<SurfaceControl> shim_createSurface(SurfaceComposerClient* self, const String8& name,
                                      uint32_t w, uint32_t h, PixelFormat format,
                                      uint32_t flags, SurfaceControl* parent,
                                      uint32_t, uint32_t) {
    return self->createSurface(name, w, h, format, flags,
                               parent ? parent->getHandle() : nullptr,
                               LayerMetadata{});
}

// getBuiltInDisplay(index) -> current internal display token.
sp<IBinder> shim_getBuiltInDisplay(SurfaceComposerClient* self, int32_t)
    __asm__("_ZN7android21SurfaceComposerClient17getBuiltInDisplayEi");

sp<IBinder> shim_getBuiltInDisplay(SurfaceComposerClient*, int32_t) {
    return SurfaceComposerClient::getInternalDisplayToken();
}

// Deprecated global transaction / display projection calls: no-ops. The
// charger's framebuffer path does not use them.
void shim_openGlobalTransaction(SurfaceComposerClient*)
    __asm__("_ZN7android21SurfaceComposerClient21openGlobalTransactionEv");
void shim_openGlobalTransaction(SurfaceComposerClient*) {}

void shim_closeGlobalTransaction(SurfaceComposerClient*, bool)
    __asm__("_ZN7android21SurfaceComposerClient22closeGlobalTransactionEb");
void shim_closeGlobalTransaction(SurfaceComposerClient*, bool) {}

void shim_setDisplayProjection(SurfaceComposerClient*, const sp<IBinder>&,
                               uint32_t, const Rect&, const Rect&)
    __asm__("_ZN7android21SurfaceComposerClient20setDisplayProjectionERKNS_2spINS_7IBinderEEEjRKNS_4RectES8_");
void shim_setDisplayProjection(SurfaceComposerClient*, const sp<IBinder>&,
                               uint32_t, const Rect&, const Rect&) {}

// Deprecated SurfaceControl mutations: no-ops in framebuffer mode.
void shim_scClear(SurfaceControl*)
    __asm__("_ZN7android14SurfaceControl5clearEv");
void shim_scClear(SurfaceControl*) {}

void shim_scSetLayer(SurfaceControl*, int32_t)
    __asm__("_ZN7android14SurfaceControl8setLayerEi");
void shim_scSetLayer(SurfaceControl*, int32_t) {}

// Fence's destructor became inline; the blob still imports the out-of-line one.
void shim_fenceDtor(Fence*)
    __asm__("_ZN7android5FenceD1Ev");
void shim_fenceDtor(Fence*) {}
