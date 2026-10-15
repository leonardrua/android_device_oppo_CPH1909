# OPPO A5s (CPH1909) recovery device tree

Minimal standalone TWRP tree. Builds `omni_CPH1909` recovery only
(`lunch omni_CPH1909-eng && mka recoveryimage`).

## Layout

- `omni_CPH1909.mk` — recovery-only product (core_64_bit + full_base_telephony
  + `vendor/omni/config/common.mk`, same inherit order as the proven CPH1920
  reference at https://github.com/SQR11211/android_device_OPPO_CPH1920).
- `BoardConfig.mk` — MT6765 board config, kernel offsets, `TARGET_RECOVERY_FSTAB`
  pointing at `recovery/root/etc/twrp.fstab`. No system/vendor/odm image
  definitions; `ALLOW_MISSING_DEPENDENCIES := true` so it builds without a
  populated `vendor/` tree.
- `device.mk` — copies recovery ramdisk init scripts plus `recovery/root/vendor`
  blobs (gatekeeper/keymaster services, mcRegistry, touch firmware, manifest).
- `prebuilt/kernel` — prebuilt `Image.gz-dtb` (9.3M) from the J0shua CPH1909
  reference, enabled via `TARGET_FORCE_PREBUILT_KERNEL`.
- `recovery/root/etc/twrp.fstab` — TWRP mount table aligned with the stock
  recovery fstab from recovery.img (SHA-256
  `d95131864444640c91eac2352e79568928f822ef5b0706d7fc283c16934f462a`,
  header v0, pagesize 2048, OS 8.1.0 patch 2020-10-05, project 18511).
  Includes stock raw partitions as image-backup targets; keeps `/odm` as
  mountable ext4 (stock ro) plus `/odm_image` raw target.

Stock `/data` uses `forceencrypt` with the metadata partition (FDE), so TWRP
enables `TW_INCLUDE_CRYPTO` and leaves FBE-only options disabled. The working
TWRP build for this exact device (`tmp/oppo_a5s_twrp_recovery_extracted.zip`,
OmniROM 16.1.0 `eng.runner.20241027`, image SHA-256
`55d79d7065fa5681652d078b1c64d47bd573f4779ea49eb56aeda1c10ca83ca8`)
ships both vendor services — `vendor/bin/hw/android.hardware.gatekeeper@1.0-service`
and `keymaster@3.0-service` (66k each) with `vendor/lib64/hw/*-impl.so` +
`gatekeeper.mt6765.so` — so `init.recovery.mt6765.rc` starts both, matching
that build exactly.

The recovery ramdisk uses `init.recovery.mt6765.rc` for Trustonic, Keymaster,
Gatekeeper, keystore services, plus the stock MT6765 preloader aliases.
`init.recovery.usb.rc` sets up the ConfigFS gadget `g1` on `on init`
with FunctionFS MTP (`ffs.mtp` + `/dev/usb-ffs/mtp` mount), `musb-hdrc`
UDC, stock CPH1909 recovery USB ID `18d1:d001`, and `mass_storage.0`
function matching `BoardConfig.mk`. Includes robust triggers for `adb`,
`sideload`, `mtp`, and `mtp,adb`. The TWRP default USB init is disabled
to avoid competing gadget setup.
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
same ConfigFS `mtp.gs0` USB setup, FBE crypto flags
(`TW_INCLUDE_CRYPTO_FBE + TW_INCLUDE_FBE_METADATA_DECRYPT`, unlike this
tree's FDE-only setting). Its `recovery/root/vendor` (gatekeeper/keymaster
services, mcRegistry, novatek firmware, manifest) and `prebuilt/Image.gz-dtb`
are vendored here. Its prebuilt kernel differs from stock (`9738426` vs
`9977596` bytes) — custom-built `Image.gz-dtb`, boots with the 27M Image +
92k DTB layout. Its `twrp.fstab` is the minimal working set (no odm/modem
backups); this tree keeps the superset with backup flags.

## ROM dump verification (tmp/cph1909-rom-dump)

A full CPH1909 ROM dump (firmware `CPH1909EX_11.A.46_0460_202103191930`,
build `full_oppo6765_18511-user 8.1.0 O11019 1616154336`, security patch
2021-04-05, kernel 4.9.77, ColorOS V5.2.1) was used as ground truth:

- Boot image header (v0, pagesize 2048, base `0x40078000`, offsets
  kernel `0x8000` / ramdisk `0x14f88000` / tags `0x13f88000`, cmdline
  `bootopt=64S3,32N2,64N2 buildvariant=user`) matches every
  `BOARD_*` value in `BoardConfig.mk` exactly.
- `vendor/etc/fstab.mt6765` confirms `/data` with
  `forceencrypt=/dev/block/.../metadata` — same flag carried in
  `twrp.fstab`.
- Blob cross-check vs dump `vendor/` and `system/`: all 8 vendored
  `system/lib64` runtime libs, `hwservicemanager`, `mcDriverDaemon`,
  `libion/libgatekeeper/libkeymaster_*/libsoftkeymasterdevice` and
  `android.hardware.gatekeeper@1.0-impl.so` are **byte-identical** (the
  CPH1920 MTP-fix reference blobs are exactly this device's ROM).
- Gatekeeper/keymaster service binaries, novatek touch firmware and
  `vendor/manifest.xml` differ from the A.46 dump but are byte-identical
  to the working TWRP ramdisk — kept as-is (working set).
- Dump boot kernel (`9979567` bytes, gzip Image + 92534-byte DTB) is the
  newer A.46 stock; this tree keeps the J0shua prebuilt kernel that the
  working TWRP boots with.
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

## Kernel source (https://github.com/yeojhenrie/A5S-8.1-kernel-source)

Cloned to /tmp/a5s_kernel (1.1G) and verified against this tree:

- `arch/arm64/configs/oppo6765_18511_defconfig` — the exact
  `TARGET_KERNEL_CONFIG` in `BoardConfig.mk` — exists, as does
  `arch/arm64/boot/dts/mediatek/oppo6765_18511.dts`.
- The defconfig produces `Image.gz-dtb` the same way stock does:
  `CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE=y` with
  `CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES="mediatek/mt6765"` — a gzip
  Image followed by a single FDT trailer. Measured: both the J0shua
  prebuilt and the A.46 dump kernel carry an identical-size **92534-byte**
  appended `mt6765` base DTB. The board overlay `oppo6765_18511` is *not*
  built into the kernel image (`CONFIG_BUILD_ARM64_DTB_OVERLAY_IMAGE` is
  off; only its `_NAMES` var is set) — LK merges it at boot from the
  `odmdtbo` partition, which `twrp.fstab` exposes as the `/odmdtbo`
  backup/flash target.
- Version: source Makefile is 4.9.80; both device kernels identify as
  `Linux version 4.9.77+ ... (Linaro GCC 6.3-2017.02)` (J0shua prebuilt
  built 2019-03-16, dump A.46 built 2021-03-19) — same tree, minor version
  bump, same toolchain.
- Defconfig touch drivers confirm the vendored firmware set:
  `CONFIG_TOUCHSCREEN_ILI9881H=y`, `CONFIG_TOUCHSCREEN_NT36xxx_HOSTDL_SPI=y`
  (novatek), `CONFIG_TOUCHSCREEN_HIMAX_IC_HX83112=y`, FT8006P. Goodix
  GT1151 is left unconfigured (`# CONFIG_TOUCHSCREEN_MTK_GT1151 is not set`)
  though `CONFIG_GT1151_FIRMWARE="firmware2"` explains the
  `gt1151_default_firmware2.img` name — kept as harmless coverage.
- Build stays prebuilt (`TARGET_FORCE_PREBUILT_KERNEL := true`, proven
  J0shua Image.gz-dtb); the source settings above document what a
  from-source build would use.

## GitHub Actions Workflows

- **`.github/workflows/ci.yml` (Device Tree CI)**: Runs automated integrity and lint checks on every push and PR:
  - Validates that all files listed in `device.mk` `PRODUCT_COPY_FILES` exist on disk.
  - Verifies presence and valid size of `prebuilt/kernel`.
  - Checks critical partition mount paths in `twrp.fstab`.
  - Verifies ELF dynamic dependencies for all vendored binaries and libraries.
- **`.github/workflows/recovery-build.yml` (Build TWRP Recovery)**: Automated end-to-end recovery builder via `workflow_dispatch` or release tags (`v*`):
  - Syncs minimal TWRP manifest (`twrp-9.0` or `twrp-8.1`).
  - Injects this device tree into `device/oppo/CPH1909`.
  - Compiles `recoveryimage` using `lunch omni_CPH1909-{eng|userdebug|user}`.
  - Generates checksums (`.sha256`, `.md5`) and uploads `recovery.img` as a workflow artifact or GitHub Release.


