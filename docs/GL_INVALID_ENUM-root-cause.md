# SystemUI RenderThread `GL_INVALID_ENUM` — root cause

**Status:** root cause established from 50 tombstones, LineageOS 17.1 Skia/HWUI
sources, and disassembly of the stock PowerVR driver. The fix is committed
(`d4da4a4`) but **not yet built or flashed** — no CI build was triggered.

## Symptom

* All 50 tombstones in `/mnt/d/tombstones` are `com.android.systemui`, thread
  `RenderThread`, SIGABRT.
* Abort message is identical in all of them:
  `GL errors! frameworks/base/libs/hwui/pipeline/skia/SkiaOpenGLPipeline.cpp:126`.
* Backtraces are byte-identical:
  `abort` → `__android_log_assert` → `SkiaOpenGLPipeline::swapBuffers+172` →
  `CanvasContext::draw+320` → `DrawFrameTask` → `WorkQueue::process` →
  `RenderThread::threadLoop`.
* The only GL-related log line before the fatal is
  `E OpenGLRenderer: GL error:  GL_INVALID_ENUM`.

## Where the abort comes from

`libs/hwui/Debug.h` defaults `DEBUG_OPENGL` to `DEBUG_LEVEL_LOW` on userdebug
builds. `GL_CHECKPOINT(LOW)` is the **first statement** of
`SkiaOpenGLPipeline::swapBuffers()` and expands to
`LOG_ALWAYS_FATAL_IF(GLUtils::dumpGLErrors(), ...)`. Therefore the invalid call
is **not** in the swap — the error is latched during the preceding
`renderFrame()` and merely detected at the swap checkpoint.

## Tombstone timeline (`tombstone_00`, representative)

| Time | Thread | Event |
| --- | --- | --- |
| 00:22:50.833 | 4486 (RenderThread) | `I OpenGLRenderer: Davey! duration=921ms` — previous frame succeeded |
| 00:22:50.943 | 4453 (main) | `W Gralloc3: allocator 3.x is not supported` — `GraphicBuffer` allocation on the main thread |
| 00:22:50.987 | 4486 (RenderThread) | `E OpenGLRenderer: GL error:  GL_INVALID_ENUM` |
| 00:22:50.987 | 4486 (RenderThread) | `F OpenGLRenderer: GL errors! ...SkiaOpenGLPipeline.cpp:126` → abort |

29 of 50 tombstones have exactly this three-line tail; the rest add only
StatusBar/ImageWallpaper lines from other threads.

Ruling out red herrings in the same tail:

* `ImageWallpaper` draws on its own GL thread (tid 4499) through
  `ImageGLWallpaper`/raw GLES, not through the HWUI RenderThread. Its lines are
  coincidental in time.
* `W Gralloc3: allocator 3.x is not supported` is the normal gralloc3→gralloc2
  fallback; the allocation it accompanies is the relevant event, not the warning.
* The main thread at crash is in `RenderProxy::setStopped` ←
  `HardwareRenderer.setStopped` ← `ViewRootImpl.performDraw+1232`, i.e. the normal
  post-draw sync, not a teardown trigger.
* Early `E ion: ioctl c0044901 failed ... EINVAL` (`ION_IOC_FREE`) is init noise,
  long before the failing frame.

## The failing call chain

1. `GrGLCaps::init()` sets `fTextureSwizzleSupport = true` for GLES >= 3.0
   (`src/gpu/gl/GrGLCaps.cpp:257,261`). The stock driver reports
   `OpenGL ES 3.2 build 1.9@4971894`, so the flag is on.
2. A hardware-backed bitmap sampled by HWUI is imported as an `AHardwareBuffer`.
   `GrAHardwareBufferImageGenerator` passes `isRenderable=false`, so
   `GrAHardwareBufferUtils::make_gl_backend_texture()` binds it as
   `GL_TEXTURE_EXTERNAL_OES` (`0x8D65`).
3. `GrGLGpu::bindTexture()` then enters its swizzle block, gated **only** on
   `glCaps().textureSwizzleSupport()`, and calls
   `glTexParameteri(target, GL_TEXTURE_SWIZZLE_R/G/B/A, ...)`
   (or `glTexParameteriv(target, GL_TEXTURE_SWIZZLE_RGBA, ...)`). Non-RGBA
   configs (e.g. RGBX, whose alpha swizzle is `GL_ONE`) make this path run.
