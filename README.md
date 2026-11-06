# OPPO A5s (CPH1909) device tree — LineageOS 17.1

Device tree for the OPPO A5s / CPH1909 (MediaTek MT6765, Helio P35), ported from
the stock Android 8.1 / API 27 vendor image to LineageOS 17.1 (Android 10).

The hardware values (partition sizes, kernel base and offsets, MT6765 platform,
fstab partition layout) are carried over unchanged from the stock device tree.
Everything that had to change for Android 10 is listed below.

## Building

Clone this repository into `device/oppo/CPH1909` in a LineageOS 17.1 checkout,
put the kernel source at `kernel/oppo/CPH1909`, then:

```sh
source build/envsetup.sh
lunch lineage_CPH1909-userdebug
mka bacon
```

Lunch choices are declared through `COMMON_LUNCH_CHOICES` in
`AndroidProducts.mk`; there is no `add_lunch_combo` any more (it is obsolete in
Android 10 and only prints a warning).

### Kernel

The tree builds the kernel from `kernel/oppo/CPH1909` with
`oppo6765_18511_defconfig`. That is a 4.9 MediaTek kernel with OPPO's
`VENDOR_EDIT` patches, so it is built with GCC 4.9:

```make
TARGET_KERNEL_CLANG_COMPILE := false
```

`TARGET_KERNEL_CROSS_COMPILE_PREFIX` must not be set: LineageOS's
`BoardConfigKernel.mk` treats it as an either/or against `KERNEL_TOOLCHAIN`, and
setting it leaves `KERNEL_TOOLCHAIN` empty so the GCC bin directory never enters
`PATH`.

## Extracting the vendor blobs

The vendor partition is not in this repository. From a dump of the matching
CPH1909 stock firmware:

```sh
device/oppo/CPH1909/extract-files.sh /path/to/rom-dump
```

The source must contain a `vendor/` directory (or be that directory). The script
copies every path in `proprietary-files.txt` to
`vendor/oppo/CPH1909/proprietary/` and generates
`vendor/oppo/CPH1909/CPH1909-vendor.mk`, which `device.mk` includes.

Entries that exist on the stock 8.1 vendor partition but must not be copied are
documented at the top of `proprietary-files.txt` (VINTF data, the 8.1 SELinux
policy, mkshrc, and the generated `public.libraries.txt` /`fs_config*` files).

## What changed for Android 10

### System-as-root and first-stage mount

Android 10 always ends up with the system image as the root filesystem. This
device's bootloader expects a legacy boot image with a ramdisk, i.e.
`BOARD_BUILD_SYSTEM_ROOT_IMAGE` stays unset, so the kernel starts
`/init` from the boot ramdisk. That `/init` is `init_first_stage`, which:

1. finds its fstab at `/fstab.<ro.boot.hardware>` (there is no /vendor yet),
2. mounts the entries tagged `first_stage_mount`,
3. switches root to `/system` and execs `/system/bin/init`.

Therefore:

* `BOARD_KERNEL_CMDLINE` carries `androidboot.hardware=mt6765`, which is what
  makes `ro.boot.hardware` / `ro.hardware` equal `mt6765`;
* `rootdir/etc/fstab.mt6765` tags `/system` and `/vendor` with
  `first_stage_mount`, and
* `device.mk` installs the same fstab both at `/vendor/etc/fstab.mt6765` and at
  `/fstab.mt6765` in the boot ramdisk.

The kernel's own device tree also contains a `firmware/android/fstab` node
(`arch/arm64/boot/dts/mediatek/mt6765.dts`). With
`CONFIG_MTK_DM_VERITY_OFF=y` — which is set in `oppo6765_18511_defconfig` — its
entries are plain `wait` (no `verify`, no `avb`), so first-stage init can mount
them directly. `ReadFirstStageFstab()` prefers the DT fstab when it exists, so
the ramdisk copy is the fallback for configs where it does not.

There is deliberately **no `/odm` entry**. The scatter defines a 256 MiB `odm`
partition, but the factory image leaves it entirely zeroed (no ext4 superblock),
so mounting it in first stage would fail and abort the boot. Nothing on the
device uses it; the stock 8.1 fstab marked it `recoveryonly` for the same reason.

### MediaTek init scripts

`androidboot.hardware=mt6765` also makes init import the stock
`/vendor/etc/init/hw/init.mt6765.rc` from AOSP's `rootdir/init.rc`:

```sh
import /vendor/etc/init/hw/init.${ro.hardware}.rc
```

That file in turn builds several of its own imports out of `${ro.mtkrc.path}`,
so `ro.mtkrc.path=/vendor/etc/init/hw/` is set through
`PRODUCT_DEFAULT_PROPERTY_OVERRIDES`, and
`BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true` puts it in
`/vendor/default.prop`, which init loads before parsing the boot scripts. With
the property unset those imports expand to `/init.connectivity.rc` and friends,
fail silently, and the device hangs at the logo with no modem, sensors or
connectivity services.

