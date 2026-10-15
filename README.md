# OPPO A5s (CPH1909) recovery device tree

Minimal standalone TWRP tree. Builds `omni_CPH1909` recovery only
(`lunch omni_CPH1909-eng && mka recoveryimage`).

## Layout

- `omni_CPH1909.mk` — recovery-only product (inherits `vendor/omni/config/common.mk`).
- `BoardConfig.mk` — MT6765 board config, kernel offsets, `TARGET_RECOVERY_FSTAB`
  pointing at `recovery/root/etc/twrp.fstab`. No system/vendor/odm image
  definitions; `ALLOW_MISSING_DEPENDENCIES := true` so it builds without a
  populated `vendor/` tree.
- `device.mk` — copies recovery ramdisk init scripts; optionally inherits
  `vendor/oppo/CPH1909` blobs for decryption when present.
- `recovery/root/etc/twrp.fstab` — TWRP mount table aligned with the stock
  recovery fstab from recovery.img (SHA-256
  `d95131864444640c91eac2352e79568928f822ef5b0706d7fc283c16934f462a`,
  header v0, pagesize 2048, OS 8.1.0 patch 2020-10-05, project 18511).
  Includes stock raw partitions as image-backup targets; keeps `/odm` as
  mountable ext4 (stock ro) plus `/odm_image` raw target.

Stock `/data` uses `forceencrypt` with the metadata partition (FDE), so TWRP
enables `TW_INCLUDE_CRYPTO` and leaves FBE-only options disabled. The stock
recovery ramdisk ships only `/sbin/android.hardware.keymaster@3.0-service`
(no gatekeeper binary), and its FDE path restarts hwservicemanager +
keymaster only — `init.recovery.mt6765.rc` mirrors that and leaves a
commented gatekeeper stub.

The recovery ramdisk uses `init.recovery.mt6765.rc` for Trustonic, Keymaster,
Gatekeeper, keystore services, and the stock MT6765 preloader aliases. It
imports `init.recovery.usb.rc`, which configures the stock `musb-hdrc` UDC and
the TWRP ConfigFS gadget with FunctionFS ADB/MTP. ADB uses the stock recovery
USB ID `18d1:d001`; the MTP IDs are retained from the CPH1909 recovery
reference. `recovery/root/trustonic.rc` supplies the Trustonic daemon setup.
The TWRP default USB init is disabled to avoid competing gadget setup. USB
mass-storage LUNs are mapped to the ConfigFS gadget path in `BoardConfig.mk`.


