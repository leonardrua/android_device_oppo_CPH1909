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
* Legacy Treble — the vendor image is O-MR1 (API 27, FCM level 2), so the device
  manifest declares `target-level="2"`. The build itself uses full VNDK
  (`BOARD_VNDK_VERSION := current`, see *Vendor partition and VNDK*).

The hardware values (partition sizes, kernel base and offsets, MT6765 platform,
fstab partition layout) are carried over from the stock device tree. Everything
that had to change for Android 10 is listed below.

Several HALs that stock ships as blobs are instead **built from source in this
tree** — fingerprint (`biometrics/fingerprint/`), face (`biometrics/face/`),
power (`power/`) and lights (`light/`) — and the matching vendor blobs are
dropped or disabled. The vendor blob adaptations (repacked APKs, ELF/VNDK
repairs, compatibility libraries) are documented in the vendor tree's README;
this file documents the device-side wiring and the Android 10 changes.

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

Automated CI builds are covered under [`## CI workflows`](#ci-workflows) below;
the `build.yml` workflow also has a `target` dispatch input so `bootimage` /
`vendorimage` / `productimage` / `systemimage` can be produced in place of
`bacon`.

### Kernel

This tree **builds the kernel from source** — there is no prebuilt kernel image
in the repository. `TARGET_KERNEL_SOURCE := kernel/oppo/CPH1909` and
`TARGET_KERNEL_CONFIG := a46_defconfig` (plus `TARGET_KERNEL_ARCH := arm64` and
`BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb`), so the build compiles the 4.9
MediaTek/OPPO `VENDOR_EDIT` kernel and packs `Image.gz-dtb` itself. The config
was switched from `oppo6765_18511_defconfig` to `a46_defconfig` to match the A.46
firmware baseline carried by the `kernel/oppo/CPH1909` lineageos branch; both
configs build the same `oppo6765_18511` project
(`CONFIG_ARCH_MTK_PROJECT="oppo6765_18511"`,
`CONFIG_BUILD_ARM64_DTB_OVERLAY_IMAGE_NAMES="mediatek/oppo6765_18511"`), and
`a46_defconfig` also sets `CONFIG_OPPO_KTV_DEV=y`.

`TARGET_PREBUILT_KERNEL` is deliberately never set: the tree carries no kernel
image, and LineageOS clears `TARGET_KERNEL_SOURCE` when it is — which would also
break the `generated_kernel_includes` Soong module (it runs
`make -C $(TARGET_KERNEL_SOURCE) ... headers_install` for modules that depend on
`generated_kernel_headers`). A real kernel source tree at `kernel/oppo/CPH1909`
is therefore required both for the image and for the headers.

The CI build workflow clones `leonardrua/A5S-8.1-kernel-source` into that path,
with the GCC Linaro 6.3.1 + Python 2 toolchain and on-the-fly warning fixes (see
[`## CI workflows`](#ci-workflows)). On a local build, check out the same tree at
`kernel/oppo/CPH1909` relative to the LineageOS source root before lunching.

The source tree is version `4.9.80` (`CONFIG_LOCALVERSION=""`), while the stock
vendor image ships seven 4.9.77+ kernel modules — `wmt_drv.ko`,
`wmt_chrdev_wifi.ko`, `wlan_drv_gen4m.ko`, `bt_drv.ko`, `gps_drv.ko`,
`fmradio_drv.ko` and `met.ko` in `/vendor/lib/modules/`, loaded by
`init.wmt_drv.rc` / `init.wlan_drv.rc` / `init.bt_drv.rc` / `init.gps_drv.rc` /
`init.fmradio_drv.rc` — all built with `CONFIG_MODVERSIONS=y`. The stock boot
ramdisk also ships `fpsgo.ko`, a small FPSGO companion module that provides the
implementation behind `xgf_est_slptime_fp`, which the source-built kernel
exports. It is kept in this tree at `rootdir/modules/fpsgo.ko` (SHA-256
`ab532998884b64151dc2c0d7c82a20ea37c3cd9d3001d7742e67d1cf3b932d8d`) and installed
by `device.mk` as `/system/lib/modules/fpsgo.ko`. The vendor `init.mt6765.rc` in
this tree is edited to load that path instead of the stock `/lib/modules/fpsgo.ko`
— Android 10's system image root has no `/lib`, and no `/lib` alias is created for
a single insmod line.

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
  driver ABI is shared between the two trees, so the modules resolve — which is
  the part the boot test proves and static analysis could not.

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

### The `/system` side blobs

The system partition blobs this device needs (the Soter Trustonic interface
libraries, the IMS stack, the stub jars, and the MediaTek native libraries) also
live in the vendor tree under `vendor/oppo/CPH1909/proprietary/system/` and are
installed into `/system/...` by the vendor makefile / prebuilt modules; the
device tree's blob list documents them in the same file as the vendor blobs. The
vendor tree's README has the full accounting; the highlights:

* `ImsService.apk` (`com.mediatek.ims`) is the Android 10 (QP1A) build from the
  Realme C2 RMX1941 donor stack, repacked and re-signed with this build's
  platform key; unlike the other stock APKs it already carries its own
  `classes.dex`. It serves the modern binder through
  `MtkDynamicImsService extends android.telephony.ims.ImsService` and targets
  API 29, matching LineageOS 17.1's `ims-common` (the stock 8.1 APK targeted
  `com.android.ims.ImsCallProfile` and could not load). The matching donor boot
  jars `mediatek-{common,ims-base,ims-common}.jar` are installed as
  Soong `dex_import` modules by the vendor tree and listed in
  `PRODUCT_BOOT_JARS` below. The ColorOS `OppoSimSettings.apk` and the three
  309-byte manifest-only ColorOS stub jars (plus their
  `com.coloros.libraries.xml`) were dropped: no shipped app references them,
  and AOSP Settings covers SIM/mobile-network configuration. `SoterService` and
  `EmCamera` are the remaining dex-stripped/repacked stock APKs; they and
  `ImsService` declare platform shared uids (`android.uid.phone`,
  `android.uid.system`).
* The VoLTE video-telephony chain is imported: `/system/bin/vtservice` and its
  full MTK dependency closure (`libmtk_vt_service.so`, `libsource.so`,
  `libcomutils.so`, `libdpframework_mtk.so`, `libged_sys.so`,
  `libgralloc_extra_sys.so`, `libion_mtk_sys.so`, `libion_ulit_sys.so`,
  `libpq_prot_mtk.so`, `libsignal.so`, `libvt_avsync.so` plus the `/system` HIDL
  interface libraries) — required by `init.vtservice.rc`. `vtservice_hidl` is
  labeled `mtk_vtservice_exec`; `/system/bin/vtservice` is labeled
  `mtk_vtservice_main_exec` with its own `mtk_vtservice_main` domain
  (`coredomain` + `system_file_type`), because domains/types entered from
  `/system` must carry those attributes (`treble_sepolicy_tests` /
  `sepolicy_tests`). Both domains stay permissive during bring-up.
* The VoLTE daemon side — `vendor/bin/volte_{imcb,imsm_93,stack,ua}` and
  `vendor/lib/libvolte_{core,xdmc}_shr.so` / `libipsec_ims_shr.so` — is the
  Android 10 donor stack from RMX1941, matched to the A10 `ImsService` APK.
  Its init scripts use the donor service names (`vendor.volte_imcb`,
  `vendor.volte_stack`, `vendor.volte_ua`) with this device's legacy
  `mtk.md1.status` triggers; the A10 `volte_md_status` daemon is not shipped.
* Additional stock `/system/bin` helpers referenced by the vendor init tree are
  imported at their original system paths with their direct native-library
  closure (`autochmod.sh`, `emdlogger1/2/5`, `factory`, `iwpriv`, `mdlogger`,
  `meta_tst`, `libmdloggerrecycle.so`, `libmemoryDumpEncoder.so`, and 64-bit
  `libaudiocustparam.so`, `libkmsetkey.so`, `libminiui.so`, `libsysenv_system.so`).
  These are factory/meta/modem/logging tools, not replacements for AOSP services.
* The stock `/system/lib[64]` MediaTek native libraries are stored in the vendor
  tree and installed at their original `/system` paths, including
  `vendor.mediatek.hardware.camera.device@1.1.so` (a direct camera-stack
  dependency). The API-27 MediaTek framework JARs and precompiled ART/OAT files
  are not included. The 309-byte empty framework stub jars remain a distinct
  exception (stock-layout parity; nothing loads them).
* The fingerprint/face framework stub jars are imported
  (`android.frameworks.fingerprintservice-V1.0-java.jar`,
  `vendor.oppo.hardware.biometrics.fingerprint-V2.1-java.jar`, `ifaamanager.jar`,
  `android.frameworks.faceservice-V1.0-java.jar`,
  `vendor.oppo.hardware.biometrics.face-V1.0-java.jar`) plus OPPO's
  `org.ifaa.android.manager.permissions.xml`. All five jars are 309-byte empty
  stubs. The stock system-side interface libraries for the disabled OPPO
  fingerprint services are deliberately not imported.
* Both IMS apps' `<uses-library>` entries carry `required="false"`, and their
  signature|privileged permissions are allowlisted by
  `configs/permissions/privapp-permissions-ims.xml` (installed to
  `/system/etc/permissions/`) in addition to AOSP's
  `android.hardware.telephony.ims.xml`.

Entries that exist on the stock 8.1 vendor partition but must not be copied are
documented at the top of `proprietary-files.txt` (VINTF data, the 8.1 SELinux
policy, mkshrc, and the generated `public.libraries.txt` / `fs_config*` /
`NOTICE.xml.gz` files).

Pins are optional: lines of the form `path|sha1` additionally record the SHA-1 of
the extracted blob so a stale or corrupted extraction fails the build early. The
current list carries none — it is generated without `--pin`, and
`extract_utils.sh` strips any `|sha1` suffix before resolving the path, so an
unpinned list extracts identically. `update-sha1sums.sh` can add or refresh them:

```sh
./update-sha1sums.sh          # refresh existing pins
./update-sha1sums.sh --add    # pin every entry
```

It reads `proprietary-files.txt` line by line (paths with spaces are safe), leaves
comments, blank lines and unpinned entries untouched unless `--add` is given,
warns and preserves any entry whose blob is missing, and rewrites the file
atomically only when something changed.

## CI workflows

The repository also contains GitHub Actions workflows.

### `build.yml` — Namespace build

`Build LineageOS 17.1 (Oppo A5s CPH1909) - Namespace` is a manual
(`workflow_dispatch`) build workflow that runs on the user-provisioned
`namespace-profile-leonard` runner and writes its `out/` tree to the persistent
`/cache` disk so consecutive runs reuse ccache and intermediates. Its main
characteristics:

* Syncs the LineageOS 17.1 source with `repo`, then clones the device and vendor
  trees and a source kernel tree (`leonardrua/A5S-8.1-kernel-source`) into
  `kernel/oppo/CPH1909`. The kernel image is built from this source tree
  (`TARGET_KERNEL_SOURCE`/`TARGET_KERNEL_CONFIG`, no prebuilt image in the device
  tree); the tree is additionally patched on the fly to keep warnings non-fatal.
* The `Keep kernel warnings non-fatal` step appends `-Wno-error` to the standard
  C-flags line in `scripts/Makefile.lib`, so the large MTK kernel (full of
  arch-specific warnings) still builds. It is idempotent and asserts exactly one
  occurrence of the Kbuild line before patching.
* The AArch64 UAPI header guard is **not** a workflow step: it is committed in the
  kernel repository as `9ff77c8aa0b1` ("uapi: guard fpsimd_context in the AArch64
  sigcontext header"), wrapping `struct fpsimd_context` in
  `arch/arm64/include/uapi/asm/sigcontext.h` with `#ifdef __aarch64__` so
  `headers_install` also works for 32-bit ARM (used by
  `generated_kernel_includes`). Related fixes `c728eada242c`, `809fe558e875` and
  `3bdc4c825601` cover the other AArch64-only UAPI declarations.
* Before the build it verifies the Git LFS artifact
  `external/chromium-webview/prebuilt/arm64/webview.apk`. If the file is a small
  LFS pointer (typical: 134 bytes, not the ~260 MB real APK) it runs `git lfs
  pull` to materialise the real ZIP, then fails fast if the file is still not a
  ZIP. This protects the run from the `//external/chromium-webview:webview`
  `veridex` / `aapt2` "failed opening zip: Invalid file" failure observed at ~99 %
  on the first CI build.
* Builds with `lunch lineage_CPH1909-<type>` and `mka <target>`. The job exposes
  `target`, `build_type`, `build_timeout_min`, `out_on_cache` and `clean_out`
  dispatch inputs. `OUT_DIR`/`OUT_BASE` live on `/cache` when the runner provides
  it, otherwise the workspace is used.
* After the build the `Collect output` step packages the images, the
  `lineage-*.zip` OTA, `build-tail.log` and, when non-empty, `error.log` into a
  `result/` folder, uploaded as a workflow artifact named
  `lineage-17.1-<device>-<target>` (default target `bacon` →
  `lineage-17.1-CPH1909-bacon`).

Because the runner blocks `swapon` and `zram` and clears `/cache` between runs,
the workflow does **not** try to create its own swap. Rely on the runner-level
swap instead; the build just reports what `free -h` sees.

### `publish.yml` — optional publishing

`Publish build artifacts (optional)` is a second, purely manual
(`workflow_dispatch`) workflow that takes the artifact produced by a successful
`build.yml` run and turns it into a GitHub draft pre-release of the device
repository. It:

* Defaults to the latest successful `Build LineageOS 17.1` run but accepts an
  explicit `run_id`.
* Defaults to the `lineage-17.1-CPH1909-bacon` artifact (or
  `lineage-17.1-CPH1909-<target>`).
* Downloads the artifact into `published/`, **deletes any zero-byte files**
  (GitHub release assets must be at least 1 byte — the empty `error.log` that
  produced a `size must be greater than or equal to 1` error on the first release
  attempt is filtered out here), then recomputes the release asset list from the
  remaining non-empty files and writes a `SHA256SUMS` alongside them.
* Creates the release with `softprops/action-gh-release` using an explicit file
  list, with `draft` and `prerelease` both on by default; publish only happens
  when the workflow is explicitly triggered.

`recovery-build.yml` (legacy TWRP recovery build) and `ci.yml` (device tree
integrity validation) are unchanged by the recent CI work. `ci.yml` explicitly
checks that the source-built HAL modules (e.g. `power.mt6765`,
`android.hardware.light@2.0-service.CPH1909`) resolve, guarding against the
Soong-finder issue described under *Resource overlay / power shim*.

## What changed for Android 10

### Boot, system-as-root and first-stage mount

This is a non-system-as-root device, but Android 10 always builds `system.img` in
the system-as-root layout: `build_image.py` merges the root directory into the
system image and mounts the result at `/`. For this device the boot image still
carries a ramdisk (`BOARD_BUILD_SYSTEM_ROOT_IMAGE` is intentionally unset), so the
kernel starts `init_first_stage` from the ramdisk and the system image is mounted
later.

First-stage init does not use the kernel device tree for the fstab. The kernel
tree this device builds carries commit `070094089462` ("ARM64: dts: Switch mt6765
to 2-stage-init"), which removed the `firmware/android/fstab` node from
`arch/arm64/boot/dts/mediatek/mt6765.dts` — the same change xiaomi-lotus-devs made
for MT6765 in kernel commit `8e24bd2`. So `ReadFstabFromDt()` finds nothing,
`ReadFirstStageFstab()` falls back to `GetFstabPath()`, which probes
`/odm/etc/fstab.<hw>`, `/vendor/etc/fstab.<hw>` and `/fstab.<hw>`; neither `/odm`
nor `/vendor` is mounted that early, so only the ramdisk copy is reachable.

That is why `rootdir/etc/fstab.mt6765` is installed **twice**: as `/fstab.mt6765`
in the boot ramdisk by the `fstab.mt6765_ramdisk` prebuilt (top-level `Android.mk`),
and as `/vendor/etc/fstab.mt6765` by `PRODUCT_COPY_FILES`. Its `/system` and
`/vendor` lines carry `wait,first_stage_mount`, so first-stage init mounts
`/system`, pivots to it (`TrySwitchSystemAsRoot()` → `SwitchRoot("/system")`), then
mounts `/vendor` from the new root. From that point on the system image is the
root filesystem and second-stage `/system/bin/init` runs.

The `/vendor` copy then serves the stock `init.mt6765.rc` `mount_all` in its
`on fs` / `on late-fs` blocks (and is the recovery fstab via
`TARGET_RECOVERY_FSTAB`). `fs_mgr` skips `first_stage_mount` entries that are
already mounted, so nothing is mounted twice.

**`/odm` is mounted in the first stage.** The scatter defines a 256 MiB `odm`
partition. Stock leaves it zeroed and unused (`recoveryonly`), but this build
installs the **precompiled SELinux policy** to `/odm/etc/selinux` (because
`BOARD_ODMIMAGE_FILE_SYSTEM_TYPE` forces `BOARD_USES_ODMIMAGE`, and
`system/sepolicy/Android.mk` puts `precompiled_sepolicy` in
`$(TARGET_OUT_ODM)/etc/selinux` in that case). The fstab `/odm` line therefore
carries `wait,first_stage_mount` so the partition is available before init's
SELinux policy load: `FindPrecompiledSplitPolicy()` checks
`/odm/etc/selinux/precompiled_sepolicy` first and loads the precompiled,
sha256-validated policy instead of recompiling the CIL at boot. The LOS build
always flashes `odm.img` (the OTA's `block_image_update` writes it
unconditionally), so the partition always has a valid ext4 filesystem when
booting LOS — no `no_fail` guard is needed. The same fstab feeds the boot ramdisk,
`/vendor/etc` and recovery, so recovery mounts `/odm` too.

The A-only layout is reflected by the absence of `slotselect` flags, the separate
`recovery` partition, and `BOARD_AVB_ENABLE := false` (the device has no `vbmeta`
partition and the bootloader is locked to OPPO's keys).

### MediaTek init scripts

`androidboot.hardware=mt6765` also makes init import the stock
`/vendor/etc/init/hw/init.mt6765.rc` from AOSP's `rootdir/init.rc`:

```sh
import /vendor/etc/init/hw/init.${ro.hardware}.rc
```

That file in turn builds several of its own imports out of `${ro.mtkrc.path}`, so
`ro.mtkrc.path=/vendor/etc/init/hw/` is set through
`PRODUCT_DEFAULT_PROPERTY_OVERRIDES`, and
`BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true` puts it in `/vendor/default.prop`,
which init loads before parsing the boot scripts. With the property unset those
imports expand to `/init.connectivity.rc` and friends, fail silently, and the
device hangs at the logo with no modem, sensors or connectivity services.

The stock `init.mt6765.rc` starts `swap_enable_init`, a oneshot service that runs
`/system/etc/swap_enable.sh` with the `rutilsdaemon` seclabel. That script lives
on the system partition and is therefore not part of the blob extraction, so
`rootdir/bin/swap_enable.sh` supplies it. It is a rewrite of the stock script: the
OPPO-private `direct_swappiness` and `almk_swap_ratio1` nodes do not exist in this
kernel (userspace lmkd replaced the in-kernel lowmemorykiller), and every write is
guarded so a missing node cannot leave zram half-configured.

The stock `init.mt6765.rc` also runs `mount_all /vendor/etc/fstab.mt6765` in its
`on fs` block, mounting the remaining partitions (data, cache, protect_f,
protect_s, nvdata, nvcfg, persist, opporeserve). The vendor image is assembled
from the extracted blobs, so `Android.mk` also creates the empty
`/vendor/{protect_f,protect_s,nvdata,nvcfg,persist}` mount point directories;
`init.mt6765.rc` and `fs_mgr` would `mkdir()` them at runtime, but init is not
allowed to create directories under `/vendor` (`vendor_file_type` is excluded
from AOSP's broad init rules).

`init.mt6765.rc` also runs `restorecon_recursive /vendor/nvcfg` (and
`/vendor/nvdata`) in its `post-fs-data` block. Those are no-ops in any AOSP 10
policy: full-Treble neverallows forbid every domain — including init — from
`relabelto` on `vendor_file_type`, and `read`/`getattr` on the files are not
covered either, so the stock lines can never fix labels from init. The
mkdir/chown/chmod/restorecon in the stock rc will also be denied under enforcing;
the partitions keep their factory labels, which this policy does not define, so
their inodes appear `unlabeled` — and all vendor domains in this policy are
`permissive` during bring-up, so unlabeled reads are logged, not blocked. The only
device rules are the `mounton` allows (AOSP's mounton list covers only platform
types), and `oppo_reserve_file` stays a plain `file_type` because `/opporeserve`
is at the root, not under `/vendor`.

The same file also imports two ColorOS ramdisk scripts by relative name,
`init.oppo.debug.rc` and `init.oppo.engineermode.rc`, and the debug script imports
`init.oppo.reserve.rc` the same way. Relative imports resolve against init's
working directory, which after `SwitchRoot("/system")` is the system image root,
so the adapted copies live in `rootdir/` and are installed to `/init.oppo.*.rc`
via `PRODUCT_COPY_FILES` (`$(TARGET_COPY_OUT_ROOT)` = `root/`, which
`build_image.py` merges into system.img). The boot ramdisk itself stays minimal
(`init` only) and is freed after the pivot.

The adaptations drop everything that needs ColorOS userland binaries absent from
`proprietary-files.txt` (junklog, nativedump, perf_record and the `autochmod.sh`
helpers), the phoenix crash-log actions and the `persist.sys.mtk.pwkdump` triggers
(`/proc/aee_kpd_enable` does not exist). `CONFIG_OPPO_PHOENIX` is now disabled in
`a46_defconfig` too (it was still `=y` there even though `oppo6765_18511_defconfig`
had it off): its watchdog panics the kernel with `ERROR_HANG_OPPO` roughly eight
minutes into boot whenever `sys.boot_completed` is not set, which turned a slow
or blocked boot into an endless reboot-to-recovery loop. What remains is the
`/opporeserve` directory tree, the vendor-provided `init.oppo.seccommon.rc` hook,
and the charger `mmi_charging_enable` switches. The
reserve script also drops the stock `restorecon_recursive /opporeserve`: the
mounts in `init.oppo.seccommon.rc` create the directory tree on the stock
partition itself, so no relabel is possible or needed, and `file_contexts` labels
it `oppo_reserve_file` (a plain `file_type`, root not `/vendor`).
`sepolicy/vendor/device.te` grants init `mounton` on it and the vendor mount
points. The dead `rootdir/init.mt6765.usb.rc` stub was removed (the vendor
`init.project.rc` already imports the real one by absolute path).

### Recovery init

Recovery imports `/init.recovery.${ro.hardware}.rc` from its own ramdisk, so
`rootdir/etc/init.recovery.mt6765.rc` is installed to
`recovery/root/init.recovery.mt6765.rc`. It creates the `/dev/block/bootdevice`
alias for the `by-name` fstab paths, makes the backlight writable, opens the
Trustonic `mobicore` nodes used by keymaster during sideload, and stops the MTK
hung-task watchdog from firing while recovery idles at the menu.

**Recovery USB uses configfs.** Recovery's own `init.rc` sets `sys.usb.configfs=0`
in early-init, selecting the legacy `/sys/class/android_usb` gadget — which this
kernel does not provide (`a46_defconfig` has `CONFIG_USB_CONFIGFS=y` and
`# CONFIG_USB_G_ANDROID is not set`, so `drivers/usb/gadget/android.c`, the only
creator of the `android_usb` class, is never built). Every write under
`/sys/class/android_usb` would fail with ENOENT and recovery adb/sideload would
never enumerate. The recovery rc sets `sys.usb.configfs 1`; recovery's `init.rc`
already contains the matching configfs actions (mount configfs, create
`/config/usb_gadget/g1`, `ffs.adb`/`ffs.fastboot`, bind the UDC), and Android 10's
init fills `sys.usb.controller` itself from `/sys/class/udc`.
`sys.usb.ffs.aio_compat` is deliberately not set: this 4.9 kernel's `f_fs.c`
implements AIO and the stock 8.1 userspace used it, so adbd's default AIO path is
the tested one.

### init fatal errors and the recoverable reboot

`BOARD_KERNEL_CMDLINE` carries `androidboot.init_fatal_reboot_target=recovery`
(`BoardConfig.mk`). init reads it once in `SetFatalRebootTarget()`
(`system/core/init/reboot_utils.cpp`) and stores it; without the option the
default is `bootloader`. Every fatal exit path then funnels through
`InitFatalReboot()`, which calls `RebootSystem(ANDROID_RB_RESTART2, "recovery")` —
the kernel `LINUX_REBOOT_CMD_RESTART2` with the argument `recovery`, which MTK's
LK maps back to the recovery partition. So an init `LOG(FATAL)`, `CHECK()` or
fatal signal parks the device in recovery instead of hanging at the logo.

There are two ways to reach it:

* **`LOG(FATAL)`/`CHECK()` in PID 1.** `InitKernelLogging()` installs the
  `InitAborter` (`init/util.cpp`) as libbase's aborter, so a fatal log from init
  aborts through `InitFatalReboot()` before it even raises a signal. This is
  unconditional: it applies to user builds too, not only debuggable ones.
* **Fatal signals.** `InstallRebootSignalHandlers()` catches
  SIGABRT/SIGBUS/SIGFPE/SIGILL/SIGSEGV/SIGSYS/SIGTRAP and forks to
  `InitFatalReboot()`. It is installed only when `REBOOT_BOOTLOADER_ON_PANIC` is 1,
  i.e. debuggable builds (userdebug/eng — the CI default), from
  `FirstStageMain()`, `SetupSelinux()` and `SecondStageMain()`. A user build takes
  the kernel default instead.

The sites init can reach on this device, in boot order:

| Phase | Site | Fires when |
| --- | --- | --- |
| first stage | `first_stage_init.cpp:179` | one of the `CHECKCALL` mounts/mkdirs (`/dev`, `/dev/pts`, `/proc`, `/apex`, ...) failed |
| first stage | `first_stage_init.cpp:219`, `switch_root.cpp:41-94` | `DoFirstStageMount()` failed: the ramdisk fstab `/system`/`/vendor` entry could not be resolved or mounted, or the `/system` pivot failed |
| first stage | `first_stage_init.cpp:244` | `/system/bin/init` missing after the pivot |
| selinux_setup | `selinux.cpp:428` | `LoadPolicy()` failed — split-policy load: unreadable `plat_sepolicy_vers.txt`, missing `vendor_sepolicy.cil`/`plat_pub_versioned.cil`, missing `mapping/<vers>.cil`, or `secilc` failed |
| selinux_setup | `selinux.cpp:435,440` | `security_setenforce()` mismatch, or `/sys/fs/selinux/checkreqprot` not writable |
| second stage | `selinux.cpp:506` (via `property_service.cpp`) | `plat_sepolicy_vers.txt` unreadable/empty when the property service starts |
| second stage | `init.cpp:350` | ueventd did not write `/dev/.coldboot_done` within 60 s |
| second stage | `property_service.cpp:128,131` | property area/contexts could not be initialised |
| second stage | `security.cpp:179,194` | mmap entropy / `kptr_restrict` setup failed |
| second stage | `service.cpp:203` | a `service` command line contains a `${prop}` that expands empty |
| second stage | `service.cpp:291-342` | a service's `rlimit`, `user`/`group`, `seclabel` or capabilities could not be applied |
| second stage | `service.cpp:389` | a `critical` service exited 4 times in 4 min or before `sys.boot_completed` |
| second stage | `ueventd.cpp:235,238` (ueventd) | a coldboot handler subprocess crashed; ueventd aborts, init restarts it, and after 4 crashes the `service.cpp:389` fatal fires |

Reachability notes for this tree:

* First-stage mount uses the ramdisk `/fstab.mt6765`, not the kernel DT. With
  `CONFIG_MTK_DM_VERITY_OFF=y` the `/system` and `/vendor` entries carry no
  `verify`/`avb` flags, so there is no verity check to fail; the realistic trigger
  is a missing/renamed `by-name` node, an unfinished fastboot flash, or a build
  that failed to install `fstab.mt6765_ramdisk` into the boot ramdisk. `/odm` is
  `first_stage_mount` but always flashed by the LOS OTA, so it mounts cleanly.
* The SELinux fatals are the ones to watch if the vendor policy plumbing changes.
  They should not fire in a normal build: `BOARD_VENDOR_SEPOLICY_DIRS` makes the
  build emit `vendor_sepolicy.cil` and `plat_pub_versioned.cil`,
  `BOARD_SEPOLICY_VERS` defaults to `PLATFORM_SEPOLICY_VERSION`, and the stock 8.1
  `/vendor/etc/selinux/*` is deliberately not imported, so `plat_sepolicy_vers.txt`
  and the `/system/etc/selinux/mapping/<vers>.cil` it names agree. The shipped CIL
  was verified to compile with `secilc` and pass all neverallows. When this path
  does fire, the log line above the fatal names the exact file.
* Only `ueventd` is `critical` among the services the platform `init.rc` starts;
  the vendor `critical` services are in `factory_init.rc` and `meta_init.rc`,
  which normal boot never imports. A service that merely crash-loops without
  `critical` is restarted, not fatal.
* A failing builtin in an action (`write`, `setprop`, `symlink`, ...) is *not*
  fatal — `Action::ExecuteCommand()` only logs it. The fatal expansion case is
  specific to a `service` command line (`Service::Start()` ->
  `ExpandArgsAndExecv()`).

Because init logs through the kernel logger, the fatal line lands in the kernel
log buffer, and the MTK ram console preserves the previous boot's log. After the
reboot into recovery, read it from TWRP: `adb shell cat /proc/last_kmsg` (created
0444 by `drivers/misc/mediatek/ram_console/mtk_ram_console.c`), or from
`/sys/fs/pstore/console-ramoops-0` (`CONFIG_PSTORE=y`,
`pstore-reserved-memory@54410000` in `mt6765.dts`). It holds the log *up to* the
fatal init line, which is the fastest way to tell which site above tripped.

### Vendor partition and VNDK

`TARGET_COPY_OUT_VENDOR := vendor` (required by build/make whenever
`BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE` is set) keeps the separate vendor image.
`TARGET_COPY_OUT_ODM := odm` is likewise required because
`BOARD_ODMIMAGE_FILE_SYSTEM_TYPE` is set; this is what places the precompiled
SELinux policy in `/odm` (see *Boot, system-as-root and first-stage mount*).

`BOARD_VNDK_VERSION := current` in `BoardConfig.mk` selects **full VNDK**, matching
xiaomi-lotus-devs commit a53267f (lotus is also MT6765 and also 8.1-launched).
`PRODUCT_USE_VNDK` would stay false on its own: `core/config.mk` only auto-defaults
`BOARD_VNDK_VERSION` to `"current"` when `PRODUCT_SHIPPING_API_LEVEL` is 28+, and
this device ships at 27 — so the variable is set explicitly rather than inferred.

The consequence is that the vendor namespace is isolated. `ld.config.29.txt`
gives the vendor `default` namespace only `/odm/${LIB}` and `/vendor/${LIB}` plus
the VNDK/LLNDK sets, so a blob may **not** reach into `/system/lib[64]` unless the
library is LLNDK or VNDK. The 8.1 blobs' needs are covered three ways:

* **`VENDOR_CORE_LIBS`** (top-level `Android.mk`): core-only libraries the blobs
  `DT_NEEDED` are copied from the system build into `/vendor/lib[64]`
  (`libmedia`, `libcamera_client`, `libaudioclient`, `libnetd_client`,
  `liblogwrap`, `libsensor`, `libhwui`, `libpixelflinger`, `libandroid_runtime`,
  `libandroid_net`, `libkeystore_binder`, `libnativehelper`, `libprogrambinary`,
  `libaed`, `vendor.mediatek.hardware.camera.device@1.1`,
  `vendor.qti.hardware.soter@1.0`).
* **System-side VNDK copies** (`device.mk`): the 8.1 `/system` MTK blobs were
  linked when the system namespace was reachable; the libraries they need that
  are not LLNDK/VNDK are copied into `/system` for the system-side blobs.
* **`libbase-v28.so`** (`proprietary-files.txt`, with patched SONAME `libbase-v28.so`):
  the Android 8.1 `libbase`, copied into `/vendor/lib[64]` and `/system/lib[64]`.
  Blobs that import the 5-argument `android::base::LogMessage` constructor removed
  in AOSP 10 (sensors impl, `libnvram`, `libsysenv`, the widevine DRM service, the wifi
  service) had their `DT_NEEDED libbase.so` rewritten to `libbase-v28.so`.
  Patching its SONAME to `libbase-v28.so` ensures the dynamic linker does not treat
  it as `libbase.so`, preventing it from shadowing platform VNDK-SP `libbase.so`
  in processes that also load `libhidlbase.so` or `libcutils.so`.

`PRODUCT_EXTRA_VNDK_VERSIONS` is intentionally not used: there is no old VNDK
snapshot to install for an API 27 vendor.

#### ELF dependency closure and VNDK namespace repairs

A full-image `DT_NEEDED` closure audit (and a vendor-process namespace audit)
found and fixed the remaining gaps. The blob-side changes live in the vendor tree
(see its README); the device-side `proprietary-files.txt` tracks them:

* **`libutilscallstack.so`** added (`patchelf --add-needed`) to the camera
  libraries that import `android::CallStack` (`gralloc.mt6765`,
  `hwcomposer.mt6765`, `libsrv_um`, `libion_ulit`, `libmtkcam_stdutils`,
  `libmtkcam_debugutils`). The library itself is platform VNDK.
* **The libskia trio** (`libskia.so`, `libMMListParser.so`, `libgraphics2d_ext.so`,
  stock 8.1): `libhwuiext.so` needs `libskia.so`, which needs the two MTK-only
  libraries. They are extracted from the stock `/system/lib[64]` but installed
  **only to `/vendor/lib[64]`** via a `system/...:vendor/...` remap in
  `proprietary-files.txt` (AOSP `libhwui` links skia statically, so nothing in
  `/system` loads the shared libskia; a `/system` copy would only add a
  reverse-Treble dependency). The earlier `cp`-from-system hack in `Android.mk`
  was removed in favour of the direct remap.
* **Compatibility libraries** shipped vendor-local (or system, where the consumer
  is a system binary): `libLLVM.so` (`/vendor/lib64`, for `rs2spir`),
  `libbacktrace.so` + `libunwind.so` (`/vendor/lib[64]`, for
  `aee_aedv`/`libudf`), and `liblog-v28.so`
  (`/vendor/lib[64]`, the stock 8.1 liblog with soname rewritten, for `aee_aedv`'s
  legacy logprint API removed in AOSP 10; its `DT_NEEDED liblog.so` was rewritten
  to `liblog-v28.so`). The stock 8.1 `libsuspend.so` was removed: the
  platform's `libsuspend` exports the same `autosuspend_enable()` /
  `autosuspend_disable()` C symbols that `kpoc_charger` imports, and shipping a
  copy duplicated the `/system/lib/libsuspend.so` install rule.
* **VNDK namespace `DT_NEEDED` trims** (`patchelf --remove-needed` /
  `--replace-needed`) so vendor processes only reference vendor-local or
  LLNDK/VNDK-delegated libs: `sound_trigger.primary.mt6765` and
  `audio.usb.mt6765` (drop `libaudioclient`/`libmedia`), `libabfadp` /
  `libfactoryfmjni` (drop `libmedia`), the OPPO face service (drop
  `libkeystore_binder`), `libPolarrRender` / `libmpbase` (drop `libandroid`), and
  `libwapi` (`libkeystore_binder` → `libkeystore-wifi-hidl`, which exports
  `keystore_get`). These links were no-ops or only `__aeabi_*` helpers already
  provided by libc.

After these repairs the vendor-process namespace closure and the full-image
`DT_NEEDED` closure both resolve with zero unresolved entries.

### HIDL transport libraries

Android 10 merged `libhidltransport` and `libhwbinder` into `libhidlbase` and
removed the standalone libraries from `base_system.mk`. Every stock 8.1 vendor
binary — `camerahalserver`, `mtkfusionrild`, the audio, bluetooth, sensors, light,
PQ and composer services — carries explicit `DT_NEEDED` entries for both
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

The `.vendor` variants are needed because the 8.1 blobs live in the vendor linker
namespace; without them `ld-android.so` resolves the system copy but the vendor
namespace isolation rejects it.

### SELinux

`sepolicy/vendor/` labels the MediaTek and OPPO vendor binaries that AOSP does not
label. The stock 8.1 precompiled policy is excluded from `proprietary-files.txt`;
loading an 8.1 policy on Android 10 is a hard boot failure, not a compatibility
question. The shipped CIL (`plat_sepolicy.cil` + `mapping/29.0.cil` +
`plat_pub_versioned.cil` + `vendor_sepolicy.cil`) was verified to compile with
`secilc` and pass all 3449 neverallow assertions.

The file_contexts labelling was audited against the stock dump's `vendor/bin` and
`vendor/etc/init/*.rc` (all 201 services in 94 rc files) and against
`proprietary-files.txt`:

* Every path regex was checked against the binary it points at. Three were wrong
  and are fixed: `mtkfusionrild` (the real binary is `/vendor/bin/hw/mtkfusionrild`,
  per `rild.rc`), `wod` (the real binary is `epdg_wod`, per `init.wod.rc`) and
  `imsm` (the real binary is `volte_imsm_93`, per `init.volte_imsm_93.rc`).
* Entries for binaries this vendor image does not ship were dropped:
  `cas@1.0-service`, `thermald` and `6620_launcher`.
* Entries that merely re-label paths already covered by upstream
  `system/sepolicy/vendor/file_contexts` were dropped as redundant. checkfc only
  rejects a repeated path regex when the two entries give *different* contexts;
  the identical-context copies were harmless dead weight, not build breakers.
* Real services that ship and start but had no label were added: `aee_aedv` and
  `aee_aedv64`, `connsyslogger`, `bip` and `volte_imsm_93`, `epdg_wod`, `stp_dump3`,
  `wfca`, `oppoalgo_daemon` and `vtservice_hidl`. Each gets a new `mtk_*` domain in
  `device.te`, permissive like the rest.

A second audit pass covered the remaining runtime edges:

* `aee_core_forwarder` was unlabelled. It is the kernel `core_pattern` helper
  (`init.aee.rc` writes `/proc/sys/kernel/core_pattern`), so it is exec'd by the
  kernel usermodehelper rather than by init. It now has
  `mtk_aee_core_forwarder_exec`, the init **and kernel** transitions, an
  `aee_core_data_file` label for `/data/vendor/core`, and a permissive bring-up
  domain. The kernel→vendor execute neverallow (`public/domain.te`) is satisfied
  by adding `kernel` to the `system_executes_vendor_violators` attribute — AOSP's
  designated full-Treble exception (the attribute is `expandattribute false` and
  not in the treble `TestViolatorAttributes` list, so it does not trip the
  violator tests).
* `TBaseDeviceBinding` (the Trustonic provisioning helper run from a shell) now
  has `tbase_device_binding_exec` and the stock shell → `mcd` transition.
* `oppoalgo_daemon` registers `android.OPPO.IOppoAlgoDaemon` with
  vndservicemanager; the missing `vndservice_contexts` was added with the
  `oppoalgo_service` type and the stock `add_service` / `vndbinder_use` / client
  rules.
* `property_contexts` covers all 165 families in the stock
  `nonplat_property_contexts` (51 were missing), still mapped to
  `mtk_persist_prop`; the stock-evidenced setters got `set_prop` grants.
* The stock `seapp_contexts` assigns custom app domains to `com.gd.mobicore.pa`,
  `com.silead.fingerprint` and `com.mediatek.mtklogger.proxy`. Those domains are
  not ported: the APKs are re-signed with the platform key and run as
  `platform_app`. sileadManager talks to the vendor HIDL HAL rather than the
  device node, and the MTK logger proxy is not boot-critical, so this remains a
  documented divergence rather than a guessed domain.

The `.te` files use make-style `type_transition src type:process dst` (not CIL
`typetransition`); an earlier CIL-syntax mistake was corrected.

Two notes on services deliberately *not* given a domain:

* `init.mt6765.rc` retains the stock `service oae /system/bin/oae_server -s` entry
  with `seclabel u:r:oae_server:s0`. The service is disabled on the stock image as
  well: `oae_server` is a ColorOS-only system binary that neither the stock dump
  nor the OTA list ships, so Android init's `stat()` check fails and marks the
  service disabled before fork. It is kept for stock-image parity; no `oae_server`
  domain is declared or imported.
* The KTV HAL (`vendor.oppo.hardware.ktv@1.0-service`) is in the stock
  `vendor/etc/init/` but its binary and rc are not in `proprietary-files.txt`, so
  it never starts and needs no label.

Most vendor domains are `permissive` during bring-up, following the convention in
the policy file. This includes the standard AOSP HAL domains that the MTK vendor
blobs are assigned to (`hal_audio_default`, `hal_bluetooth_default`,
`hal_camera_default`, `hal_graphics_composer_default`, `hal_light_default`,
`hal_sensors_default`, `rild`): these domains are enforcing by default in AOSP and
lack rules for MTK-specific device nodes (`/dev/kd_camera_hw`, `/dev/mtk_sched`,
`/dev/ccci*`, `/dev/mtk_disp_mgr`, etc.), so denials on those nodes crash the
daemons immediately. Marking them permissive during bring-up logs the denials
instead of blocking them.

`device.te` also declares `gps_device` and `sw_sync_device` itself: both were
dropped from Android 10's `system/sepolicy/public/device.te`, but the MT6765
kernel still exposes `/dev/gps`, `/dev/stpgps` (opened directly by `mnld` /
`mtk_agpsd`) and `/dev/sw_sync` (legacy sync fences used by the display driver),
so the device-local types are required.

The biometrics policy mirrors the stock 8.1 vendor policy: `silead_fpd_device`
(`/dev/silead_fp`), `egis_device` (`/dev/esfp0`), `silead_fpd_data_file`
(`/data/{vendor,system}/silead`, `/persist/silead`), `face_data_file` and
`face_picture_file` are labeled with the stock types, and `device.te` grants
`hal_fingerprint_default` / `hal_face` the same sensor-node and data-file allows
the stock rules had. The DT2W proc node is labeled `proc_dt2w`
(`genfs_contexts`) and `hal_power_default` is granted write access
(`hal_power_default.te`), so DT2W is not dependent on the permissive bring-up.

Convert the denials the permissive domains log into `allow` rules and remove the
`permissive` lines before shipping.

### VINTF

`manifest.xml` carries the CPH1909 stock vendor HAL declarations (Android 8.1
blobs) plus the HALs LineageOS 17.1 builds: `android.hardware.health@2.0`,
`android.hardware.usb@1.0`, `android.hardware.power@1.0` (served by the AOSP HIDL
service that forwards to `power.mt6765`, used for DT2W),
`android.hardware.light@2.0` (served by the source-built
`android.hardware.light@2.0-service.CPH1909`), and
`android.hardware.biometrics.fingerprint@2.1` (AOSP interface backed by the Silead
legacy-HAL shim) and `android.hardware.biometrics.face@1.0` (the source-built
proxy). The `drm@1.2` clearkey instance is provided by a VINTF fragment, not listed
statically (see below). It declares `target-level="2"`. The file is formatted in
the expanded VINTF style (per-hal `<version>`/`<interface>`/`<fqname>` blocks).

This is the key legacy-Treble setting. Android 10 replaced the old
`PRODUCT_COMPATIBILITY_MATRIX_LEVEL_OVERRIDE` with the `target-level` attribute on
the device manifest. API 27 corresponds to FCM level 2 (O-MR1), so the Q framework
validates the vendor HALs against the frozen O-MR1 compatibility matrix.
`assemble_vintf` would infer level 2 from `PRODUCT_SHIPPING_API_LEVEL=27` even
without the attribute, but only after printing a warning. All ten HALs that FCM 2
marks as required are present in this manifest. The stock 8.1 vendor device matrix
is replaced by `compatibility_matrix.xml` in this tree (`DEVICE_MATRIX_FILE`),
which keeps the framework requirements the 8.1 vendor blobs expect
(`android.frameworks.{schedulerservice,sensorservice}`, `android.hidl.*`,
`android.system.wifi.keystore`) in Android 10 VINTF format.

`android.hardware.cas` and `android.hardware.drm@1.2` (clearkey) are *not* listed
in the static manifest: `base_vendor.mk` always builds
`android.hardware.cas@1.1-service`, and `device.mk` builds
`android.hardware.drm@1.2-service.clearkey`. Both packages ship their own VINTF
fragments, and a second entry for the same HAL name and major version is rejected
by `assemble_vintf` with a duplicate-instance error. The stock 8.1 `cas@1.0-service`
daemon is likewise dropped in favour of the AOSP 1.1 service
(`@1.1::IMediaCasService` extends `@1.0`).

### Keymaster and gatekeeper HAL modules

Android locates a HAL implementation with `hw_get_module_by_class()`, which tries
`"<class>.<ro.hardware>.so"` before falling back to `"<class>.default.so"`. With
`ro.hardware=mt6765` that means `keystore.mt6765.so` and `gatekeeper.mt6765.so`.
The vendor image carries no symlinks and ships the MediaTek TEE modules under
their own names, so the loader could not find either one and both services came up
in a degraded mode — keymaster printed "Could not find any keystore module, using
software-only implementation." and gatekeeper failed to open at all.

`Android.mk` installs the names the loader expects as symlinks next to the blobs:

| module name             | target                 |
| ----------------------- | ---------------------- |
| `keystore.mt6765.so`    | `libMcTeeKeymaster.so` |
| `gatekeeper.mt6765.so`  | `libMcGatekeeper.so`   |
| `gatekeeper.default.so` | `libSoftGatekeeper.so` |

`kmsetkey` needs no alias: `ro.hardware.kmsetkey=trustonic` in `vendor.prop` makes
the loader open the shipped `kmsetkey.trustonic.so` directly.

Keeping the TEE keymaster has one consequence: the stock `libMcTeeKeymaster.so`
implements generate/import/begin/update/finish but has **no `delete_key` or
`delete_all_keys` ops**. `Keymaster2PassthroughContext` calls those null
pointers unconditionally during fingerprint enrollment. Android 10's CFI check
catches the null indirect target and aborts the keymaster HAL; disabling CFI
only converted that abort into a `SIGSEGV` at `pc 0x0`. A dead keymaster makes
`ILockSettings.verifyCredential()` return null, and Settings then crashes with
`NullPointerException` in `LockPatternUtils.checkPattern()`; on a later boot
it also produced `Failed to decrypt blob` in `system_server`.

`patches/0004-keymaster-null-delete-ops.patch` (applied by the build workflow
after `repo sync` via its `.project` companion) adds null checks in
`system/keymaster/contexts/keymaster2_passthrough_context.cpp` and returns
`KM_ERROR_OK` when the legacy module has no delete op. Key blobs are managed by
keystore, so a no-op delete is safe here. CFI stays enabled. Credentials
enrolled with the TEE keymaster remain usable; reflashing a build that instead
uses the software keymaster invalidates them and requires clearing the lock
credential once.

### Resource overlay

`DEVICE_PACKAGE_OVERLAYS` points at `overlay/`, which is extracted from the stock
CPH1909 `framework-res.apk` and limited to resources that LineageOS 17.1 still
defines. `overlay/README.md` records the input hashes and the complete accounting:
603 stock resources also exist in LOS 17.1, 66 differ, 47 are stock device
configuration and are emitted, 19 are ROM policy and are excluded with a reason,
and 537 are identical. Four additional values describe device capabilities that
the stock framework does not attest; they are listed with their evidence in
`overlay/README.md`.

* `frameworks/base/core/res/res/values/config.xml` — device configuration: display
  and auto-brightness, the waterdrop cutout, navigation bar, ACCDET audio jack,
  proximity suspend, the MediaTek `networkAttributes` table, MMS user agent, Wi-Fi
  capabilities and RSSI thresholds, tether regexes, Bluetooth HFP/power values,
  multi-user, auto power modes and the icon mask. Every entry is the stock 8.1
  value except the capability overrides noted below.
* `frameworks/base/core/res/res/values/dimens.xml` — the stock `status_bar_height`
  (28dp = 56px at 320dpi, clearing the 55px notch) under the LOS 17.1 name
  `status_bar_height_portrait`, plus the 82px hardware corner radius.
* `frameworks/base/packages/SystemUI/res/values/dimens.xml` — the 82px
  `rounded_corner_content_padding` used as the navigation bar's start/end margin.
* `frameworks/base/core/res/res/xml/power_profile.xml` — the stock energy model
  with the 8.1 CPU keys mapped to the names Android 10 reads
  (`cpu.speeds.clusterN` → `cpu.core_speeds.clusterN`, `cpu.active.clusterN` →
  `cpu.core_power.clusterN`; `dsp.audio`/`dsp.video` → `audio`/`video`), both
  clusters included and the 4230 mAh battery.

The `config.xml` overlay is grouped as follows:

**Display and brightness.** AOSP 10 ships empty `config_autoBrightnessLevels` and
`config_autoBrightnessLcdBacklightValues` arrays, which makes
`BrightnessMappingStrategy.create()` return null, so auto-brightness is unavailable
and manual brightness has no device curve. The overlay supplies the stock lux
thresholds (`45, 1025, 1480, 2250, 3300, 10000`), the matching backlight levels
(`8, 22, 48, 78, 128, 206, 255`), the stock debounce/sampling values and
`config_automatic_brightness_available=true`. The vendor side is the source-built
lights HAL (see *Lights HAL* below), which writes
`/sys/class/leds/lcd-backlight/brightness`. The manual range is the stock CPH1909
one: minimum `1`, default `44` of `255` (dark/doze `2`). The waterdrop notch cutout
(`M -105,0 L -105,55 L 105,55 L 105,0 Z`) is overridden too;
`config_mainBuiltInDisplayCutoutRectApproximation` follows the cutout string
automatically. `config_showNavigationBar=true` because the device has no
capacitive navigation buttons.

**Input, sensors and audio jack.** The MTK ACCDET driver
(`CONFIG_MTK_PMIC_CHIP_MT6357`) reports `SW_HEADPHONE_INSERT` /
`SW_MICROPHONE_INSERT` through the Linux input subsystem, not through the legacy
`/sys/class/switch/h2w` uevent path. AOSP defaults
`config_useDevInputEventForAudioJack` to false, so the framework never saw headset
insertion; the stock ROM sets it true. The stock ROM also enables
`config_suspendWhenScreenOffDueToProximity`, so the proximity sensor turns the
screen off against the ear during a call.

**Double-tap to wake.** The stock 8.1 framework sets
`config_supportDoubleTapWake=false` (ColorOS handled the setting outside the AOSP
switch), so this is one of the documented capability overrides: the overlay adds
`<bool name="config_supportDoubleTapWake">true</bool>`, backed by the stock kernel
and the power HAL. The authoritative 8.1 kernel (`oppo6765_18511.dts`, multi-panel
SPI touch `ili_ts@0` on `spi3`) exposes `/proc/touchpanel/double_tap_enable` on the
Himax summer, NT36525B and Ilitek ipio_mmi panel drivers. `BoardConfig.mk` sets
`TARGET_TAP_TO_WAKE_NODE` to that proc node. On LineageOS 17.1 the Display toggle
writes `Settings.Secure.DOUBLE_TAP_TO_WAKE`, and `PowerManagerService` forwards it
as `IPower::setFeature(POWER_FEATURE_DOUBLE_TAP_TO_WAKE)` to
`android.hardware.power@1.0`. The default AOSP service loads the legacy
`libhardware` module and forwards `setFeature` to it, so this tree builds a small
`power.mt6765` shim (`power/`) — same `power_open()` device-class allocation, same
`LOG_TAG "MTKPowerHAL"`, the sustained-performance and VR-mode hint handlers, and
the DT2W write through `TARGET_TAP_TO_WAKE_NODE`. The node is labelled `proc_dt2w`
and `hal_power_default` is granted write access, so DT2W is not dependent on the
permissive bring-up. The stock legacy power HALs (`vendor/lib/hw/power.mt6765.so`
and `power.default.so`) are deliberately absent from `proprietary-files.txt`: they
installed to the same vendor path as the shim while having no proc-node writer at
all. `power.default.so` is built from AOSP's
`hardware/libhardware/modules/power` and installed unconditionally by the platform,
but the probe order makes it unreachable whenever `ro.hardware=mt6765` resolves
the shim. This shim only handles DT2W (other power hints/interactive are stubs);
the MTK vendor power interface (`vendor.mediatek.hardware.power@1.1-service`) is
separate and unchanged.

`power/Android.mk` is compiled only because the top-level `Android.mk` ends with
`include $(call all-makefiles-under,$(LOCAL_PATH))`. That include is load-bearing:
Soong's finder uses `FindFirstNamedAt` for `Android.mk`, which **stops descending**
once it matches a directory, so the top-level `Android.mk` hides every nested one.
Without the include the module was never parsed, `PRODUCT_PACKAGES += power.mt6765`
resolved to nothing, and the image shipped AOSP's `power.default.so` — whose
`power_module_t` has no `setFeature` member at all, so `Power::setFeature()`'s
`if (mModule->setFeature)` guard made `IPower::setFeature(DOUBLE_TAP_TO_WAKE)` a
silent no-op and DT2W never worked. The build system only warns about an
unresolvable `PRODUCT_PACKAGES` entry in `TARGET_BUILD_APPS` (sdk) builds, which is
why a normal ROM build stayed green. `ci.yml` now checks this explicitly. The same
mechanism builds the lights HAL (`light/Android.mk`).

After a build, confirm the shim is present and picked up:

```sh
ls out/target/product/CPH1909/vendor/lib{,64}/hw/power.mt6765.so
adb shell dumpsys power | grep -i double            # setting
adb shell 'ls -l /proc/touchpanel/double_tap_enable' # node exists
adb shell dmesg | grep -i MTKPowerHAL               # shim log lines
```

**Telephony.** `config_hotswapCapable=true` and the stock `networkAttributes` table
(including the MediaTek WAP, XCAP, RCS, BIP, VSIM and preempt connection types)
match the dual-SIM, hot-swap-capable modem (`ro.telephony.sim.count=2`,
`ro.radio.simcount=2`, `ro.mtk_sim_hot_swap=1`). `radioAttributes` is identical to
the AOSP 10 table and is therefore not overlaid. `config_num_physical_slots` is a
capability override set to `2` from the stock vendor `ro.telephony.sim.count=2`;
`UiccController` also raises the slot count to the number of RIL channels (2 here),
so the explicit value and the modem agree.

**Connectivity.** `config_wifi_dual_band_support` and
`config_wifi_background_scan_support` are set for the MT6765 802.11ac radio, and
the tethering regexes (`ap\d`, `rndis\d`, `bt-pan`/`bt-dun`) match the stock vendor
configuration (`wifi.tethering.interface=ap0`).

**Bluetooth.** HFP in-band ringing plus the stock Bluetooth power model
(`1/2/3` mA idle/rx/tx, `3300` mV) used by BatteryStats.

**UI and power.** `config_enableMultiUserUI` and `config_multiuserMaximumUsers=4`
are enabled as in the stock ROM, and `config_unplugTurnsOnScreen=true` restores the
stock behaviour of waking the screen when power is unplugged.

**SystemUI dimensions.** `navigation_layout.xml` uses
`rounded_corner_content_padding` as the start/end margin of the navigation bar,
and the framework uses `rounded_corner_radius` for its software corner masks. Both
are `82px`: all eight real 720x1520 LCM drivers in the stock a46 kernel set
`corner_pattern_height`/`corner_pattern_height_bot` to 82, and
`CONFIG_MTK_ROUND_CORNER_SUPPORT=y` enables the hardware mask.

The stock **`SysuiDarkThemeOverlay`** (`vendor/overlay`,
`com.android.systemui.theme.dark`) was **dropped**: it is a ColorOS theme-engine
RRO whose main override targets `style/qs_base`, which LineageOS SystemUI does not
define (LOS uses `qs_theme` / `QSHeaderTheme` plus night mode), so the style
override is inert; the lone `qs_detail_progress_track` color override is redundant
with the SystemUI default. LOS drives the SystemUI dark theme itself.

### Lights HAL

The proprietary MediaTek lights stack (`android.hardware.light@2.0-service-mediatek`,
`android.hardware.light@2.0-impl-mediatek.so`, `lights.mt6765.so`) is **dropped**
from the vendor tree and replaced by a source-built
`android.hardware.light@2.0-service.CPH1909` (`light/`), adapted from the LineageOS
light@2.0 template used by xiaomi-lotus (lineage-17.1) and oppo OP4BFB (lineage-20).

Hardware adaptation (authoritative kernel `oppo6765_18511.dts` + `mtk_leds_drv.c`):

* The only registered LED is **lcd-backlight** (`led@6`, `led_mode=4`, TDDI panel
  brightness control). red/green/blue/jogball/keyboard/button are all `led_mode=0`
  (`MT65XX_LED_MODE_NONE`) and are skipped at `led_classdev_register`, so the A5s
  has **no notification LED and no button backlight** (on-screen navigation keys).
  The HAL therefore advertises and handles **BACKLIGHT only** and returns
  `LIGHT_NOT_SUPPORTED` for notification/battery/attention.
* The MTK LED class does not set `max_brightness`, so `led-class.c` defaults it to
  `LED_FULL` (255). Hence `/sys/class/leds/lcd-backlight/brightness` is 0..255
  (lotus's 2047 is panel-specific and does not apply here).

`light/Android.mk` (not Android.bp, for the Soong-finder reason above) builds the
service; `device.mk` adds it to `PRODUCT_PACKAGES`; `file_contexts` labels the
binary `hal_light_default_exec`. The stock chain (service → dlopen impl →
`hw_get_module("lights")` → `lights.mt6765.so`) was self-contained — no other blob
references it — so dropping it loses nothing. `android.hardware.light@2.0::ILight`
is declared in `manifest.xml`.

### Input key layouts

AOSP 10 ships neither the MediaTek accessory-detect headset-button map
(`ACCDET.kl`) nor its keypad map (`mtk-kpd.kl`). Without them the wired headset
buttons (hook, media transport, `VOICE_ASSIST`) and the `mtk-kpd` key map fall back
to `Generic.kl`. The stock files are copied unchanged into
`/system/usr/keylayout/` through `PRODUCT_COPY_FILES`.

### Media profiles

Android 10's `MediaProfiles` only searches `/odm/etc` and `/vendor/etc` for
`media_profiles_V1_0.xml`, plus `/system/etc/media_profiles.xml`. The stock 8.1
vendor image ships its profiles as `/vendor/etc/media_profiles.xml`, so the
framework never finds them and camcorder recording has no device profiles. The
stock file is copied unchanged to `configs/media/media_profiles_V1_0.xml` and
installed as `/vendor/etc/media_profiles_V1_0.xml`, keeping the device's own
1080p/720p camcorder profiles and encoder capabilities.

### AAC decoder

The 32-bit vendor OMX service (`/vendor/bin/hw/android.hardware.media.omx@1.0-service`)
loads `libstagefright_softomx_plugin.so` from `/vendor/lib`, which then dlopens each
soft codec from the same `sphal` namespace. The installed image contains
`libstagefright_soft_aacdec.so` but **not** `libstagefright_soft_xaacdec.so`,
even though `configs/media/media_codecs_google_audio.xml` advertised
`OMX.google.xaac.decoder` for all of `audio/mp4a-latm`. Facebook/Instagram
AAC tracks therefore failed to instantiate a decoder:

```
MediaPlayerNative: error (1, -2147483648)
```

which is what made Facebook videos show a black surface with no sound. The
device copy now advertises `OMX.google.aac.decoder` (SoftAAC2), whose library is
present, for AAC-LC/HE-AAC. xHE-AAC (`mp4a.40.42`) is no longer claimed by the
config; restoring it requires fixing the `libstagefright_soft_xaacdec` build/install
first.

`configs/media/media_codecs_google_video_le.xml` stays empty: MediaTek's
hardware OMX video codecs in `media_codecs_mediatek_video.xml` cover AVC, HEVC,
VP9 and MPEG4. Both XML overrides are listed in `device.mk` before the vendor
makefile is inherited, because `PRODUCT_COPY_FILES` keeps the first source for
a destination.

### Codec2 ION SIGBUS (SystemUI / system_server)

A boot log from the reverted-GPU build still showed a crash loop: 44 tombstones
with `signal 7 (SIGBUS)` in `android::MediaCodec::queueCSDInputBuffer()`, split
between `com.android.systemui` and `system_server`, and 53 matching kernel lines

```
Unhandled fault: level 3 address size fault (0x92000043) at 0x...
```

All crashes are the same 30-byte `memcpy` into a 32 KiB `anon_inode:dmabuf`
mapping. The source begins with `\x01vorbis`: MediaCodec is queueing the Vorbis
identification header into `c2.android.vorbis.decoder`'s input buffer. The
buffer comes from Codec2's platform allocator (`allocatorID 16`,
`C2AllocatorIon`), and the same boot log shows repeated
`ion ioctl c0044901 failed with code -1: Invalid argument`. The first write to
that mapping faults at PTE level, so each attempt to open an `audio/vorbis`
stream kills both processes and they restart into the same state.

`debug.stagefright.ccodec=0` in `system.prop` is the supported Android 10 knob:
`Codec2InfoBuilder::buildMediaCodecList()` treats option 0 as "no Codec 2.0
components are available", so `c2.android.vorbis.decoder` never enters
`MediaCodecList` and `MediaCodec::GetCodecBase()` never creates a `CCodec`.
The stream then fails to find a decoder instead of SIGBUS-ing the two
processes; the device has no working OMX Vorbis decoder either (AOSP 10 no
longer builds `libstagefright_soft_vorbisdec` and stock ColorOS has no MTK
hardware Vorbis codec), so Vorbis playback is the cost of stopping the crash
loop. Setting `debug.stagefright.c2-poolmask` does *not* work here: on
LineageOS 17.1 `DEFAULT_LINEAR` resolves to the ION allocator too.

### RIL Parcel ABI (mtkfusionrild)

The same boot log also has `mtkfusionrild` tombstones with `SIGABRT` and

```
Abort message: 'stack corruption detected (-fstack-protector)'
#02 pc ... /vendor/lib64/libmtk-ril.so (RilOemClient::executeThermal(char*)+552)
```

The crash happens while handling the `THERMAL,0,0,0,0` OEM indication, after
the request has already been parsed and enqueued. The stock blob was built
against Android 8.1's `libbinder`, where `sizeof(android::Parcel)` is 104
bytes. LineageOS 17.1 loads `/system/lib64/vndk-29/libbinder.so`, whose
`Parcel` is 120 bytes: Android 10 inserted `mRequestHeaderPresent` and
`mWorkSourceRequestHeaderPosition` before the flags, moving the trailing
`mOpenAshmemSize` from offset 96 to offset 112. `Parcel::initState()` writes
that field, so every constructor/destructor writes eight bytes past the
8.1-sized object.

In `executeThermal()` the object is at `sp+8` and the stack canary is at
`sp+120`; the `mOpenAshmemSize` store lands exactly on the canary, and the
epilogue calls `__stack_chk_fail`. `executeShutDownByThermal()` has the same
frame. The two AGPS handlers (`RtcAgpsNSlotController::sendAgpsMessage()` and
`RtcAgpsdAdapter::processInput()`) allocate the object with `new(0x68)`, so
the same store overflows the heap allocation.

`RilClient::requestComplete()` has a third variant: the Parcel starts at
`sp`, the canary is at `sp+104` and the saved `x25` is at `sp+112`. The
canary lands in Android 10's `mOwnerCookie`, which `initState()` never
writes and which is only read when `mOwner` is set (it is always null here),
so the canary survives. `mOpenAshmemSize` at 112, however, covers the saved
`x25`; `initState()` zeroes it, so the epilogue restores `x25 = 0` into the
caller -- a callee-saved register ABI violation.

`RilClient::processCommands()` was audited too and needs no patch: its
Parcel is at `sp+0x10`, so the 120-byte object ends at `sp+0x88` while the
canary is at `sp+0xd8`. The 92-byte property buffer at `sp+0x7c` overlaps
only the object's `mOwnerCookie`/`mOpenAshmemSize` tail, `mOwner` remains
null, and the destructor never reads those overlapped fields.

Fifteen blobs in the vendor tree reference `android::Parcel`, but only
`libmtk-ril.so` is loaded by this boot; the rest (camera, codec, DRM and
video-telephony libraries) never appear in the log. Within `libmtk-ril.so`
the six constructions above are the only ones, and the blob imports no
ashmem or `ipcSetDataReference` entry point.

`tools/patch-mtk-ril-parcel-abi.py` applies eight instruction patches to the
stock blob: it moves the two thermal-handler Parcels from `sp+8` to the
unused `sp+0..7` slot, so the 120-byte object ends at `sp+120` immediately
before the canary; changes the two AGPS allocations from 104 to 120 bytes;
and moves `requestComplete()`'s saved `x25` from `sp+112` to the free
`sp+120` slot just past the 120-byte object. `extract-files.sh` runs the
script after adding the `libutilscallstack.so` dependency, and the patched
64-bit blob is committed in the vendor tree. (Only `/vendor/lib64/libmtk-ril.so`
is loaded by the 64-bit `mtkfusionrild`; the script skips the unused 32-bit
copy.) The two thermal handlers never call a method on their Parcel; the
shift keeps the constructor/destructor pair valid without changing the
request path.

### Properties

Both property files were audited against the stock firmware dump
(`system/build.prop`, `vendor/build.prop` and `vendor/default.prop`) and against
the Android 10 / LineageOS 17.1 sources that read them. Two rules follow:

* The stock 8.1 blobs read the **unprefixed** `ro.mtk_*` names that the stock vendor
  `build.prop` set. The `ro.vendor.mtk_*` names used by Android-10-era MTK trees
  only work with Android 10 vendor blobs, so they are not used here.
* Properties that no stock image for this device ever set and that no Android 10
  reader consumes are left out rather than borrowed from other MTK trees.

`system.prop` (framework side) carries, grouped in-file: display/camera/audio
(`ro.sf.lcd_density=320`, `ro.camera.sound.forced=0`, `ro.audio.silent=0`);
radio/Wi-Fi (`rild.libpath=mtk-ril.so`, `rild.libargs=-d /dev/ttyC0`,
`wifi.interface=wlan0`, `wifi.direct.interface=p2p0`, `wifi.tethering.interface=ap0`,
the MediaTek Wi-Fi feature gates and `qemu.hw.mainkeys=0`); Dalvik
(`ro.config.low_ram=false`); crypto (`ro.crypto.allow_encrypt_override=true`, see
*Encryption*); and the MediaTek framework knobs (`ro.kernel.zio`,
`ro.zygote.preload.enable=0`, the `ro.mtk_perf_*` hints). Zygote is set by
`core_64_bit.mk` (`ro.zygote=zygote64_32`), not here.

`vendor.prop` (vendor side) holds the subset of the stock vendor
`build.prop`/`default.prop` that the prebuilt blobs and their rc files actually
read, **regrouped by subsystem** (Audio, Dirac, Camera, Display, DRM, Media, FM,
GPS, Radio, IMS, Modem/CCCI, Wi-Fi, Bluetooth, WFD, Platform, Storage, USB, Dalvik,
Power, Misc) with the comments trimmed to the load-bearing notes. Notable entries:

* **Audio**: the Dirac suite (`persist.dirac.*`), `ro.mtk_audio_tuning_tool_ver=V2.2`,
  `ro.audio.usb.period_us=16000`, and **`ro.audio.ignore_effects=true`**. The last
  makes `EffectsFactory init()` skip `EffectLoadXmlEffectConfig` entirely. The
  stock 8.1 MTK effects path can crash in `libeffects.so` and watchdog-reboot
  `system_server`; this tree ships no `audio_effects.xml`/`.conf` or soundfx libs
  (AOSP builds `libeffects`), so the switch only disables optional effects and
  removes the crash path. Being `ro.*` it cannot be overridden by a stale
  `/data/property` value. The Aurisys tuning set (`vendor/etc/aurisys_config.xml`,
  `vendor/etc/aurisys_param/*`) is loaded by the MTK audio HAL from its fixed path,
  so no `vendor.audiohal.aurisys.*` property is needed.
* **Display / graphics**: `ro.surface_flinger.has_wide_color_display=false`,
  `ro.surface_flinger.has_HDR_display=false`, `debug.sf.disable_backpressure=1`,
  `debug.sf.latch_unsignaled=1`, `ro.opengles.version=196610`, `ro.sf.hwrotation=0`,
  and — critically — `ro.hardware.egl=mtk`. The Android 10 EGL loader appends
  `ro.hardware.egl` to `libEGL_`; this device ships `libEGL_mtk.so` /
  `libGLESv2_mtk.so`, so without it the loader looks for the non-existent
  `libEGL_mt6765` and SurfaceFlinger never starts.
* **Camera, DRM/Media, FM/GPS/radio/telephony, Bluetooth, Storage/init/USB,
  Platform/TEE, Wi-Fi, Dalvik**: the stock values, including
  `media.settings.xml=/vendor/etc/media_profiles_V1_0.xml`,
  `persist.bluetooth.a2dp_offload.disabled=true` (the prefix-less name the AOSP
  stack reads), `ro.hardware.kmsetkey=trustonic`, and
  `dalvik.vm.heapgrowthlimit=384m` / `dalvik.vm.heapsize=512m`.

The ColorOS-only values (`ro.com.google.gmsversion`, `ro.setupwizard.*`,
`pm.dexopt.*`, the `persist.log.tag.*` block and the `ro.mtk_*` feature switches
that no prebuilt blob consults) are deliberately dropped.

#### Properties deliberately not carried over

These were added at various points but have no reader (or no stock backing) on this
device, so they were removed: `ro.keystore.disable_strongbox` (not read; the
Trustonic TEE is keymaster 3.0, no StrongBox anyway);
`ro.crypto.dm_default_key.options_format.version` (does not exist in Android 10
`vold`); `ro.charge.animation.hz` (ColorOS charger-app property, no LineageOS
reader); and the `persist.vendor.radio.gps.support` / `ro.vendor.mtk_*` /
`persist.vendor.camera3.zsl.enable` / `ro.vendor.bt.stack` / extra
`persist.vendor.*.usb.config` / `audiohal` set — none exist in this device's stock
dump (or they use the Android-10 `ro.vendor.` namespace its 8.1 blobs do not read).

### Not taken from the stock dump

The stock ROM also carries system-side, device-specific files that this build has
no use for, so they are intentionally neither extracted nor copied:

* `system/etc/bluetooth/` — AOSP's own Bluetooth stack installs the generic
  `bt_stack.conf` and `bt_did.conf`; the remaining stock files there
  (`mtk_bt_stack.conf`, `mtk_bt_fw.conf`, `bt_mtk_iot_list.conf`,
  `profile_version.conf`) are read only by MediaTek's patched `bluetooth.default.so`,
  which is not shipped. Device tuning goes through `bluetooth/bdroid_buildcfg.h`.
* `vendor/etc/fs_config_files` sets the two MTK HAL binaries to be owned by the
  `audioserver`/`bluetooth` accounts. On Android 10 the file ownership comes from
  the generated `fs_config` and the process credentials from the `user` directive
  in each HAL's `.rc`, so the stock override is not needed.

### Encryption

The device ships full-disk encryption with the key blob on the `metadata`
partition, backed by the Trustonic TEE — not file-based encryption. The stock ROM
used `forceencrypt=`; this port deliberately uses `encryptable=` instead, so an
already-encrypted /data is decrypted through the metadata key while an unencrypted
/data is mounted as-is rather than triggering in-place encryption on first boot.
`BOARD_USES_METADATA_PARTITION := true` creates `/metadata`.

The fstab entry is classic FDE (`encryptable=<metadata partition>`), not
dm-default-key metadata encryption and not file-based encryption, so of the
`ro.crypto.*` switches only one is both real and relevant on Android 10:

```properties
ro.crypto.allow_encrypt_override=true
```

`vold`'s `cryptfs.cpp` reads it when `fscrypt_is_native()` and adds
`allow_encrypt_override` to the dm-crypt table, letting the encryption path override
the encryption mode instead of failing when the footer and the requested mode
disagree. `ro.crypto.volume.filenames_mode` is read by `FsCrypt.cpp` only when
creating volume keys for adoptable storage, and
`ro.crypto.dm_default_key.options_format.version` does not exist in the Android 10
`vold` at all, so neither is set. The TEE side is the `ro.mtk_tee_gp_support` /
`ro.mtk_trustonic_tee_support` / `ro.hardware.kmsetkey=trustonic` block under
*Properties*.

### Other build changes

* `BUILD_BROKEN_DUP_RULES := true` — the blob set and AOSP both install several of
  the same paths; the blob wins Make parse order, which is what we want for the
  MediaTek binaries.
* `BUILD_BROKEN_PREBUILT_ELF_FILES := true` — Android 10's `check_elf_file.py`
  verifies DT_NEEDED entries resolve within the declared VNDK set; the 8.1 vendor
  blobs predate these checks and carry entries like `libhidltransport.so` /
  `libhwbinder.so` that would fail the validator.
* `BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true` — suppresses the parallel
  check that flags ELF binaries installed through `PRODUCT_COPY_FILES`.
* `BUILD_BROKEN_USES_BUILD_COPY_HEADERS := true` — downgrades the removed
  `BUILD_COPY_HEADERS` idiom from error to warning.
* `BOARD_AVB_ENABLE := false` — the bootloader is locked to OPPO keys and this build
  is not signed by them; the device has no vbmeta partition.
* `VENDOR_SECURITY_PATCH := 2021-04-05` — the stock system build.prop's
  `ro.build.version.security_patch`, so `ro.vendor.build.security_patch` reports the
  real level of the frozen 8.1 vendor blobs.
* `androidboot.init_fatal_reboot_target=recovery` — a fatal init failure reboots
  into recovery instead of hanging at the boot logo.
* `androidboot.selinux=permissive` — BRING-UP ONLY. init's `StatusFromCmdline()`
  reads it from the kernel command line and runs the policy in permissive mode
  before any actions execute (debuggable builds only; the CI default is userdebug;
  user builds ignore it). Useful while the sepolicy is still being brought up, and
  it makes the permissive domains in `sepolicy/vendor/device.te` redundant. Remove
  before shipping a release.

### PowerVR texture swizzle and the SystemUI RenderThread abort

**Status:** root cause established from 50 tombstones, LineageOS 17.1 Skia/HWUI
sources, and disassembly of the stock PowerVR driver. The fix is committed
(`d4da4a4`) but **not yet built or flashed** — no CI build was triggered.

#### Symptom

* All 50 captured tombstones are `com.android.systemui`, thread
  `RenderThread`, SIGABRT.
* Abort message is identical in all of them:
  `GL errors! frameworks/base/libs/hwui/pipeline/skia/SkiaOpenGLPipeline.cpp:126`.
* Backtraces are byte-identical: `abort` → `__android_log_assert` →
  `SkiaOpenGLPipeline::swapBuffers+172` → `CanvasContext::draw+320` →
  `DrawFrameTask` → `WorkQueue::process` → `RenderThread::threadLoop`.
* The only GL-related log line before the fatal is
  `E OpenGLRenderer: GL error:  GL_INVALID_ENUM`.

#### Where the abort comes from

`libs/hwui/Debug.h` defaults `DEBUG_OPENGL` to `DEBUG_LEVEL_LOW` on userdebug
builds. `GL_CHECKPOINT(LOW)` is the **first statement** of
`SkiaOpenGLPipeline::swapBuffers()` and expands to
`LOG_ALWAYS_FATAL_IF(GLUtils::dumpGLErrors(), ...)`. The invalid call is
therefore **not** in the swap — the error is latched during the preceding
`renderFrame()` and merely detected at the swap checkpoint.

#### Tombstone timeline (`tombstone_00`, representative)

| Time | Thread | Event |
| --- | --- | --- |
| 00:22:50.833 | 4486 (RenderThread) | `I OpenGLRenderer: Davey! duration=921ms` — previous frame succeeded |
| 00:22:50.943 | 4453 (main) | `W Gralloc3: allocator 3.x is not supported` — `GraphicBuffer` allocation on the main thread |
| 00:22:50.987 | 4486 (RenderThread) | `E OpenGLRenderer: GL error:  GL_INVALID_ENUM` |
| 00:22:50.987 | 4486 (RenderThread) | `F OpenGLRenderer: GL errors! ...SkiaOpenGLPipeline.cpp:126` → abort |

29 of 50 tombstones have exactly this three-line tail; the rest add only
StatusBar/ImageWallpaper lines from other threads. Red herrings in the same
tail:

* `ImageWallpaper` draws on its own GL thread (tid 4499) through
  `ImageGLWallpaper`/raw GLES, not through the HWUI RenderThread. Its lines are
  coincidental in time.
* `W Gralloc3: allocator 3.x is not supported` is the normal gralloc3→gralloc2
  fallback; the allocation it accompanies is relevant, not the warning.
* The main thread at crash is in `RenderProxy::setStopped` ←
  `HardwareRenderer.setStopped` ← `ViewRootImpl.performDraw+1232`, i.e. the
  normal post-draw sync, not a teardown trigger.
* Early `E ion: ioctl c0044901 failed ... EINVAL` (`ION_IOC_FREE`) is init noise,
  long before the failing frame.

#### The failing call chain

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
4. REA of the stock PowerVR GLES driver `libGLESv2_mtk.so` (SHA-256
   `8e846a0186afb469de0823f0a8ddb6ba2d0659d11677341b7ba8b6d431a6bb17`):
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

#### The fix

The workaround is the one phh's GSI uses for PowerVR Rogue devices:

* `patches/0001-skia-ignore-vendor-texture-swizzle.patch` (from
  `AndyCGYan/lineage_patches_unified`, lineage-17.1) makes, under
  `SK_BUILD_FOR_ANDROID`, `GrGLCaps::textureSwizzleSupport()` return
  `!GetBoolProperty("ro.skia.ignore_swizzle", false) && fTextureSwizzleSupport`.
  Skia then inserts the swizzle into shader code
  (`shaderCaps->fConfigTextureSwizzle`) instead of programming the texture unit.
* `system.prop` sets `ro.skia.ignore_swizzle=true`. Skia is linked statically
  into `libhwui` (the stock vendor `libskia.so` is not loaded by SystemUI), so
  the patch must be applied to `external/skia` at build time. `SK_BUILD_FOR_ANDROID`
  derives from `__ANDROID__` in `SkPreConfig.h`, so the branch compiles.
* `patches/0002-hwui-link-libbase.patch` adds `libbase` to the `hwui_static_deps`
  defaults in `frameworks/base/libs/hwui/Android.bp`. `GetBoolProperty()` lives
  in `libbase`, and `libhwui` pulls Skia in through `whole_static_libs`, which
  does not propagate `libskia`'s own `shared_libs` to the link line — without
  this, `libhwui.so` fails to link with an undefined `android::base::GetBoolProperty`.
* `.github/workflows/build.yml` applies both patches after `repo sync`, driven
  by their `patches/<name>.project` companion files, and fails the build if a
  patch no longer applies.

With the property set, `GrGLGpu::bindTexture()` skips the entire swizzle block,
so none of the rejected calls are made. Filter/wrap parameters sent to external
OES are accepted, and `BASE_LEVEL`/`MAX_LEVEL` are already suppressed on Android
(`fDontSetBaseOrMaxLevelForExternalTextures = true`, `GrGLCaps.cpp:2814`). This
does not replace any GPU blob: the stock `vendor/lib{,64}/egl` and
`libsrv_um.so` stay untouched, and HWUI's GL checks stay enabled for real errors.

#### Alternatives rejected

* **Kanged CPH2185 GPU blobs** — different PVR stack/kernel ABI; reverted
  (device `c98d89a`, vendor `4ec6b65`).
* **Full PVR 1.11 replacement** — needs a 4.9.190 kernel BSP port
  (`1.9@4971894` vs `1.11@5425693`).
* **`debug.hwui.renderer=skiavk`** — no vendor Vulkan HAL in the stock dump.
* **Non-fatal `GLUtils::dumpGLErrors()`** — masks every GL error instead of
  avoiding the invalid call; kept as a fallback only.
* **Runtime-only GL workaround** — `GL_CHECKPOINT` is compile-time; no property
  disables it.

#### Corroboration, caveats and verification

* A same-device GSI built from Andy Yan/phh sources works with this property
  while carrying the identical fatal checkpoint. Tombstones do not record the
  offending GL call, so attribution rests on the driver disassembly, the Skia
  source and that GSI precedent.
* Modem/airplane-mode initialization is a separate issue (`mtk.md1.status`
  stops at `bootup`, never `ready`) and is not addressed by this fix.
* Verification still needed: build and flash the tree with `d4da4a4` applied,
  confirm SystemUI no longer restarts and `GL error:  GL_INVALID_ENUM` is absent
  from logcat, and confirm `getprop ro.skia.ignore_swizzle` returns `true`.

## Known limitations / porting notes

* **Fingerprint** is wired to the AOSP biometric stack via
  `biometrics/fingerprint/` (`fingerprint.mt6765`, `proprietary`, multilib): it
  exports the `FINGERPRINT_HARDWARE_MODULE_ID` HMI (required because Android 10
  `libhardware` rejects an `hmi->id`/`class_id` mismatch) and `dlopen`s/forwards
  `open()` to the first working stock legacy vendor HAL, trying Silead
  (`fingerprint.silead.default.so`, API 2.1, `libsl_fp_impl.so`, `/dev/silead_fp`)
  then Egis (`fingerprint.egis.default.so`, API 2.1,
  `vendor.egistec.hardware.fingerprint@4.0.so`/`libRbsFlow.so`, `/dev/esfp0`) — the
  same order the stock service uses, recording the winner in
  `persist.sys.fp.vendor`. `ro.hardware` and `ro.board.platform` are both `mt6765`,
  so `hw_get_module_by_class("fingerprint")` resolves `fingerprint.mt6765.so` on its
  first variant key and never probes `fingerprint.default.so` — no `.default` alias
  is needed (and `hardware/libhardware/modules/fingerprint/` already builds a real
  `fingerprint.default`, so aliasing that path would fight the platform module).
  `device.mk` builds `android.hardware.biometrics.fingerprint@2.1-service` and
  first-wins `PRODUCT_COPY_FILES` overrides disable the stock ColorOS `fps_hal` /
  `fpay_hal` services, which register `vendor.oppo.hardware.biometrics.fingerprint@2.1`
  (not the AOSP interface) and would contend for the sensor node.
* **Face unlock** is userspace-only on CPH1909 (no face driver in the authoritative
  kernel; stock vendor face service/`libmegface`/`libstface*` blobs exist). AOSP 10
  ships no `android.hardware.biometrics.face@1.0` default service, and the vendor
  ships no legacy face HAL module, so unlike fingerprint there is nothing to wrap.
  `biometrics/face/` builds a source `android.hardware.biometrics.face@1.0-service`
  that registers the AOSP interface and forwards to the OPPO backend through
  `OppoFaceHal`. The stock backend implements a *custom*, vendor-namespaced interface
  (`vendor.oppo.hardware.biometrics.face@1.0::IBiometricsFace`, fingerprint-shaped),
  reconstructed from the stock interface library and **built** as a `hidl_interface`
  (`interfaces/vendor/hardware/biometrics/face/1.0/`; the exact source bytes are not
  in the dump, so the frozen hash differs — `getService()` matches by name). The
  stock `face_hal` service is **enabled** (its override rc does not set `disabled`)
  and its two DT_NEEDED interface libraries ship in `/vendor/lib{,64}`, so it can
  start. Forwarding is nevertheless **unverified on hardware**: operations with no
  faithful vendor equivalent (`getFeature`, `setFeature`, `userActivity`,
  `resetLockout`) deliberately return `OPERATION_NOT_SUPPORTED`; the per-method
  confidence notes are in `biometrics/face/OppoFaceHal.h`. The face feature XML is
  installed, so Settings surfaces the entry — but enrollment depends on the
  unverified forwarding. Boot-test to confirm shim load, `IBiometricsFingerprint/default`
  and `IBiometricsFace/default` registration, sensor-node access, that
  `fps_hal`/`fpay_hal` remain disabled, and that `face_hal` is running.
* **Lights** is the source-built BACKLIGHT-only HAL (see *Lights HAL*); the
  proprietary stack is dropped. There is no notification LED or button backlight on
  this device.
* The 8.1 vendor blobs are the highest-risk part of the port. The HIDL transport
  libraries (`libhidltransport`, `libhwbinder`) and their `.vendor` variants are
  installed to satisfy the blobs' `DT_NEEDED` entries. If HIDL services still fail
  to load, check `ro.hardware` / `ro.hardware.egl` and the linker namespace denials
  first. This is a full-VNDK build, so a vendor binary may **not** resolve a library
  from `/system/lib[64]` unless it is LLNDK or VNDK — if a blob fails with
  "library ... not found", the fix is another entry in `VENDOR_CORE_LIBS`
  (`Android.mk`), the *System-side VNDK* copy block (`device.mk`), or a vendor-local
  compatibility library (see the vendor README), not a linker-config override.
* Recovery: `TARGET_RECOVERY_FSTAB` points at the same fstab. The TWRP tree for this
  device is a separate branch and is not built from this one.