The stock `init.mt6765.rc` starts `swap_enable_init`, a oneshot service that
runs `/system/etc/swap_enable.sh` with the `rutilsdaemon` seclabel. That script
lives on the system partition and is therefore not part of the blob extraction,
so `rootdir/bin/swap_enable.sh` supplies it. It is a rewrite of the stock
script: the OPPO-private `direct_swappiness` and `almk_swap_ratio1` nodes do not
exist in this kernel (userspace lmkd replaced the in-kernel lowmemorykiller),
and every write is guarded so a missing node cannot leave zram half-configured.

The stock `init.mt6765.rc` also runs `mount_all /vendor/etc/fstab.mt6765` in its
`on fs` block. Entries that were already mounted by first-stage init are skipped
by `fs_mgr_mount_all()`, so the remaining partitions (data, cache, protect_f,
protect_s, nvdata, nvcfg, persist, opporeserve) are mounted there as before.

### Vendor partition and VNDK

`TARGET_COPY_OUT_VENDOR := vendor` (required by build/make whenever
`BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE` is set) keeps the separate vendor image.

`BOARD_VNDK_VERSION` is deliberately left unset. The build system only accepts
"current" for it, and that would impose VNDK linkage rules on every vendor
module built from source. With it unset the build sets `ro.vndk.lite=true`, so
the linker uses `ld.config.vndk_lite.txt`: that configuration allows vendor
binaries to resolve libraries from `/system/lib[64]` directly, not only from the
vndk/vndk-sp subdirectories. The 8.1 blobs therefore link against the Android 10
system libraries, which are VNDK forward-compatible with the API 27 versions the
blobs were built against.

`PRODUCT_EXTRA_VNDK_VERSIONS` is intentionally not used. The `vndk_snapshot_package`
phony that installs an older snapshot is only defined when
`BOARD_VNDK_VERSION` is set (`build/make/target/product/gsi/Android.mk`), so the
variable would silently install nothing on this non-VNDK build.

### SELinux

`sepolicy/vendor/` labels the MediaTek and OPPO vendor binaries that AOSP does
not label. The stock 8.1 precompiled policy is excluded from
`proprietary-files.txt`; loading an 8.1 policy on Android 10 is a hard boot
failure, not a compatibility question.

Most vendor domains are `permissive` during bring-up, following the convention
in the policy file. Convert the denials they log into rules and remove the
`permissive` lines before shipping.

### VINTF

`manifest.xml` is the stock CPH1909 device manifest with `target-level` removed
(an 8.1 vendor image cannot honestly claim an FCM level), plus the HALs
LineageOS builds because Android 10 requires them: `health@2.0`, `usb@1.0` and
the `drm@1.2` clearkey instance.

`android.hardware.cas` is *not* listed: `base_vendor.mk` always builds
`android.hardware.cas@1.1-service`, which ships its own VINTF fragment, and a
second entry for the same HAL name and major version is rejected by
`assemble_vintf`.

The stock 8.1 `cas@1.0-service` daemon is likewise dropped in favour of the
AOSP 1.1 service (`@1.1::IMediaCasService` extends `@1.0`).

### Properties

* `system.prop` holds the framework-side values from the stock system build
  (density, radio library names, Wi-Fi interfaces).
* `vendor.prop` holds the subset of the stock vendor build.prop that the
  prebuilt MediaTek/OPPO blobs and their rc files read. In particular
  `ro.hardware.egl=mtk` is required: the Android 10 EGL loader appends
  `ro.hardware.egl` (then `ro.board.platform`) to `libEGL_`, and this device's
  PowerVR blobs are `libEGL_mtk.so`. Without it the loader looks for the
  non-existent `libEGL_mt6765` and SurfaceFlinger never starts.

### Encryption

The device ships full-disk encryption (`forceencrypt=`) with the key blob on the
`metadata` partition, backed by the Trustonic TEE — not file-based encryption.
The fstab keeps `forceencrypt=` exactly as the stock ROM had it;
`BOARD_USES_METADATA_PARTITION := true` creates `/metadata`.

### Other build changes

* `BUILD_BROKEN_DUP_RULES := true` — the blob set and AOSP both install several
  of the same paths (the 8.1 HAL services AOSP 10 replaces); the blob wins Make
  parse order, which is what we want for the MediaTek binaries.
* `BOARD_AVB_ENABLE := false` — the bootloader is locked to OPPO keys and this
  build is not signed by them; the device has no vbmeta partition.
* `BUILD_BROKEN_DUP_RULES` and the duplicate-path decision are described in
  `BoardConfig.mk` next to the assignment.

## Known limitations / porting notes

* Fingerprint and face unlock use OPPO/Silead vendor packages rather than the
  AOSP `android.hardware.biometrics.fingerprint@2.1` service, so the framework
  biometric stack will not drive them without a shim.
* The 8.1 vendor blobs are the highest-risk part of the port. If HIDL services
  fail to load, check `ro.hardware` / `ro.hardware.egl` and the linker denials
  first; the build is non-VNDK, so vendor binaries may resolve libraries from
  `/system/lib[64]` as described above.
* Recovery: `TARGET_RECOVERY_FSTAB` points at the same fstab. The TWRP tree for
  this device is a separate branch and is not built from this one.
