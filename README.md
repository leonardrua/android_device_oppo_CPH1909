# OPPO A5s (CPH1909) recovery device tree

Minimal standalone TWRP tree. Builds `omni_CPH1909` recovery only
(`lunch omni_CPH1909-eng && mka recoveryimage`).

## Build (pinned to Android 8.1)

```
repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni \
          -b twrp-8.1
repo sync -j$(nproc)
cp -r <this-tree> device/oppo/CPH1909
. build/envsetup.sh && lunch omni_CPH1909-eng && mka recoveryimage
```

`PLATFORM_VERSION := 8.1.0` in `BoardConfig.mk` matches the `twrp-8.1` manifest
branch: the branch is what sets `PLATFORM_SDK_VERSION 27`, and that in turn
selects the FDE crypto path and the `mke2fs` image tooling. `PLATFORM_VERSION`
itself only feeds `ro.build.version.release`, so the two are kept in agreement
for documentation and OTA-assert purposes; CI fails if they drift apart.

The reference build for this device was also an SDK 27 (8.1) build, which is
what makes this branch the known-good choice. Confirmed from TWRP's own
version-gated modules in its ramdisk: `sload.f2fs` is absent (added only for
SDK >= 28), `event-log-tags` is present (added for SDK < 28), `ld.config.txt`
is present (SDK >= 26), and `libtwrpmtp-legacy.so` is linked (SDK < 28). The
"OmniROM 16.1.0" label in its tree is Omni's own version string, not Android 9.

This uses the manifest's own pairing, unmodified: `build/make`, `vendor/omni`,
boringssl and friends at android-8.1, with `bootable/recovery` at TeamWin
android-9.0 (TWRP 3.7). That is deliberate, not an accident — TWRP's
android-9.0 `Android.mk` is written to build on older platforms, gating its
Pie-only bits behind `-gt 27` and carrying an explicit "build errors in 8.1"
fix. If a future sync does break on the platform mismatch, the fix is a local
manifest override re-pinning `bootable/recovery` to `android-8.1` (TWRP 3.5)
via `repo init -m <file>` — not a change to this tree.

## Layout

