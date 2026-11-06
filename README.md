# OPPO A5s (CPH1909) device tree — LineageOS 17.1

Device tree for the OPPO A5s / CPH1909 (MediaTek MT6765, Helio P35), ported from
the stock Android 8.1 / API 27 vendor image to LineageOS 17.1 (Android 10).

The device is **A-only**, **non-system-as-root**, and **legacy Treble**:

* A-only — one system/vendor slot; no `slotselect`, `AB_OTA_UPDATER`, or A/B
  boot control.
* Non-system-as-root — the boot image still carries a ramdisk and
  `BOARD_BUILD_SYSTEM_ROOT_IMAGE` is unset. Android 10 nevertheless builds
  `system.img` in the system-as-root layout; first-stage init mounts it at
  `/system` and pivots to it.
* Legacy Treble — the vendor image is O-MR1 (API 27, FCM level 2), so the build
  uses VNDK-lite and the device manifest declares `target-level="2"`.

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

### Boot, system-as-root and first-stage mount

This is a non-system-as-root device, but Android 10 always builds `system.img`
in the system-as-root layout: `build_image.py` merges the root directory into the
system image and mounts the result at `/`. For this device the boot image still
carries a ramdisk (`BOARD_BUILD_SYSTEM_ROOT_IMAGE` is intentionally unset), so
the kernel starts `init_first_stage` from the ramdisk and the system image is
mounted later.

First-stage init does not read this tree's `fstab.mt6765`.
`ReadFirstStageFstab()` first calls `ReadFstabFromDt()`, and the kernel DT
contains a `firmware/android/fstab` node in
`arch/arm64/boot/dts/mediatek/mt6765.dts`. That node always lists `/system` and
`/vendor` (`/odm` is inside `#if 0`); with `CONFIG_MTK_DM_VERITY_OFF=y`, which
`oppo6765_18511_defconfig` sets, their flags are just `wait` — no `verify`, no
`avb`, and no `first_stage_mount` requirement. `TrySwitchSystemAsRoot()` sees
the `/system` entry, mounts it, and calls `SwitchRoot("/system")`; the remaining
entries (the DT `/vendor` node) are mounted immediately afterwards from the new
root. From that point on the system image is the root filesystem and
second-stage `/system/bin/init` runs.

The fstab in `rootdir/etc/fstab.mt6765` is therefore not the first-stage fstab.
It is installed only at `/vendor/etc/fstab.mt6765`, where the stock
`init.mt6765.rc` runs `mount_all` from its `on fs` block, and it is also the
recovery fstab (`TARGET_RECOVERY_FSTAB`). Its `/system`, `/vendor`, and `/odm`
lines keep the stock `wait,recoveryonly` flags: `recoveryonly` keeps them out of
the normal second-stage `mount_all` (they are already mounted or intentionally
unused) while still letting recovery mount them. There is no `first_stage_mount`
flag and no ramdisk copy of the file.

There is no `/odm` mount in normal boot. The scatter defines a 256 MiB `odm`
partition, but the factory image leaves it zeroed (no ext4 superblock);
`recoveryonly` matches stock and means the boot never tries to mount it. Nothing
on the device uses it.

