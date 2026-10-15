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
`init.recovery.usb.rc` applies the CPH1920 MTP fix verbatim
(SQR11211/android_device_OPPO_CPH1920, commit `4f007b8` tag `MTP-fix`,
"Fix MTP via ConfigFS gadget", cloned to /tmp/sqr_cph1920): ConfigFS gadget
`g1` on `on init` with FunctionFS MTP (`ffs.mtp` + `/dev/usb-ffs/mtp` mount),
`musb-hdrc` UDC, single `mtp,adb` trigger, stock CPH1909 recovery USB ID
`18d1:d001` (CPH1920 uses `22d9:2765`). The TWRP default USB init is disabled
to avoid competing gadget setup. USB mass-storage LUNs map to
`mass_storage.0` in `BoardConfig.mk` (same as CPH1920).
`ueventd.reserve.rc` carries the stock opporeserve1 rules.
`sbin/hwservicemanager`, `system/lib64` binder/crypto/hidl runtime, and
`vendor/lib64` gatekeeper/keymaster libs are vendored from the CPH1920
reference. `twrp.fstab` storage nodes match its reference fstab:
`mmcblk1p1/mmcblk1` for SD, `sda1/sda` for OTG.

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