- `omni_CPH1909.mk` — recovery-only product (core_64_bit + full_base_telephony
  + `vendor/omni/config/common.mk`, same inherit order as the proven CPH1920
  reference at https://github.com/SQR11211/android_device_OPPO_CPH1920).
- `BoardConfig.mk` — MT6765 board config, kernel offsets, `TARGET_RECOVERY_FSTAB`
  pointing at `recovery/root/etc/twrp.fstab`. No system/vendor/odm image
  definitions; `ALLOW_MISSING_DEPENDENCIES := true` so it builds without a
  populated `vendor/` tree.
- `device.mk` — copies recovery ramdisk init scripts plus `recovery/root/vendor`
  blobs (gatekeeper/keymaster services, mcRegistry, touch firmware, manifest)
  and the `recovery/root/system/lib64` + `recovery/root/sbin` runtime libs.
  No `PRODUCT_PACKAGES` entries: TWRP builds MTP in-tree (`libtwrpmtp` on 8.1,
  `libtwrpmtp-legacy` on 9.0) and the legacy `libmtp`/`mtp_server` modules are
  stripped from the manifest.
- `prebuilt/kernel` — prebuilt `Image.gz-dtb` (9979567) extracted from the
  working TWRP 3.7.0_9-1 recovery for this device
  (`tmp/oppo_a5s_twrp1_kernel.zip`, its `kernel.gz`), byte-identical to the
  A.46 dump boot kernel (SHA-256
  `76b59114fca90ce744c356c4a373714ea9f07299490d08b3ab52a92ba28bb6fc`);
  enabled via `TARGET_FORCE_PREBUILT_KERNEL`.
- `recovery/root/etc/twrp.fstab` — TWRP mount table aligned with the stock
  recovery fstab from recovery.img (SHA-256
  `d95131864444640c91eac2352e79568928f822ef5b0706d7fc283c16934f462a`,
  header v0, pagesize 2048, OS 8.1.0 patch 2020-10-05, project 18511).
  All 37 partitions of the MT6765 scatter table are mapped 1:1, including the
  renames: `misc`→`para`, `persistent`→`frp`, `bootloader`→`lk`,
  `bootloader2`→`lk2`, `opporeserve`→`opporeserve2`. `metadata` is
  deliberately absent — it is reached through `forceencrypt=`, never mounted.
- `system`, `vendor` and `odm` are each listed twice, which is the standard TWRP
  convention rather than a mistake. The `ext4` entry marks a mountable
  filesystem, so backup tars only its files; the `emmc` `*_image` entry marks
  a raw disk image, so backup dd-clones the whole partition including free
  space — the escape hatch for a filesystem that will not mount, or for
  restoring a foreign ROM. Google's and TeamWin's own trees ship the same
  pattern (see `recovery.fstab` in `android-9.0` for `xiaomi_beryllium` or
  `google_shamrock`).
  Those raw entries carry `flags=backup=0;flashimg=1`: `flashimg` keeps them
  available for restore/flashing, `backup=0` keeps them out of the backup list.
  Without it, "Select All partitions" archives the same three partitions twice
  — **5.77 GiB** of redundant raw images (system 4.20, vendor 1.31, odm 0.25
  GiB, sizes from the scatter table) on top of the tarballs, because a raw
  image includes the partition's empty space.
  The system-as-root caveat that sometimes makes only the `_image` form valid
  does not apply here: the scatter table has `system`, `vendor`, `odm`,
  `cache` and `userdata` as separate `EXT4_IMG` partitions, and this build sets
  `BOARD_BUILD_SYSTEM_ROOT_IMAGE := false`, so both entries describe the same
  whole partition.

Stock `/data` uses `forceencrypt` with the metadata partition (FDE), so TWRP
enables `TW_INCLUDE_CRYPTO`. The working TWRP build for this exact device
(`tmp/oppo_a5s_twrp_recovery_extracted.zip`, OmniROM 16.1.0
`eng.runner.20241027`, image SHA-256
`55d79d7065fa5681652d078b1c64d47bd573f4779ea49eb56aeda1c10ca83ca8`)
ships both vendor services — `vendor/bin/hw/android.hardware.gatekeeper@1.0-service`
and `keymaster@3.0-service` (66k each) with `vendor/lib64/hw/*-impl.so` +
`gatekeeper.mt6765.so` — so `init.recovery.mt6765.rc` starts both, matching
that build exactly.

What actually decides decrypt behaviour here is `PLATFORM_SDK_VERSION`, not
the `TW_INCLUDE_*` flags: at `PLATFORM_SDK_VERSION 27` TWRP compiles the FDE
path (`libcryptfsfde`, `libscrypt`) and force-enables
`TW_INCLUDE_CRYPTO_FBE` for SDK >= 24, while `TW_INCLUDE_FBE_METADATA_DECRYPT`
stays off because it needs SDK >= 28. TWRP 3.x has no `TW_INCLUDE_FBE`
variable and neither FBE flag can be disabled from `BoardConfig.mk` — both are
gated on the SDK version alone. The J0shua reference set
`TW_INCLUDE_FBE_METADATA_DECRYPT := true` explicitly and got nothing extra
for it: it compiled at SDK 27 too (see below), so that flag was just as inert
as anything this tree could set. Both trees end up with the same crypto build.

Note that `PLATFORM_VERSION` in `BoardConfig.mk` is *not* what selects that SDK
level — it only feeds `ro.build.version.release`. `PLATFORM_SDK_VERSION` comes
from the platform branch in the manifest. The J0shua tree proves the
distinction: it pins `PLATFORM_VERSION := 16.1.0` (OmniROM's label, not an
Android version) yet compiles at SDK 27. The two must still be kept in
agreement, so CI cross-checks them, but the branch is the real pin.

The recovery ramdisk uses `init.recovery.mt6765.rc` for Trustonic, Keymaster,
Gatekeeper, keystore services, plus the stock MT6765 preloader aliases.
`init.recovery.usb.rc` sets up the ConfigFS gadget `g1` on `on init`
with MTK `mtp.gs0` MTP (`/dev/mtp_usb`), `musb-hdrc` UDC, stock CPH1909
recovery USB ID `18d1:d001`, and `mass_storage.0` function matching
`BoardConfig.mk`. Includes robust triggers for `adb`, `sideload`, `mtp`, and
`mtp,adb`. The TWRP default USB init is disabled to avoid competing gadget
setup.

### MTP: why `mtp.gs0` and not `ffs.mtp`

TWRP chooses its MTP implementation by SDK level in
`bootable/recovery/Android.mk` (line 230): `PLATFORM_SDK_VERSION >= 28` builds
`mtp/ffs` → `libtwrpmtp-ffs` over FunctionFS, anything lower builds
`mtp/legacy` → `libtwrpmtp-legacy`, which talks to `/dev/mtp_usb`. The gadget
function has to match the library.

This tree inherits from the CPH1920 MTP fix
([SQR11211 4f007b8](https://github.com/SQR11211/android_device_OPPO_CPH1920/commit/4f007b8d4ffdc432af70b066367a936c73b2badc)),
which converted CPH1920 *from* `mtp.gs0` *to* `ffs.mtp` and dropped
`TW_MTP_DEVICE := /dev/mtp_usb`. That is the right pairing for an SDK 28+
platform and the wrong one here: at SDK 27 TWRP links `libtwrpmtp-legacy` and
would drive `/dev/mtp_usb` while the gadget advertises `ffs.mtp`, so MTP never
comes up. The working build for this device uses `mtp.gs0` together with
`libtwrpmtp-legacy.so`, so this file is back on the pre-4f007b8 form. ADB,
sideload and USB mass storage are unaffected either way.

The `/dev/mtp_usb` node this drives is set up by the platform's `ueventd.rc`,
which carries `/dev/mtp_usb 0660 root mtp` — verified in this build, in the
working CPH1909 build and in the stock 8.1 recovery. Note this tree's
`ueventd.reserve.rc` is never imported (ueventd only loads `ueventd.rc` +
`ueventd.$hardware.rc`), so it cannot be used to add rules.

`ueventd.reserve.rc` carries the stock opporeserve1 rules.
`sbin/hwservicemanager`, `system/lib64` binder/crypto/hidl runtime, and
`vendor/lib64` gatekeeper/keymaster/Trustonic libs (including `libMcClient.so`
and `libkeymaster_staging.so` from the ROM dump, plus all 30 `mcRegistry`
trustlets) are vendored. `twrp.fstab` storage nodes: `mmcblk1p1/mmcblk1` for
SD, `sda1/sda` for OTG (`/usb_otg` auto).

CPH1909 vs CPH1920: same MT6765/project 18511 hardware; per the CPH1920
README the only difference is CPH1920 lacks fingerprint hardware. The CPH1920
tree disables decryption (`TW_INCLUDE_CRYPTO := false`, Route B); this tree
keeps the FDE decrypt attempt per the CPH1909 stock analysis.

The J0shua CPH1909 reference (https://github.com/J0shua-code/Oppo-CPH1909-Device-Tree,
cloned to /tmp/j0shua_cph1909) is the source tree of the working TWRP build
above: same `init.recovery.mt6765.rc` (gatekeeper+keymaster from vendor),
same ConfigFS `mtp.gs0` USB setup. Its `recovery/root/vendor` (gatekeeper/keymaster
services, mcRegistry, novatek firmware, manifest) and `prebuilt/Image.gz-dtb`
are vendored here. Its own prebuilt kernel (`9738426` bytes, custom
`Image.gz-dtb`) was later replaced in this tree by the kernel extracted
from the working TWRP 3.7.0_9-1 build (see below). Its `twrp.fstab` is the
minimal working set (no odm/modem backups); this tree keeps the superset
with backup flags. It carries no `device.mk` and no MTP packages.

`trustonic.rc` here loads a different applet set than the working build: it
ships and starts 8 `.drbin` drivers (020f, 030b, 030d, 0507, 0512, 0715, 0717,
0907) plus their 22 `.tlbin`/`.tabin` payloads, and drops the fingerprint
applets (020b, 070b, 0707, `5020170115e016302017012521300000`,
`40188311faf343488db888ad39496f9a`) that the reference build loaded. Self-consistent
— every shipped `.drbin` is passed to `mcDriverDaemon` — and gatekeeper/keymaster
applets are present.

## ROM dump verification (tmp/cph1909-rom-dump)

A full CPH1909 ROM dump (firmware `CPH1909EX_11.A.46_0460_202103191930`,
build `full_oppo6765_18511-user 8.1.0 O11019 1616154336`, security patch
2021-04-05, kernel 4.9.77, ColorOS V5.2.1) was used as ground truth:

- Boot image header (v0, pagesize 2048, base `0x40078000`, offsets
  kernel `0x8000` / ramdisk `0x14f88000` / tags `0x13f88000`, cmdline
  `bootopt=64S3,32N2,64N2 buildvariant=user`) matches every
  `BOARD_*` value in `BoardConfig.mk` exactly. Re-checkable: the header
  stores absolute load addresses, and `kernel_addr 0x40080000`,
  `ramdisk_addr 0x55000000`, `tags_addr 0x54000000` are precisely the base
  plus the three offsets above.
- `vendor/etc/fstab.mt6765` confirms `/data` with
  `forceencrypt=/dev/block/.../metadata` — same flag carried in
  `twrp.fstab`.
- Blob cross-check vs dump `vendor/` and `system/`: the 8 vendored
  `system/lib64` runtime libs, `sbin/hwservicemanager` (dump
  `system/bin/hwservicemanager`) and `vendor/bin/mcDriverDaemon` are
  **byte-identical** to the A.46 dump (the CPH1920 MTP-fix reference blobs
  are exactly this device's ROM).
- The 64-bit `vendor/lib64` set (`libion`, `libgatekeeper`, `libkeymaster_*`,
  `libsoftkeymasterdevice`) and `vendor/lib64/hw/android.hardware.gatekeeper@1.0-impl.so`
  are **not** dump-identical — the dump only carries 32-bit copies of those
  names, under `system/lib/`. Their provenance is the working TWRP ramdisk,
  which they match byte-for-byte; that is the set to trust.
- Gatekeeper/keymaster service binaries, novatek touch firmware and
  `vendor/manifest.xml` also differ from the A.46 dump but are byte-identical
  to the working TWRP ramdisk — kept as-is (working set). In total all 40
  `vendor/*` files shared with the working ramdisk match byte-for-byte; the
  14 extras here are the added touch firmware plus the vendor-side crypto
  libs. `sbin/hwservicemanager` is the one file that differs from the working
  ramdisk (it is the dump's Oreo build, not the platform's own).

### Keymaster chain completeness (added after the blob cross-check)

The blob set had a real hole, found by tracing what the services actually load.
The HIDL service binaries are only trampolines — the ROM's
`android.hardware.keymaster@3.0-service` (11024 B) and the one this tree
carries (66064 B) have identical `NEEDED` lists and no `dlopen` strings. The
work happens in libraries that `hwservicemanager` loads via the vendored
`vendor/manifest.xml`, which declares `android.hardware.keymaster` 3.0. The
dump's manifest has no `<library>` tags, so passthrough falls back to the AOSP
convention of `<name>@<version>-impl.so` — and that file was missing:

| link | file | status |
|---|---|---|
| gatekeeper impl | `vendor/lib64/hw/android.hardware.gatekeeper@1.0-impl.so` | already present |
| ↳ Trustonic gatekeeper | `vendor/lib64/hw/gatekeeper.mt6765.so` | already present, byte-identical to the dump's `libMcGatekeeper.so` |
| keymaster impl | `vendor/lib64/hw/android.hardware.keymaster@3.0-impl.so` | **added** (40176 B, dump-identical) |
| ↳ Trustonic TEE keymaster | `vendor/lib64/hw/libMcTeeKeymaster.so` | **added** (89256 B, dump-identical) |
| MTK kmsetkey HAL | `vendor/lib64/hw/kmsetkey.trustonic.so` | **added** (15232 B, dump-identical) |
| MTK kmsetkey CA helper | `vendor/bin/kmsetkey_ca.trustonic` | **added** (15344 B, dump-identical) |

Without the keymaster impl there is no `IKeymasterDevice/default` at all, which
is a plausible mechanical cause for the long-standing "decryption doesn't work"
report for this device. Adding it turns that into "a software keymaster
service", which may still be insufficient: this tree's
`libsoftkeymasterdevice.so` contains no reference to kmsetkey or Trustonic, so
the HAL in that last row has no link to it. The real consumer of
`kmsetkey.trustonic.so` is the dump's `system/lib64/libkmsetkey.so` shim (it
reads `ro.hardware.kmsetkey=trustonic` from `vendor/build.prop`), which this
tree does not carry — deliberately, since nothing in the recovery crypto path
links it. Whether the stock ROM's FDE salt is TEE-bound is untested; if decrypt
still fails after a build, that shim is the next thing to pull.

The last three rows explain the device difference from the MT6761 sibling
trees that use a self-contained
`android.hardware.keymaster@3.0-service.trustonic` binary: CPH1909 has no such
binary, its only `.trustonic` files being kmsetkey and the SOTER service.
- Dump boot kernel (`9979567` bytes, gzip Image + 92534-byte DTB) is the
  A.46 stock — and exactly what this tree now uses as `prebuilt/kernel`
  (extracted from the working TWRP 3.7.0_9-1 recovery; byte-identical,
  config identical to stock recovery). Note that in the dump `boot.img` the
  kernel payload sits at file offset `0x800`: mkbootimg packs sections
  sequentially, so `BOARD_KERNEL_OFFSET` and friends are load addresses in
  the header, not in-file offsets.
- Dump `recovery.img` is an MTK `IMGDIF2` recovery-from-boot patch, not a
  flashable image; the stock ramdisk reference remains
  `tmp/oppo_a5s_stock_recovery_extracted.zip`.
- Touch firmware: the working TWRP ramdisk only ships the 4 novatek blobs.
  From the dump's `vendor/firmware/` the other panel-vendor firmwares were
  added for full A5s TP coverage: Himax (`Himax_firmware.bin` +
  `Himax_firmware_sort.bin`, HX83112), ILITEK (`ILITEK_FW_{HLT,INX,LEAD_TF,TXD,TXD_TF}.bin`,
  ILI9881 variants per panel source) and Goodix (`gt1151_default_firmware2.img`,
  GT1151). Kernel drivers request these by the same names from
  `/vendor/firmware` in the ramdisk.

## Built image verification (`tmp/recovery (2).img`)

A first build of this tree on the `twrp-8.1` manifest (SHA-256
`6ac58585d6124f13122286e5182e7146c3e03dbc298699aa23c4df196baae037`,
29,775,872 bytes) was checked against the tree:

- Header matches `BoardConfig.mk` exactly: `kernel_addr 0x40080000`,
  `ramdisk_addr 0x55000000`, `tags_addr 0x54000000`, page 2048,
  `os_version` 8.1, cmdline `bootopt=64S3,32N2,64N2 buildvariant=eng`
  (one `buildvariant`, as intended).
- The kernel payload is byte-identical to `prebuilt/kernel`
  (`76b59114fca90ce744c356c4a373714ea9f07299490d08b3ab52a92ba28bb6fc`).
- All 68 `PRODUCT_COPY_FILES` land in the ramdisk byte-identical, none
  missing — including the 9 `system/lib64` libs, `sbin/hwservicemanager`
  (the ROM-dump Oreo build, so ours wins over the platform's) and the 54
  `vendor/` blobs.
- SDK level is 27, read off TWRP's own version-gated modules:
  `sbin/libtwrpmtp-legacy.so` present and `libtwrpmtp-ffs.so` absent
  (`< 28` vs `>= 28`), `system/etc/event-log-tags` present (`< 28`),
  `sbin/sload.f2fs` absent (`>= 28`), `sbin/ld.config.txt` present
  (`>= 26`). FDE is built (`libcryptfsfde`, `libopenaes`), FBE comes
  along automatically (`libe4crypt`).
- `sbin/ld.config.txt` is byte-identical to the working build's, so the
  loader search order is unchanged: `/sbin` resolves before
  `/system/lib64` and `/vendor/lib64`. Every colliding library differs
  between those locations, so the vendored `system/lib64` copies are
  additive rather than load-bearing — `libMcClient.so` exists only in
  `vendor/lib64` and is what `gatekeeper.mt6765.so` actually needs.
- `/default.prop` is the standard 12-byte symlink to `prop.default`, and
  `prop.default` is really there (3926 bytes of properties here, 3268 in the
  working build, 3668 in the CPH1920 reference) — it only looks dangling if
  you stop at the symlink. `init.rc` does import
  `/init.recovery.vold_decrypt.rc`, which is absent: init warns and
  continues, and the in-tree FDE path does not need it. Both behave
  identically in the working build.
- That image predates the `mtp.gs0` fix and still advertises `ffs.mtp`,
  so its MTP is dead — see the MTP section above.

## Kernel source (https://github.com/yeojhenrie/A5S-8.1-kernel-source)

Cloned to /tmp/a5s_kernel (1.1G) and verified against this tree:

- `arch/arm64/configs/oppo6765_18511_defconfig` — the exact
  `TARGET_KERNEL_CONFIG` in `BoardConfig.mk` — exists, as does
  `arch/arm64/boot/dts/mediatek/oppo6765_18511.dts`.
- The defconfig produces `Image.gz-dtb` the same way stock does:
  `CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE=y` with
  `CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES="mediatek/mt6765"` — a gzip
  Image followed by a single FDT trailer. Measured on the prebuilt kernel
  (identical to the A.46 dump kernel): a **92534-byte**
  appended `mt6765` base DTB. The board overlay `oppo6765_18511` is *not*
  built into the kernel image (`CONFIG_BUILD_ARM64_DTB_OVERLAY_IMAGE` is
  off; only its `_NAMES` var is set) — LK merges it at boot from the
  `odmdtbo` partition, which `twrp.fstab` exposes as the `/odmdtbo`
  backup/flash target.
- Version: source Makefile is 4.9.80; the device kernel identifies as
  `Linux version 4.9.77+ ... (Linaro GCC 6.3-2017.02)` built 2021-03-19
  (prebuilt == dump A.46 image) — same tree, minor version bump, same
  toolchain.
- Defconfig touch drivers confirm the vendored firmware set:
  `CONFIG_TOUCHSCREEN_ILI9881H=y`, `CONFIG_TOUCHSCREEN_NT36xxx_HOSTDL_SPI=y`
  (novatek), `CONFIG_TOUCHSCREEN_HIMAX_IC_HX83112=y`, FT8006P. Goodix
  GT1151 is left unconfigured (`# CONFIG_TOUCHSCREEN_MTK_GT1151 is not set`)
  though `CONFIG_GT1151_FIRMWARE="firmware2"` explains the
  `gt1151_default_firmware2.img` name — kept as harmless coverage.
- Build stays prebuilt (`TARGET_FORCE_PREBUILT_KERNEL := true`, proven
  TWRP 3.7.0_9-1 Image.gz-dtb); the source settings above document what a
  from-source build would use. The kernel is reused as-is across platform
  branches — only the ramdisk contents change with the manifest.

## GitHub Actions Workflows

- **`.github/workflows/ci.yml` (Device Tree CI)**: Runs automated integrity and lint checks on every push and PR:
  - Validates that all files listed in `device.mk` `PRODUCT_COPY_FILES` exist on disk.
  - Verifies presence and valid size of `prebuilt/kernel`.
  - Checks critical partition mount paths in `twrp.fstab`.
  - Verifies ELF dynamic dependencies for all vendored binaries and libraries.
  - Checks `PLATFORM_VERSION` in `BoardConfig.mk` against the manifest branch
    the build workflow defaults to.
- **`.github/workflows/recovery-build.yml` (Build TWRP Recovery, legacy)**: end-to-end recovery builder, `workflow_dispatch` only (owner-triggered; there is no tag trigger):
  - Asserts `MANIFEST_BRANCH` matches `PLATFORM_VERSION` before doing anything,
    so the branch and the platform cannot drift apart.
  - Syncs minimal TWRP manifest, default
    `minimal-manifest-twrp/platform_manifest_twrp_omni` at **`twrp-8.1`**,
    exactly as upstream publishes it.
  - Injects this device tree into `device/oppo/CPH1909`.
  - Compiles `recoveryimage` using `lunch omni_CPH1909-eng`.
  - Uploads `recovery.img` as a GitHub Release (tag = run id).

## Where the ramdisk libraries come from

TWRP's recovery tree installs its own modules into `root/sbin`
(`LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/sbin`, identical in its
android-8.1 and android-9.0 `Android.mk`), which matches the proven build:
that ramdisk holds ~90 libs in `/sbin` and has no `/system/lib64` at all. The
nine `root/system/lib64` + `root/sbin` copies in `device.mk` are therefore
additive rather than a replacement of platform output. They give the
keymaster/gatekeeper/hwservicemanager stack an explicit Oreo-vintage runtime —
all 8 libs verified byte-identical to the A.46 ROM dump — instead of leaving
it to whatever the platform emits for the SDK. The vendor services run with
`LD_LIBRARY_PATH=/vendor/lib64:/vendor/lib:/sbin:/system/lib64:/system/lib`
from `init.recovery.mt6765.rc`, so where `/sbin` can satisfy a dependency it
wins over the copy in `/system/lib64`.