4. REA of the stock `/vendor/lib64/egl/libGLESv2_mtk.so`
   (SHA-256 `8e846a0186afb469de0823f0a8ddb6ba2d0659d11677341b7ba8b6d431a6bb17`):
   `glTexParameteri` is `FUN_0017abd8`. For target `0x8D65` its switch accepts
   only `0x2800`/`0x2801` (MIN/MAG_FILTER), `0x2802`/`0x2803`/`0x8072`
   (WRAP_S/T/R) and `0x813C` (BASE_LEVEL, value 0). Swizzle pnames
   `0x8E42`..`0x8E45` are accepted for 2D/cube/array/multisample targets only.
   Every other pname falls into `LAB_0017ae9c`, which records
   `GL_INVALID_ENUM` (`0x500`) at `opengles3/tex.c:0x178`.
5. The driver latches the error; the swap checkpoint turns it fatal.

The exact bitmap that first binds an external-OES texture in the failing frame
is deliberately not pinned down: the fix does not depend on it, since any
sampled hardware bitmap follows the same path.

## Why the pushed fix is sufficient

`patches/0001-skia-ignore-vendor-texture-swizzle.patch` (from Andy Yan's
`lineage_patches_unified`, `lineage-17.1`) changes, under `SK_BUILD_FOR_ANDROID`:

```cpp
bool textureSwizzleSupport() const {
    return !GetBoolProperty("ro.skia.ignore_swizzle", false) && fTextureSwizzleSupport;
}
```

With `ro.skia.ignore_swizzle=true` (set in `system.prop`):

* `GrGLGpu::bindTexture()` skips the entire swizzle block, so none of the
  rejected `glTexParameteri(SWIZZLE_*)` calls are made. Skia folds the swizzle
  into the shader instead (`shaderCaps->fConfigTextureSwizzle`).
* Filter/wrap parameters sent to external OES are accepted by the driver.
* `BASE_LEVEL`/`MAX_LEVEL` are already suppressed for external textures on
  Android (`fDontSetBaseOrMaxLevelForExternalTextures = true`,
  `GrGLCaps.cpp:2814`).
* `libskia` is statically linked into `/system/lib64/libhwui.so`; no stock GPU
  blob is replaced and HWUI's GL checks stay enabled for genuine errors.

`SK_BUILD_FOR_ANDROID` is derived from `__ANDROID__` in `SkPreConfig.h`, so the
branch compiles in the device build. The patch adds `libbase` to `libskia` for
`GetBoolProperty`.

## Alternatives rejected

* **Kanged CPH2185 GPU blobs** — different PVR stack/kernel ABI; reverted
  (device `c98d89a`, vendor `4ec6b65`).
* **Full PVR 1.11 replacement** — needs a 4.9.190 kernel BSP port
  (`1.9@4971894` vs `1.11@5425693`).
* **`debug.hwui.renderer=skiavk`** — no vendor Vulkan HAL in the stock dump.
* **Non-fatal `GLUtils::dumpGLErrors()`** — masks every GL error instead of
  avoiding the invalid call; kept as a fallback only.
* **Runtime-only GL workaround** — `GL_CHECKPOINT` is compile-time; no property
  disables it.

## Corroboration and caveats

* A same-device GSI built from Andy Yan/phh sources works with this property
  while carrying the identical fatal checkpoint.
* Tombstones do not record the offending GL call; attribution rests on the
  driver disassembly, the Skia source, and that GSI precedent.
* `Gralloc3`/ion warnings are not the GL error cause.
* Modem/airplane-mode initialization is a separate issue (`mtk.md1.status` stops
  at `bootup`, never `ready`) and is not addressed by this fix.

## Verification still needed

1. Build and flash the tree with `d4da4a4` applied (CI run not triggered yet).
2. Confirm SystemUI no longer restarts and `GL error:  GL_INVALID_ENUM` is
   absent from logcat.
3. Confirm `getprop ro.skia.ignore_swizzle` returns `true`.

## References

* `/mnt/d/tombstones` — 50 SystemUI RenderThread tombstones (primary evidence)
* `/tmp/opencode/rea-gpu-analysis.json` — REA evidence for the stock GLES driver
* `/tmp/opencode/andy-patches/patches/platform_external_skia/0001-GrGLCaps-allow-ignoring-vendor-supplied-texture-swiz.patch`
* `patches/0001-skia-ignore-vendor-texture-swizzle.patch`, `system.prop`,
  `.github/workflows/build.yml` in this tree
