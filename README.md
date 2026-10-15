# OPPO A5s (CPH1909) recovery device tree 

## Recovery reference

The TWRP mount table at `recovery/root/etc/twrp.fstab` follows the stock
recovery partition map. It includes the stock raw partitions as image-backup
targets and omits ODM because that partition is empty in the supplied dump.
The Android/vendor fstab remains at `rootdir/etc/fstab.mt6765`. `BoardConfig.mk`
selects the TWRP-specific table for `twrp_*` or `omni_*` products and retains
the Android-format table for the AOSP recovery. Stock `/data` uses
`forceencrypt` with the metadata partition, so the TWRP configuration enables
crypto and leaves FBE-only options disabled.

TWRP-specific options in `BoardConfig.mk` are groundwork for a compatible
TWRP/Omni build; this repo currently defines only the `aosp_CPH1909` product,
so it is not yet a standalone TWRP build target. Encryption support also
depends on the recovery tree and matching vendor libraries.

The recovery ramdisk uses `init.recovery.mt6765.rc` for Trustonic, Keymaster,
Gatekeeper, keystore services, and the stock MT6765 preloader aliases. It
imports `init.recovery.usb.rc`, which configures the stock `musb-hdrc` UDC and
the TWRP ConfigFS gadget with FunctionFS ADB/MTP. ADB uses the stock recovery
USB ID `18d1:d001`; the MTP IDs are retained from the CPH1909 recovery
reference. `recovery/root/trustonic.rc` supplies the Trustonic daemon setup.
The TWRP default USB init is disabled to avoid competing gadget setup. USB
mass-storage LUNs are mapped to the ConfigFS gadget path in `BoardConfig.mk`.