The A-only layout is reflected by the absence of `slotselect` flags, the
separate `recovery` partition, and `BOARD_AVB_ENABLE := false` (the device has no
`vbmeta` partition and the bootloader is locked to OPPO's keys).

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
`on fs` block. `fs_mgr_mount_all()` skips `recoveryonly` entries, so
system/vendor/odm stay out of the second stage, and mounts the remaining
partitions (data, cache, protect_f, protect_s, nvdata, nvcfg, persist,
opporeserve) as before.

### Vendor partition and VNDK

`TARGET_COPY_OUT_VENDOR := vendor` (required by build/make whenever
`BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE` is set) keeps the separate vendor image.

`BOARD_VNDK_VERSION` is deliberately left unset. Because
`PRODUCT_SHIPPING_API_LEVEL` is 27, `PRODUCT_USE_VNDK` stays false
(`core/config.mk` only defaults `BOARD_VNDK_VERSION` to `"current"` for API
28+), so this is the legacy-Treble VNDK-lite configuration rather than VNDK
enforcement. With the variable unset the build sets `ro.vndk.lite=true`, so the
linker uses `ld.config.vndk_lite.txt`: vendor binaries can resolve libraries
from `/system/lib[64]` directly, not only from the vndk/vndk-sp
subdirectories. The 8.1 blobs therefore link against the Android 10 system
libraries, which are VNDK forward-compatible with the API 27 versions the blobs
were built against.

`PRODUCT_EXTRA_VNDK_VERSIONS` is intentionally not used. The
`vndk_snapshot_package` phony that installs an older snapshot is only defined
when `BOARD_VNDK_VERSION` is set
(`build/make/target/product/gsi/Android.mk`), so the variable would silently
install nothing on this VNDK-lite build.

### SELinux

`sepolicy/vendor/` labels the MediaTek and OPPO vendor binaries that AOSP does
not label. The stock 8.1 precompiled policy is excluded from
`proprietary-files.txt`; loading an 8.1 policy on Android 10 is a hard boot
failure, not a compatibility question.

Most vendor domains are `permissive` during bring-up, following the convention
in the policy file. Convert the denials they log into rules and remove the
`permissive` lines before shipping.

### VINTF

`manifest.xml` is the stock CPH1909 device manifest plus the HALs LineageOS
builds because Android 10 requires them: `health@2.0`, `usb@1.0` and the
`drm@1.2` clearkey instance. It declares `target-level="2"`.

This is the key legacy-Treble setting. Android 10 replaced the old
`PRODUCT_COMPATIBILITY_MATRIX_LEVEL_OVERRIDE` with the `target-level` attribute
on the device manifest. API 27 corresponds to FCM level 2 (O-MR1), so the Q
framework validates the vendor HALs against the frozen O-MR1 compatibility
matrix. `assemble_vintf` would infer level 2 from
`PRODUCT_SHIPPING_API_LEVEL=27` even without the attribute, but only after
printing a warning. All ten HALs that FCM 2 marks as required are present in
this manifest. The stock 8.1 `compatibility_matrix.xml` (the vendor's device
matrix) is **not** shipped: it describes the 8.1 framework and would reject
Android 10.

`android.hardware.cas` is *not* listed: `base_vendor.mk` always builds
`android.hardware.cas@1.1-service`, which ships its own VINTF fragment, and a
second entry for the same HAL name and major version is rejected by
`assemble_vintf`.

The stock 8.1 `cas@1.0-service` daemon is likewise dropped in favour of the
AOSP 1.1 service (`@1.1::IMediaCasService` extends `@1.0`).

### Keymaster and gatekeeper HAL modules

Android locates a HAL implementation with `hw_get_module_by_class()`, which
tries `"<class>.<ro.hardware>.so"` before falling back to `"<class>.default.so"`.
With `ro.hardware=mt6765` that means `keystore.mt6765.so` and
`gatekeeper.mt6765.so`. The vendor image carries no symlinks and ships the
MediaTek TEE modules under their own names, so the loader could not find either
one and both services came up in a degraded mode — keymaster printed "Could not
find any keystore module, using software-only implementation." and gatekeeper
failed to open at all.

`Android.mk` installs the names the loader expects as symlinks next to the
blobs:

| module name             | target                 |
| ----------------------- | ---------------------- |
| `keystore.mt6765.so`    | `libMcTeeKeymaster.so` |
| `gatekeeper.mt6765.so`  | `libMcGatekeeper.so`   |
| `gatekeeper.default.so` | `libSoftGatekeeper.so` |

`kmsetkey` needs no alias: `ro.hardware.kmsetkey=trustonic` in `vendor.prop`
makes the loader open the shipped `kmsetkey.trustonic.so` directly.

### Resource overlay

`DEVICE_PACKAGE_OVERLAYS` points at `overlay/`, which holds two resource
overlays for `frameworks/base/core/res`:

* `res/xml/power_profile.xml` — the energy-use model BatteryStats needs. AOSP
  ships only deliberately bogus placeholder values there, so without it every
  battery statistic is meaningless. It describes the Helio P35's two clusters
  (4x2.3 GHz and 4x1.8 GHz, matching the clock frequencies in the kernel DT)
  and the 4230 mAh battery.
* `res/values/config.xml` — the brightness and wired-headset fixes described
  below. These are framework resources, so they cannot come from the vendor
  blobs; the values are the stock CPH1909 ones extracted from the stock
  `framework-res.apk`.

**Brightness / auto-brightness.** AOSP 10 ships empty
`config_autoBrightnessLevels` and `config_autoBrightnessLcdBacklightValues`
arrays, which makes `BrightnessMappingStrategy.create()` return null. No
`AutomaticBrightnessController` is then created, so auto-brightness is
unavailable and manual brightness has no device curve. The overlay supplies the
stock lux thresholds (`45, 1025, 1480, 2250, 3300, 10000`), the matching
backlight levels (`8, 22, 48, 78, 128, 206, 255`), the stock debounce/sampling
values and `config_automatic_brightness_available=true`. The vendor side was
already complete: `lights.mt6765.so` writes
`/sys/class/leds/lcd-backlight/brightness`, which the MT6765 LEDs driver
exposes.

**Wired headset detection.** The MTK ACCDET driver
(`CONFIG_MTK_PMIC_CHIP_MT6357`) reports `SW_HEADPHONE_INSERT` /
`SW_MICROPHONE_INSERT` through the Linux input subsystem, not through the
legacy `/sys/class/switch/h2w` uevent path. AOSP defaults
`config_useDevInputEventForAudioJack` to false, so the framework never saw
headset insertion; the stock ROM sets it true, and so does the overlay.

### Input key layouts

AOSP 10 ships neither the MediaTek accessory-detect headset-button map
(`ACCDET.kl`) nor its keypad map (`mtk-kpd.kl`). Without them the wired headset
buttons (hook, media transport, `VOICE_ASSIST`) and the `mtk-kpd` key map fall
back to `Generic.kl`. The stock files are copied unchanged into
`/system/usr/keylayout/` through `PRODUCT_COPY_FILES`.

### Properties

* `system.prop` holds the framework-side values from the stock system build
  (density, radio library names, Wi-Fi interfaces, the MediaTek Wi-Fi feature
  gates `ro.mediatek.wlan.{wsc,p2p}`/`mediatek.wlan.ctia`, the camera
  shutter-sound policy, and the `ro.mtk_perf_*` start-window/response-time
  performance hints).
* `vendor.prop` holds the subset of the stock vendor build.prop that the
  prebuilt MediaTek/OPPO blobs and their rc files read. Besides the platform
  identification block this includes the ART heap sizing
  (`dalvik.vm.heapgrowthlimit=384m`, `dalvik.vm.heapsize=512m`), the Dirac audio
  and FM-radio enables, the modem/CCCI and WCN connectivity values, and the AVRCP
  single-player setting. In particular `ro.hardware.egl=mtk` is required: the
  Android 10 EGL loader appends `ro.hardware.egl` (then `ro.board.platform`) to
  `libEGL_`, and this device's PowerVR blobs are `libEGL_mtk.so`. Without it the
  loader looks for the non-existent `libEGL_mt6765` and SurfaceFlinger never
  starts.

The ColorOS-only values (`ro.com.google.gmsversion`, `ro.setupwizard.*`,
`pm.dexopt.*`, the `persist.log.tag.*` block and the `ro.mtk_*` feature switches
that no prebuilt blob consults) are deliberately dropped.

### Not taken from the stock dump

The stock ROM also carries system-side, device-specific files that this build has
no use for, so they are intentionally neither extracted nor copied:

* `system/etc/bluetooth/` — AOSP's own Bluetooth stack installs the generic
  `bt_stack.conf` and `bt_did.conf` into `/system/etc/bluetooth/`, and this build
  uses that stack. The remaining stock files there (`mtk_bt_stack.conf`,
  `mtk_bt_fw.conf`, `bt_mtk_iot_list.conf`, `profile_version.conf`) are read only
  by MediaTek's patched `bluetooth.default.so`, which is not shipped. Device
  tuning goes through `bluetooth/bdroid_buildcfg.h` instead.
* `vendor/etc/fs_config_files` sets the two MTK HAL binaries to be owned by the
  `audioserver`/`bluetooth` accounts. On Android 10 the file ownership comes from
  the generated `fs_config` and the process credentials come from the `user`
  directive in each HAL's `.rc`, so the stock override is not needed.

### Encryption

The device ships full-disk encryption with the key blob on the `metadata`
partition, backed by the Trustonic TEE — not file-based encryption. The stock ROM
used `forceencrypt=`; this port deliberately uses `encryptable=` instead, so an
already-encrypted /data is decrypted through the metadata key while an
unencrypted /data is mounted as-is rather than triggering in-place encryption on
first boot. `BOARD_USES_METADATA_PARTITION := true` creates `/metadata`.

### Other build changes

* `BUILD_BROKEN_DUP_RULES := true` — the blob set and AOSP both install several
  of the same paths (the 8.1 HAL services AOSP 10 replaces); the blob wins Make
  parse order, which is what we want for the MediaTek binaries.
* `BOARD_AVB_ENABLE := false` — the bootloader is locked to OPPO keys and this
  build is not signed by them; the device has no vbmeta partition.
* `VENDOR_SECURITY_PATCH := 2021-04-05` — the stock system build.prop's
  `ro.build.version.security_patch`, so `ro.vendor.build.security_patch` reports
  the real level of the frozen 8.1 vendor blobs.
* `androidboot.init_fatal_reboot_target=recovery` — a fatal init failure
  reboots into recovery instead of hanging at the boot logo.
* `BUILD_BROKEN_DUP_RULES` and the duplicate-path decision are described in
  `BoardConfig.mk` next to the assignment.

## Known limitations / porting notes

* Fingerprint and face unlock use OPPO/Silead vendor packages rather than the
  AOSP `android.hardware.biometrics.fingerprint@2.1` service, so the framework
  biometric stack will not drive them without a shim.
* The 8.1 vendor blobs are the highest-risk part of the port. If HIDL services
  fail to load, check `ro.hardware` / `ro.hardware.egl` and the linker denials
  first; the build is VNDK-lite, so vendor binaries may resolve libraries from
  `/system/lib[64]` as described above.
* Recovery: `TARGET_RECOVERY_FSTAB` points at the same fstab. The TWRP tree for
  this device is a separate branch and is not built from this one.
