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
then:

```sh
source build/envsetup.sh
lunch lineage_CPH1909-userdebug
mka bacon
```

Lunch choices are declared through `COMMON_LUNCH_CHOICES` in
`AndroidProducts.mk`; there is no `add_lunch_combo` any more (it is obsolete in
Android 10 and only prints a warning).

Automated CI builds are covered under
[`## CI workflows`](#ci-workflows) below; the `build.yml` workflow also has a
`target` dispatch input so `bootimage` / `vendorimage` / `productimage` /
`systemimage` can be produced in place of `bacon`.

### Kernel

This tree **builds the kernel from source** — there is no prebuilt kernel image
in the repository. `TARGET_KERNEL_SOURCE := kernel/oppo/CPH1909` and
`TARGET_KERNEL_CONFIG := oppo6765_18511_defconfig` (plus
`TARGET_KERNEL_ARCH := arm64` and `BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb`),
so the build compiles the 4.9 MediaTek/OPPO `VENDOR_EDIT` kernel
(`oppo6765_18511_defconfig`, `CONFIG_OPPO_KTV_DEV=y`, etc.) and packs
`Image.gz-dtb` itself.

`TARGET_PREBUILT_KERNEL` is deliberately never set: the tree carries no kernel
image, and LineageOS clears `TARGET_KERNEL_SOURCE` when it is — which would
also break the `generated_kernel_includes` Soong module, since that runs
`make -C $(TARGET_KERNEL_SOURCE) ... headers_install` for modules that depend
on `generated_kernel_headers`. Keeping a real kernel source tree at
`kernel/oppo/CPH1909` is therefore required both for the image and for the
headers.

The CI build workflow clones `leonardrua/A5S-8.1-kernel-source` into that
path, with the GCC Linaro 6.3.1 + Python 2 toolchain and on-the-fly warning
fixes (see [`## CI workflows`](#ci-workflows)). On a local build, check out
the same tree at `kernel/oppo/CPH1909` relative to the LineageOS source root
before lunching.

The source tree is version `4.9.80` (`CONFIG_LOCALVERSION=""`), while the
stock vendor image ships seven 4.9.77+ kernel modules — `wmt_drv.ko`,
`wmt_chrdev_wifi.ko`, `wlan_drv_gen4m.ko`, `bt_drv.ko`, `gps_drv.ko`,
`fmradio_drv.ko` and `met.ko` in `/vendor/lib/modules/`, loaded by
`init.wmt_drv.rc` / `init.wlan_drv.rc` / `init.bt_drv.rc` / `init.gps_drv.rc`
/ `init.fmradio_drv.rc` — all built with `CONFIG_MODVERSIONS=y`. That mix has
been verified to work: a kernel built from this source boots on the stock
vendor image and the stock modules load at boot.

Why the version mismatch is not a problem, for the record:

* `same_magic()` in the tree's `kernel/module.c` skips the kernel release
  (`4.9.80` vs `4.9.77+`) whenever the module carries a `__versions`
  (`modversions`) section, which all of the stock modules do. Only the flags
  after it — `SMP preempt mod_unload modversions aarch64` — are compared, and
  those match the source config.
* `check_modinfo()`'s `return -ENOEXEC` after the version-magic `pr_err` is
  commented out in this tree, so even a trailing vermagic mismatch only logs.
* What still matters is the modversions CRC check in `check_version()`, which
  resolves against the running kernel's exported-symbol CRCs. The MediaTek
  driver ABI is shared between the two trees, so the modules resolve — which
  is the part the boot test proves and static analysis could not.

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

Lines in `proprietary-files.txt` of the form `path|sha1` pin the SHA-1 of the
extracted blob so a stale or corrupted extraction fails the build early.
`update-sha1sums.sh` refreshes those pins against the current blobs in
`vendor/oppo/CPH1909/proprietary/` (it rewrites every `path|sha1` line with a
fresh `sha1sum`), so it can be run after a vendor re-extract instead of editing
the hashes by hand.

## CI workflows

The repository also contains two GitHub Actions workflows.

### `build.yml` — Namespace build

`Build LineageOS 17.1 (Oppo A5s CPH1909) - Namespace` is a manual
(`workflow_dispatch`) build workflow that runs on the user-provisioned
`namespace-profile-leonard` runner and writes its `out/` tree to the
persistent `/cache` disk so that consecutive runs reuse ccache and
intermediates. Its main characteristics:

* Syncs the LineageOS 17.1 source with `repo`, then clones the device and
  vendor trees and a source kernel tree
  (`leonardrua/A5S-8.1-kernel-source`) into
  `kernel/oppo/CPH1909`. The kernel image is built from this source tree
  (`TARGET_KERNEL_SOURCE`/`TARGET_KERNEL_CONFIG`, no prebuilt image in the
  device tree); the tree is additionally
  patched on the fly to keep warnings non-fatal.
* The AArch64 UAPI header guard step (`Guard AArch64 signal context header
  for ARM builds`) wraps `struct fpsimd_context` in
  `arch/arm64/include/uapi/asm/sigcontext.h` with `#ifdef __aarch64__` so
  32-bit targets can compile against it. This corresponds to commit
  `ac03987` in the kernel repository. The step is also responsible for the
  "keep kernel warnings non-fatal" tweak: `scripts/Makefile.lib` gets
  `-Wno-error` appended to the standard C-flags line, so the large MTK
  kernel (which is full of arch-specific warnings) still builds.
* Before the build starts it verifies the Git LFS artifact
  `external/chromium-webview/prebuilt/arm64/webview.apk`. If the file is a
  small LFS pointer (typical: 134 bytes, not the ~260 MB real APK) it runs
  `git lfs pull` to materialise the real ZIP, then fails fast if the file is
  still not a ZIP. This protects the run from the
  `//external/chromium-webview:webview` `veridex` / `aapt2`
  "failed opening zip: Invalid file" failure observed at ~99 % on the first
  CI build (around `110688/111307`).
* Builds with `lunch lineage_CPH1909-<type>` and `mka <target>`. The job
  exposes `target`, `build_type`, `build_timeout_min`, `out_on_cache` and
  `clean_out` dispatch inputs. `OUT_DIR`/`OUT_BASE` live on `/cache` when
  the runner provides it, otherwise the workspace is used.
* After the build the `Collect output` step packages the images, the
  `lineage-*.zip` OTA, `build-tail.log` and, when non-empty, `error.log`
  into a `result/` folder, which is uploaded as a workflow artifact named
  `lineage-17.1-<device>-<target>` (default target `bacon` →
  `lineage-17.1-CPH1909-bacon`).

Because the runner blocks `swapon` and `zram` and clears `/cache` between
runs, the workflow does **not** try to create its own swap. Rely on the
runner-level swap instead; the build just reports what `free -h` sees.

### `publish.yml` — optional publishing

`Publish build artifacts (optional)` is a second, purely manual
(`workflow_dispatch`) workflow that takes the artifact produced by a
successful `build.yml` run and turns it into a GitHub draft pre-release of
the device repository. It:

* Defaults to the latest successful `Build LineageOS 17.1` run but accepts
  an explicit `run_id`.
* Defaults to the `lineage-17.1-CPH1909-bacon` artifact (or
  `lineage-17.1-CPH1909-<target>`).
* Downloads the artifact into `published/`, **deletes any zero-byte files**
  (GitHub release assets must be at least 1 byte — the empty `error.log`
  that produced `{"resource":"ReleaseAsset","code":"custom","field":"size",
  "message":"size must be greater than or equal to 1"}` on the first
  release attempt is filtered out here), then recomputes the list of
  release assets from the remaining non-empty files and writes a
  `SHA256SUMS` alongside them.
* Creates the release with `softprops/action-gh-release` using an explicit
  file list, with `draft` and `prerelease` both on by default; publish only
  happens when the workflow is explicitly triggered.

`recovery-build.yml` (legacy TWRP recovery build) and `ci.yml` (device
tree integrity validation) are unchanged by the recent CI work.

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
opporeserve) as before. The vendor image is assembled from the extracted
blobs, so `Android.mk` also creates the empty
`/vendor/{protect_f,protect_s,nvdata,nvcfg,persist}` mount point directories;
`init.mt6765.rc` and `fs_mgr` would `mkdir()` them at runtime, but init is not
allowed to create directories under `/vendor` (`vendor_file_type` is excluded
from AOSP's broad init rules).

`init.mt6765.rc` also runs `restorecon_recursive /vendor/nvcfg` in its
`post-fs-data` block. The stock nvcfg partition labels its contents
`nvcfg_file`, which this policy does not define, so the inodes appear
unlabeled and init relabels them to `mtk_nvcfg_file`. `device.te` grants init
`read`/`getattr`/`relabelto` on `mtk_nvcfg_file` for that reason: AOSP's
generic init rules exclude `vendor_file_type` from those permissions, while
`relabelfrom` on `unlabeled` and `associate` on `file_type` over `labeledfs`
are already covered by the platform policy.

The same file also imports two ColorOS ramdisk scripts by relative name,
`init.oppo.debug.rc` and `init.oppo.engineermode.rc`, and the debug script
imports `init.oppo.reserve.rc` the same way. Relative imports resolve against
init's working directory, which after `SwitchRoot("/system")` is the system
image root, so the adapted copies live in `rootdir/` and are installed to
`/init.oppo.*.rc` via `PRODUCT_COPY_FILES` (`$(TARGET_COPY_OUT_ROOT)` = `root/`,
which `build_image.py` merges into system.img). The boot ramdisk itself stays
minimal (`init` only) and is freed after the pivot.

The adaptations drop everything that needs ColorOS userland binaries absent
from `proprietary-files.txt` (junklog, nativedump, perf_record and the
`autochmod.sh` helpers), the phoenix crash-log actions (`CONFIG_OPPO_PHOENIX`
is disabled in the kernel) and the `persist.sys.mtk.pwkdump` triggers
(`/proc/aee_kpd_enable` does not exist). What remains is the
`/opporeserve` directory tree, the vendor-provided `init.oppo.seccommon.rc`
hook, and the charger `mmi_charging_enable` switches. The reserve script also
drops the stock `restorecon_recursive /opporeserve`: this policy labels the
whole partition `oppo_reserve_file`, so every directory inherits that label and
there is nothing to relabel. `sepolicy/vendor/device.te` grants init
`mounton`/`create_dir_perms` on `oppo_reserve_file` and `mtk_persist_file`
because AOSP's generic init rules exclude `vendor_file_type`.

### Recovery init

Recovery imports `/init.recovery.${ro.hardware}.rc` from its own ramdisk, so
`rootdir/etc/init.recovery.mt6765.rc` is installed to
`recovery/root/init.recovery.mt6765.rc`. It creates the `/dev/block/bootdevice`
alias for the `by-name` fstab paths, makes the backlight writable, opens the
Trustonic `mobicore` nodes used by keymaster during sideload, and stops the MTK
hung-task watchdog from firing while recovery idles at the menu.

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

### HIDL transport libraries

Android 10 merged `libhidltransport` and `libhwbinder` into `libhidlbase` and
removed the standalone libraries from `base_system.mk`. Every stock 8.1 vendor
binary — `camerahalserver`, `mtkfusionrild`, the audio, bluetooth, sensors,
light, PQ and composer services — carries explicit `DT_NEEDED` entries for both
libraries. Without them the dynamic linker aborts every vendor HAL with
`library "libhidltransport.so" not found`, causing a total bootloop.

`device.mk` therefore adds all four packages:

```make
PRODUCT_PACKAGES += \
    libhidltransport \
    libhidltransport.vendor \
    libhwbinder \
    libhwbinder.vendor
```

The `.vendor` variants are needed because the 8.1 blobs live in the vendor
linker namespace; without them `ld-android.so` resolves the system copy but
the vendor namespace isolation rejects it.

### SELinux

`sepolicy/vendor/` labels the MediaTek and OPPO vendor binaries that AOSP does
not label. The stock 8.1 precompiled policy is excluded from
`proprietary-files.txt`; loading an 8.1 policy on Android 10 is a hard boot
failure, not a compatibility question.

The file_contexts labelling was audited against the stock dump's `vendor/bin`
and `vendor/etc/init/*.rc` (all 201 services in 94 rc files) and against
`proprietary-files.txt`:

* Every path regex was checked against the binary it points at. Three were
  wrong and are fixed: `mtkfusionrild` (the real binary is
  `/vendor/bin/hw/mtkfusionrild`, per `rild.rc`), `wod` (the real binary is
  `epdg_wod`, per `init.wod.rc`) and `imsm` (the real binary is
  `volte_imsm_93`, per `init.volte_imsm_93.rc`).
* Entries for binaries this vendor image does not ship were dropped:
  `cas@1.0-service`, `thermald` and `6620_launcher`.
* Entries that merely re-label paths already covered by upstream
  `system/sepolicy/vendor/file_contexts` (with broader regexes like
  `cas@1\.[01]-service`) were dropped as redundant: `configstore@1.0`,
  `graphics.composer@2.1`, `thermal@1.0` and `broadcastradio@1.1`, on top of
  the AOSP-standard HAL services (`drm@1.0`, `gatekeeper@1.0`,
  `graphics.allocator@2.0`, `keymaster@3.0`, `media.omx@1.0`, `memtrack@1.0`,
  `vibrator@1.0`, `wifi@1.0`) that were already omitted. checkfc only rejects
  a repeated path regex when the two entries give *different* contexts; the
  identical-context copies were harmless dead weight, not build breakers.
* Real services that ship and start but had no label were added: `aee_aedv`
  and `aee_aedv64` (started at `on post-fs` by `init.aee.rc`), `connsyslogger`
  (class main), `bip` and `volte_imsm_93` (both on `mtk.md1.status=ready`),
  `epdg_wod` (on `persist.mtk_epdg_support=1`, which `vendor.prop` sets),
  `stp_dump3` (on `persist.mtk.wcn.coredump.mode=2`, which `vendor.prop` sets),
  `wfca` (class core), `oppoalgo_daemon` (on `sys.boot_completed=1`) and
  `vtservice_hidl` (class hal). Each gets a new `mtk_*` domain in `device.te`,
  permissive like the rest.

Two notes on services deliberately *not* given a domain:

* `init.mt6765.rc` starts `service oae /system/bin/oae_server -s` with
  `seclabel u:r:oae_server:s0`, but `oae_server` is a ColorOS-only system
  binary that neither the stock dump nor `proprietary-files.txt` ships (it
  sits in a `#ifdef COLOROS_EDIT` block). No `oae_server` type is declared:
  the exec would fail anyway, and a domain exists only to make a missing
  binary appear started.
* The KTV HAL (`vendor.oppo.hardware.ktv@1.0-service`) is in the stock
  `vendor/etc/init/` but its binary and rc are not in
  `proprietary-files.txt`, so it never starts and needs no label.

Most vendor domains are `permissive` during bring-up, following the convention
in the policy file. This includes the standard AOSP HAL domains that the MTK
vendor blobs are assigned to (`hal_audio_default`, `hal_bluetooth_default`,
`hal_camera_default`, `hal_graphics_composer_default`, `hal_light_default`,
`hal_sensors_default`, `rild`): these domains are enforcing by default in AOSP
and lack rules for MTK-specific device nodes (`/dev/kd_camera_hw`,
`/dev/mtk_sched`, `/dev/ccci*`, `/dev/mtk_disp_mgr`, etc.), so denials on
those nodes crash the daemons immediately. Marking them permissive during
bring-up logs the denials instead of blocking them.

`device.te` also declares `gps_device` and `sw_sync_device` itself: both were
dropped from Android 10's `system/sepolicy/public/device.te`, but the MT6765
kernel still exposes `/dev/gps`, `/dev/stpgps` (opened directly by `mnld` /
`mtk_agpsd`) and `/dev/sw_sync` (legacy sync fences used by the display
driver), so the device-local types are required.

Convert the denials they log into `allow` rules and remove the `permissive`
lines before shipping.

### VINTF

`manifest.xml` carries the CPH1909 stock vendor HAL declarations (Android 8.1
blobs) plus the HALs LineageOS 17.1 builds: `android.hardware.health@2.0`,
`android.hardware.usb@1.0`, `android.hardware.power@1.0` (served by the AOSP
HIDL service that forwards to `power.mt6765`, used for DT2W), and
`android.hardware.biometrics.fingerprint@2.1` (AOSP interface backed by the
Silead legacy-HAL shim). The `drm@1.2` clearkey instance is provided by a VINTF
fragment, not listed statically (see below). It declares `target-level="2"`.
The file is formatted in the expanded VINTF style (per-hal
`<version>`/`<interface>`/`<fqname>` blocks).

This is the key legacy-Treble setting. Android 10 replaced the old
`PRODUCT_COMPATIBILITY_MATRIX_LEVEL_OVERRIDE` with the `target-level` attribute
on the device manifest. API 27 corresponds to FCM level 2 (O-MR1), so the Q
framework validates the vendor HALs against the frozen O-MR1 compatibility
matrix. `assemble_vintf` would infer level 2 from
`PRODUCT_SHIPPING_API_LEVEL=27` even without the attribute, but only after
printing a warning. All ten HALs that FCM 2 marks as required are present in
this manifest. The stock 8.1 vendor device matrix is replaced by
`compatibility_matrix.xml` in this tree (`DEVICE_MATRIX_FILE`), which keeps the
framework requirements the 8.1 vendor blobs expect
(`android.frameworks.{schedulerservice,sensorservice}`, `android.hidl.*`,
`android.system.wifi.keystore`) in Android 10 VINTF format.

`android.hardware.cas` and `android.hardware.drm@1.2` (clearkey) are *not*
listed in the static manifest: `base_vendor.mk` always builds
`android.hardware.cas@1.1-service`, and `device.mk` builds
`android.hardware.drm@1.2-service.clearkey`. Both packages ship their own VINTF
fragments, and a second entry for the same HAL name and major version is
rejected by `assemble_vintf` with a duplicate-instance error.

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

`DEVICE_PACKAGE_OVERLAYS` points at `overlay/`, which holds three resource
overlays:

* `frameworks/base/core/res/res/xml/power_profile.xml` — the energy-use model
  BatteryStats needs. AOSP ships only deliberately bogus placeholder values
  there, so without it every battery statistic is meaningless. It describes the
  Helio P35's two clusters (4x2.3 GHz and 4x1.8 GHz, matching the clock
  frequencies in the kernel DT) and the 4230 mAh battery.
* `frameworks/base/core/res/res/values/config.xml` — the device-specific
  framework configuration described below. These are framework resources, so
  they cannot come from the vendor blobs. Every value is the stock CPH1909 one,
  read from the stock `framework-res.apk`, except where noted; only settings
  that differ from the AOSP 10 defaults, or that describe a capability the
  vendor/kernel provide, are listed.
* `frameworks/base/packages/SystemUI/res/values/dimens.xml` — the SystemUI
  dimensions described at the end of this section.

The `config.xml` overlay is grouped as follows:

**Display and brightness.** AOSP 10 ships empty `config_autoBrightnessLevels`
and `config_autoBrightnessLcdBacklightValues` arrays, which makes
`BrightnessMappingStrategy.create()` return null. No
`AutomaticBrightnessController` is then created, so auto-brightness is
unavailable and manual brightness has no device curve. The overlay supplies the
stock lux thresholds (`45, 1025, 1480, 2250, 3300, 10000`), the matching
backlight levels (`8, 22, 48, 78, 128, 206, 255`), the stock debounce/sampling
values and `config_automatic_brightness_available=true`. The vendor side was
already complete: `lights.mt6765.so` writes
`/sys/class/leds/lcd-backlight/brightness`, which the MT6765 LEDs driver
exposes. The stock manual range was too dim for Android 10, so the brightness
bounds come from the sibling MT6765 / 720x1520 CPH1920 (AX5s) instead: minimum
`4`, default `140` and dim `4` of `255` (dark/doze stay at the stock `2`).
Because the slider position scales the auto-brightness curve, the brighter
default lifts auto-brightness as well. The waterdrop notch cutout
(`M -105,0 L -105,55 L 105,55 L 105,0 Z`) is overridden too;
`config_mainBuiltInDisplayCutoutRectApproximation` follows the cutout string
automatically. `config_showNavigationBar=true` because the device has no
capacitive navigation buttons.

**Input, sensors and audio jack.** The MTK ACCDET driver
(`CONFIG_MTK_PMIC_CHIP_MT6357`) reports `SW_HEADPHONE_INSERT` /
`SW_MICROPHONE_INSERT` through the Linux input subsystem, not through the
legacy `/sys/class/switch/h2w` uevent path. AOSP defaults
`config_useDevInputEventForAudioJack` to false, so the framework never saw
headset insertion; the stock ROM sets it true. The stock ROM also enables
`config_suspendWhenScreenOffDueToProximity`, so the proximity sensor turns the
screen off against the ear during a call.

**Double-tap to wake.** `config_supportDoubleTapWake` is enabled. The
authoritative 8.1 kernel (`oppo6765_18511.dts`, multi-panel SPI touch `ili_ts@0`
on `spi3`) exposes `/proc/touchpanel/double_tap_enable` on the Himax summer,
NT36525B and Ilitek ipio_mmi panel drivers (the NT36xxx non-B path uses
`WAKEUP_GESTURE`/double-click mapped to `KEY_POWER`; its proc enable node is not
confirmed). `BoardConfig.mk` sets `TARGET_TAP_TO_WAKE_NODE` to that proc node.
On LineageOS 17.1 the Display toggle writes `Settings.Secure.DOUBLE_TAP_TO_WAKE`,
and `PowerManagerService` forwards it as
`IPower::setFeature(POWER_FEATURE_DOUBLE_TAP_TO_WAKE)` to
`android.hardware.power@1.0`. The default AOSP `android.hardware.power@1.0-service`
loads the legacy `libhardware` module and forwards `setFeature` to it, so this
tree builds a small `power.mt6765` shim (`power/`) — in the style of the MT6765
RMX2185 device trees — that writes `TARGET_TAP_TO_WAKE_NODE`. Both
`android.hardware.power@1.0-service` and `power.mt6765` are added in
`device.mk`, and `android.hardware.power@1.0::IPower/default` is declared in
`manifest.xml`. This shim only handles DT2W (other power hints/interactive are
stubs); the MTK vendor power interface
(`vendor.mediatek.hardware.power@1.1-service` / blobs) is separate and
unchanged. Behavior is panel-variant dependent; build/boot-test on hardware.

**Telephony.** `config_num_physical_slots=2` and `config_hotswapCapable=true`
match the dual-SIM, hot-swap-capable modem (`ro.telephony.sim.count=2`,
`ro.radio.simcount=2`, `ro.mtk_sim_hot_swap=1`). The stock
`networkAttributes`/`radioAttributes` tables are used, including the
MediaTek-specific WAP, XCAP, RCS, BIP, VSIM and preempt connection types.

**Connectivity.** `config_wifi_dual_band_support` and
`config_wifi_background_scan_support` are set for the MT6765 802.11ac radio,
and the tethering regexes (`ap\d`, `rndis\d`, `bt-pan`/`bt-dun`) match the
stock vendor configuration (`wifi.tethering.interface=ap0`).

**Bluetooth.** HFP in-band ringing plus the stock Bluetooth power model
(`1/2/3` mA idle/rx/tx, `3300` mV) used by BatteryStats.

**UI and power.** `config_enableMultiUserUI` and `config_multiuserMaximumUsers=4`
are enabled as in the stock ROM, and `config_unplugTurnsOnScreen=true` restores
the stock behaviour of waking the screen when power is unplugged.

**SystemUI dimensions.** The A5s uses a panel with physically rounded corners:
the MT6765 kernel enables round-corner support (`CONFIG_MTK_ROUND_CORNER_SUPPORT`)
and every LCM driver shipped for this device declares a corner pattern. In
LineageOS 17.1 SystemUI applies `rounded_corner_content_padding` as the
start/end margin of the gesture-navigation layout, so the overlay sets it to
the panel's corner radius (`34.0px`). That value comes from the sibling OPPO
A12/A11k (OP4BFB), the same Helio P35 with a 720x1520 panel, and matches the
32px corner constant used by the MT6765 720p LCM drivers in the kernel source.

### Input key layouts

AOSP 10 ships neither the MediaTek accessory-detect headset-button map
(`ACCDET.kl`) nor its keypad map (`mtk-kpd.kl`). Without them the wired headset
buttons (hook, media transport, `VOICE_ASSIST`) and the `mtk-kpd` key map fall
back to `Generic.kl`. The stock files are copied unchanged into
`/system/usr/keylayout/` through `PRODUCT_COPY_FILES`.

### Media profiles

Android 10's `MediaProfiles` only searches `/odm/etc` and `/vendor/etc` for
`media_profiles_V1_0.xml`, plus `/system/etc/media_profiles.xml`. The stock 8.1
vendor image ships its profiles as `/vendor/etc/media_profiles.xml`, so the
framework never finds them and camcorder recording has no device profiles. The
stock file is copied unchanged to `configs/media/media_profiles_V1_0.xml` and
installed as `/vendor/etc/media_profiles_V1_0.xml`, keeping the device's own
1080p/720p camcorder profiles and encoder capabilities.

### xHE-AAC decoder

Instagram and Facebook serve some audio tracks as xHE-AAC (`mp4a.40.42`).
Neither Android 10's C2 AAC decoder nor AOSP's SoftAAC2 OMX decoder can decode
that profile, and Meta's HeroPlayer picks a decoder by MIME without falling
back. The build therefore compiles AOSP's libxaac-backed OMX decoder from
source and makes it the image's AAC decoder:

```make
PRODUCT_PACKAGES += \
    libstagefright_softomx \
    libstagefright_softomx_plugin \
    libstagefright_soft_xaacdec
```

`libstagefright_soft_xaacdec` is `SoftXAAC` from
`frameworks/av/media/libstagefright/codecs/xaacdec`, with `external/libxaac`
linked in statically. It inherits `compile_multilib: "32"` from
`libstagefright_softomx-defaults`, matching the 32-bit 8.1 vendor OMX service.
The platform plugin is loaded by `OMXMaster::addPlatformPlugin()` through
`android_load_sphal_library()`. On this VNDK-lite build the vendor linker
configuration defines no `sphal` namespace, so the call falls back to the
process' default namespace, which searches `/system/lib`; the plugin and the
codec are installed there.

AOSP's `SoftOMXPlugin.cpp` registers two components for the `audio_decoder.aac`
role and leaves the selection to the vendor `media_codecs_google_audio.xml`:

* `OMX.google.aac.decoder` → `libstagefright_soft_aacdec` (SoftAAC2, stops at
  HE-AAC)
* `OMX.google.xaac.decoder` → `libstagefright_soft_xaacdec` (libxaac, supports
  AAC-LC, HE-AAC, HE-AACv2 and xHE-AAC)

The device copy in `configs/media/media_codecs_google_audio.xml` advertises
only the xaac component, for the whole `audio/mp4a-latm` type. It therefore
also serves the plain-AAC slot that Facebook Lite selects by MIME, which is the
behaviour the GSI v7.1 release note describes. Software OMX audio codecs rank
ahead of C2 software codecs, so the xaac node is chosen for AAC playback.

`configs/media/media_codecs_google_video_le.xml` replaces the stock Google
software video list with an empty `<Included>`. Installing the platform plugin
registers Google's software video component names, but their libraries are not
built in this image and MediaTek's hardware OMX video codecs cover every format
the stock file listed; the entries would otherwise advertise codecs that fail
when instantiated.

Both overrides are listed in `device.mk` before the vendor makefile is
inherited, because `PRODUCT_COPY_FILES` keeps the first source for a
destination.

### Properties

Both property files were audited against the stock dump (`a5s-dump`:
`system/build.prop`, `vendor/build.prop` and `vendor/default.prop`) and against
the Android 10 / LineageOS 17.1 sources that read them. Two rules follow from
that audit:

* The stock 8.1 blobs read the **unprefixed** `ro.mtk_*` names that the stock
  vendor `build.prop` set. The `ro.vendor.mtk_*` names used by Android-10-era
  MTK trees only work with Android 10 vendor blobs, so they are not used here.
* Properties that no stock image for this device ever set and that no Android 10
  reader consumes are left out rather than borrowed from other MTK trees.

`system.prop` (framework side) currently carries, grouped in-file:

* **Display / camera / audio**: `ro.sf.lcd_density=320`, `ro.camera.sound.forced=0`,
  `ro.audio.silent=0`.
* **Radio / Wi-Fi**: `rild.libpath=mtk-ril.so`, `rild.libargs=-d /dev/ttyC0`;
  `wifi.interface=wlan0`, `wifi.direct.interface=p2p0`,
  `wifi.tethering.interface=ap0`; the MediaTek Wi-Fi feature gates
  `ro.mediatek.wlan.wsc=1` / `ro.mediatek.wlan.p2p=1` / `mediatek.wlan.ctia=0`
  and `qemu.hw.mainkeys=0`.
* **Dalvik**: `ro.config.low_ram=false` (read by `core/jni/AndroidRuntime.cpp`
  and `RoSystemProperties`; this is not a low-RAM device).
* **Zygote**: nothing — `lineage_CPH1909.mk` inherits `core_64_bit.mk`, which
  already sets `ro.zygote=zygote64_32` via `PRODUCT_VENDOR_PROPERTIES`.
* **Crypto**: only `ro.crypto.allow_encrypt_override=true`; see *Encryption*.
* **MediaTek framework knobs**: `ro.kernel.zio=38,108,105,16`,
  `ro.zygote.preload.enable=0`, and the `ro.mtk_perf_*` start-window /
  response-time performance hints.

`vendor.prop` (vendor side) holds the subset of the stock vendor
`build.prop` / `default.prop` that the prebuilt MediaTek / OPPO blobs and their
`rc` files actually read. Grouped in-file:

* **Audio**: the Dirac suite (`persist.dirac.*`),
  `ro.mtk_audio_tuning_tool_ver=V2.2` and `ro.audio.usb.period_us=16000`
  (stock values). The Aurisys tuning set (`vendor/etc/aurisys_config.xml` and
  `vendor/etc/aurisys_param/*`, extracted through `proprietary-files.txt`) is
  loaded by the MTK audio HAL from that fixed path, so — as on the stock image,
  and in rosemary / mt6768 trees — no `vendor.audiohal.aurisys.*` property is
  needed to point at it.
* **Camera**: `ro.mtk_camera_app_version=3`, `ro.mtk_fd_support=1`,
  `camera.disable_zsl_mode=1` and the MDP capture flags
  `camera.mdp.cz.enable=1` / `camera.mdp.dre.enable=0` — all stock values;
  ZSL stays disabled as on ColorOS.
* **Display / graphics**: `ro.surface_flinger.has_wide_color_display=false`
  and `ro.surface_flinger.has_HDR_display=false` (Android 10
  `SurfaceFlingerProperties` sysprops), `debug.sf.disable_backpressure=1`
  (stock; read by `SurfaceFlinger.cpp`), `debug.sf.latch_unsignaled=1` (read by
  `BufferLayer.cpp`), `ro.opengles.version=196610`, `ro.sf.hwrotation=0`, and —
  critically — `ro.hardware.egl=mtk`. The Android 10 EGL loader appends
  `ro.hardware.egl` (then `ro.board.platform`) to `libEGL_`; this device's
  vendor tree ships `libEGL_mtk.so` / `libGLESv2_mtk.so`, so without it the
  loader looks for the non-existent `libEGL_mt6765` and SurfaceFlinger never
  starts.
* **DRM / Media**: `drm.service.enabled=true`,
  `ro.mtk_widevine_drm_l3_support=1`; `media.settings.xml` points at
  `/vendor/etc/media_profiles_V1_0.xml`, the file this device tree installs
  (see *Media profiles*); `mtk.vdec.waitkeyframeforplay=1`; and the stock
  playback flags `ro.mtk_wmv_playback_support=1` /
  `ro.mtk_flv_playback_support=1`.
* **FM / GPS / radio / telephony**: `fmradio.driver.enable=1` and
  `ro.mtk_fm_50khz_support=1`; GPS via `ro.mtk_gps_support=1` and
  `ro.mtk_agps_app=1`, plus `ro.mtk_omacp_support=1` in the platform block;
  the dual-SIM hot-swap modem
  block (`persist.radio.default.sim=0`, `persist.radio.fd.counter=150`, ...);
  and the `persist.mtk.connsys.poweron.ctl` / `persist.mtk.wcn.patch.version`
  WCN connect bits.
* **Bluetooth**: `bt.profiles.avrcp.multiPlayer.enable=0` (AVRCP single active
  player, matching stock) and
  `persist.bluetooth.a2dp_offload.disabled=true`. The AOSP Bluetooth stack
  (`system/bt`, the Bluetooth app) reads the prefix-less name; the
  `persist.vendor.bluetooth.*` form is not read by anything.
* **Storage / init / USB**: `ro.frp.pst=/dev/block/.../frp`, `ro.mount.fs=EXT4`,
  `ro.sys.sdcardfs=1`, `ro.oem_unlock_supported=1`,
  `persist.sys.usb.config=mtp` (the stock `default.prop` name read by
  `UsbDeviceManager`).
* **Platform identification / TEE**: the `ro.mtk_*` platform block, including
  `ro.mtk_tee_gp_support=1`, `ro.mtk_trustonic_tee_support=1` and
  `ro.hardware.kmsetkey=trustonic` (what `kmsetkey` actually opens, see
  *Keymaster and gatekeeper HAL modules* above).
* **Wi-Fi**: `ro.mtk_wapi_support=1` (the stock value; the Android-10 trees use
  `ro.vendor.mtk_wapi_support=0`, which these blobs do not read),
  `ro.mtk_dhcpv6c_wifi=1`, and the WCN/consys connection values.
* **Dalvik / ART**: `dalvik.vm.heapgrowthlimit=384m`,
  `dalvik.vm.heapsize=512m` (the stock 3/4 GB sizing).

The ColorOS-only values (`ro.com.google.gmsversion`, `ro.setupwizard.*`,
`pm.dexopt.*`, the `persist.log.tag.*` block and the `ro.mtk_*` feature switches
that no prebuilt blob consults) are deliberately dropped.

#### Properties deliberately not carried over

These were added at various points but have no reader (or no stock backing) on
this device, so they were removed:

* `ro.keystore.disable_strongbox` — not read by AOSP, LineageOS or the MTK
  blobs. StrongBox availability is probed from the keymaster HAL; the Trustonic
  TEE here is keymaster 3.0, so no StrongBox is advertised anyway.
* `ro.crypto.dm_default_key.options_format.version` — does not exist in the
  Android 10 `vold` (checked against `android-10.0.0_r47`); it was added in a
  later release and is inert here.
* `ro.charge.animation.hz` — ColorOS charger-app property with no LineageOS
  reader and no entry in the stock `build.prop`.
* `persist.vendor.radio.gps.support`, `ro.vendor.mtk_passpoint_r1_support`,
  `ro.vendor.mtk_thermal_config`, `ro.vendor.mtk_tee_support`,
  `ro.vendor.mtk_sec_usb_check`, `ro.vendor.mtk_lcm_physical_rotation`,
  `ro.vendor.mtk_hwc_support`, `ro.vendor.gpu.type`, the `ro.vendor.mtk_cam_*`
  set, `persist.vendor.camera3.zsl.enable`, `ro.vendor.mtk_omx_core_log_enable`,
  the mp4/avi/hevc playback flags, `ro.vendor.bt.stack`,
  `persist.vendor.bt.a2dp.source_codec` and the extra
  `persist.vendor.*.usb.config` / `audiohal` entries — none of these exist in
  this device's stock dump (or they use the Android-10 `ro.vendor.` namespace
  that its 8.1 blobs do not read), so they would have been inert.

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

The fstab entry is classic FDE (`encryptable=<metadata partition>`), not
dm-default-key metadata encryption and not file-based encryption, so of the
`ro.crypto.*` switches only one is both real and relevant on Android 10:

```properties
ro.crypto.allow_encrypt_override=true
```

`vold`'s `cryptfs.cpp` reads it when `fscrypt_is_native()` and adds
`allow_encrypt_override` to the dm-crypt table, letting the encryption path
override the encryption mode instead of failing when the footer and the
requested mode disagree. `ro.crypto.volume.filenames_mode` is read by
`FsCrypt.cpp`, but only when creating volume keys for adoptable storage, and
`ro.crypto.dm_default_key.options_format.version` does not exist in the
Android 10 `vold` at all, so neither is set. The TEE side of the setup is the
`ro.mtk_tee_gp_support` / `ro.mtk_trustonic_tee_support` /
`ro.hardware.kmsetkey=trustonic` block under *Properties*.

### Other build changes

* `BUILD_BROKEN_DUP_RULES := true` — the blob set and AOSP both install several
  of the same paths (the 8.1 HAL services AOSP 10 replaces); the blob wins Make
  parse order, which is what we want for the MediaTek binaries.
* `BUILD_BROKEN_PREBUILT_ELF_FILES := true` — Android 10's build system runs
  ELF checks (`check_elf_file.py`) on prebuilt shared libraries, verifying
  DT_NEEDED entries resolve within the declared VNDK set. The 8.1 vendor blobs
  predate these checks and carry entries like `libhidltransport.so` and
  `libhwbinder.so` that would fail the validator.
* `BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true` — suppresses the
  parallel check that flags ELF binaries installed through `PRODUCT_COPY_FILES`
  rather than through `BUILD_PREBUILT`.
* `BUILD_BROKEN_USES_BUILD_COPY_HEADERS := true` — vendor makefiles may still
  use the removed `BUILD_COPY_HEADERS` idiom; this flag downgrades the error to
  a warning.
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

* Fingerprint is wired to the AOSP biometric stack via
  `biometrics/fingerprint/` (`fingerprint.mt6765`, `proprietary`, multilib): it
  exports the `FINGERPRINT_HARDWARE_MODULE_ID` HMI (required because Android 10
  `libhardware` rejects an `hmi->id`/`class_id` mismatch) and `dlopen`s/forwards
  the stock legacy Silead HAL (`fingerprint.silead.default.so`, API 2.1,
  `libsl_fp_impl.so`, `/dev/silead_fp`). `Android.mk` installs a
  `fingerprint.default.so` → `fingerprint.mt6765.so` alias. `device.mk`
  builds/installs `android.hardware.biometrics.fingerprint@2.1-service` and
  first-wins `PRODUCT_COPY_FILES` overrides (before `CPH1909-vendor.mk`) disable
  the stock ColorOS `fps_hal` / `fpay_hal` init services, which register
  `vendor.oppo.hardware.biometrics.fingerprint@2.1` (not the AOSP interface) and
  would contend for `/dev/silead_fp`. Vendor SELinux contexts/bring-up
  `permissive hal_fingerprint_default` are in `sepolicy/vendor/`. Face unlock is
  userspace-only on CPH1909 (no face driver in the authoritative kernel; stock
  vendor face service/`libmegface`/`libstface*` blobs exist, but LineageOS 17.1
  has no AOSP `android.hardware.biometrics.face@1.0` default service), so only
  fingerprint is wired to an AOSP interface. Boot-test to confirm shim load,
  `IBiometricsFingerprint/default` registration, `/dev/silead_fp` access, and
  that stock `fps_hal`/`fpay_hal` remain disabled.
* The 8.1 vendor blobs are the highest-risk part of the port. The HIDL
  transport libraries (`libhidltransport`, `libhwbinder`) and their `.vendor`
  variants are installed to satisfy the blobs' `DT_NEEDED` entries. If HIDL
  services still fail to load, check `ro.hardware` / `ro.hardware.egl` and the
  linker namespace denials first; the build is VNDK-lite, so vendor binaries may
  resolve libraries from `/system/lib[64]` as described above.
* Recovery: `TARGET_RECOVERY_FSTAB` points at the same fstab. The TWRP tree for
  this device is a separate branch and is not built from this one.
