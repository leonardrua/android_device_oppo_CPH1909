# OPPO A5s (CPH1909) TWRP Recovery Device Tree

Device tree for building a TWRP recovery image for the OPPO A5s (CPH1909),
MediaTek MT6765 (project 18511), running Android 8.1 (`PLATFORM_SDK_VERSION 27`).

> **Status: experimental.** The build pipeline is in place, but several parts of
> this tree (decryption, keymaster, and MTP) are not yet confirmed on
> hardware. See [Experimental features](#experimental-features).

## Contents

- [Building](#building)
- [Tree layout](#tree-layout)
- [Key configuration decisions](#key-configuration-decisions)
- [Experimental features](#experimental-features)
- [CI and workflows](#ci-and-workflows)
- [Known gaps](#known-gaps)
- [References](#references)

## Building

### Requirements

- Ubuntu 22.04 (or the runner image used by the workflows)
- Roughly 250 GB of free disk space for a full sync, or use the `--depth=1` sync below
- OpenJDK 8, as used by the android-8.1 build

### Local build

```bash
repo init --depth=1 \
  -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni \
  -b twrp-8.1
repo sync -j$(nproc)

# Place this tree at the path the product expects
git clone https://github.com/leonardrua/android_device_oppo_CPH1909 \
  -b recovery device/oppo/CPH1909

source build/envsetup.sh
lunch omni_CPH1909-eng
mka recoveryimage
```

The output is `out/target/product/CPH1909/recovery.img`.

### GitHub Actions

The `recovery-build.yml` workflow (manual trigger only) runs the same steps on
a hosted runner and uploads the result as a GitHub Release. Its default inputs
match the values above:

| Input | Default |
|---|---|
| `MANIFEST_URL` | `https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni` |
| `MANIFEST_BRANCH` | `twrp-8.1` |
| `DEVICE_TREE_BRANCH` | `recovery` |
| `DEVICE_PATH` | `device/oppo/CPH1909` |
| `DEVICE_NAME` | `CPH1909` |
| `MAKEFILE_NAME` | `omni_CPH1909` |
| `BUILD_TARGET` | `recovery` |

Set `MANIFEST_BRANCH` and `MAKEFILE_NAME` only to values that match this tree.
The guard step described in [CI and workflows](#ci-and-workflows) rejects a
mismatch before the build starts.

## Tree layout

| Path | Purpose |
|---|---|
| `AndroidProducts.mk`, `vendorsetup.sh` | Registers the `omni_CPH1909-{user,userdebug,eng}` lunch combos. |
| `omni_CPH1909.mk` | Recovery-only product. Inherits `core_64_bit`, `full_base_telephony`, `vendor/omni/config/common.mk`, then `device.mk`. |
| `BoardConfig.mk` | MT6765 board configuration: architecture, kernel offsets and cmdline, partition sizes, TWRP options. |
| `device.mk` | Copies recovery init scripts, vendor blobs, firmware, and runtime libraries into the ramdisk through `PRODUCT_COPY_FILES`. |
| `prebuilt/kernel` | Prebuilt `Image.gz-dtb`, enabled by `TARGET_FORCE_PREBUILT_KERNEL`. |
| `recovery/root/etc/twrp.fstab` | TWRP mount table (`TARGET_RECOVERY_FSTAB`). |
| `recovery/root/etc/mke2fs.conf` | Stock AOSP `mke2fs` configuration, used when TWRP formats ext4 on the device. |
| `recovery/root/init.recovery.mt6765.rc` | Starts Trustonic, keymaster, gatekeeper, and keystore services in recovery, and tears the TEE stack down again once `/data` is decrypted. |
| `recovery/root/init.recovery.usb.rc` | ConfigFS USB gadget `g1` with `mtp.gs0` MTP, ADB, sideload, and mass storage. |
| `recovery/root/trustonic.rc` | Starts the `mcDriverDaemon` with the eight `.drbin` drivers shipped on this device. |
| `recovery/root/ueventd.reserve.rc` | Stock `opporeserve1` rules. Not imported by ueventd, see [Known gaps](#known-gaps). |
| `recovery/root/vendor/` | Gatekeeper and keymaster services, Trustonic libraries, `mcRegistry` trustlets, `manifest.xml`, and touch firmware. |
| `recovery/root/system/lib64/`, `recovery/root/sbin/` | Runtime libraries for the binder, HIDL, and crypto stack, and `hwservicemanager`. |

## Key configuration decisions

### Platform and manifest pairing

`PLATFORM_VERSION := 8.1.0` in `BoardConfig.mk` must match the manifest branch.
The branch sets `PLATFORM_SDK_VERSION` (27), and the SDK level decides several
things: crypto code paths, MTP library choice, and image tooling. The
`PLATFORM_VERSION` value only sets `ro.build.version.release`. CI checks that the
two agree for `twrp-8.1`, `twrp-9.0`, and `twrp-10.0`.

The `twrp-8.1` manifest uses the platform sources as published. The one
exception is `bootable/recovery`, which the `twrp-extras.xml` manifest overrides
to the TeamWin `android-9.0` revision (TWRP 3.7). If a future sync breaks because
of this platform mismatch, pin `bootable/recovery` to an `android-8.1` revision
with a local manifest (`repo init -m <file>`). Do not change this tree for that.

### Storage and fstab

`BOARD_USES_VENDORIMAGE := true` and `TARGET_COPY_OUT_VENDOR := vendor` keep
`root/vendor` as a real directory in the ramdisk. Without them, the Android 8.1
rootdir creates `root/vendor` as a symlink to `/system/vendor`, and the copy rules
in `device.mk` fail on the build machine.

`twrp.fstab` maps the MT6765 partitions by their `by-name` nodes, including the
renamed ones: `misc` → `para`, `persistent` → `frp`, `bootloader` → `lk`,
`bootloader2` → `lk2`, and `opporeserve` → `opporeserve2`. `metadata` is not
mounted. It is reached through `forceencrypt=` on `/data`.

Each of `system`, `vendor`, and `odm` appears twice: once as a mountable `ext4`
entry, and once as a raw `emmc` `*_image` entry for full-partition backup or
restore. The raw entries use `flags=backup=0;flashimg=1` so that "Select all"
does not archive each partition twice.

### Decryption

Stock `/data` is `forceencrypt` with the `metadata` partition, so the tree sets
`TW_INCLUDE_CRYPTO := true`. At `PLATFORM_SDK_VERSION 27`, TWRP builds the FDE
path. That is one shared library, `sbin/libcryptfsfde.so`; there is no separate
`libscrypt.so`, because `crypto/fde/Android.mk` links `libscrypttwrp_static`
into it. The FBE metadata-decrypt flag is not set, because TWRP only enables it
for SDK 28 and above. Whether the FDE path decrypts `/data` on this device is
still unconfirmed.

### MTP

TWRP picks its MTP implementation by SDK level in `bootable/recovery/Android.mk`.
SDK 28 and above builds FunctionFS (`libtwrpmtp-ffs`). Lower levels build the
legacy implementation (`libtwrpmtp-legacy`), which talks to `/dev/mtp_usb`.
This tree is at SDK 27, so `init.recovery.usb.rc` uses the legacy `mtp.gs0`
function. A `ffs.mtp` gadget would not work with this library. The
`/dev/mtp_usb` node comes from the platform `ueventd.rc`.

The gadget also advertises the Microsoft OS descriptor, so Windows recognises
the MTP interface without a driver. That needs three things in
`init.recovery.usb.rc`: the `os_desc` attributes (`b_vendor_code`, `qw_sign`),
a symlink from `os_desc/b.1` to `configs/b.1`, and `os_desc/use 1`. The
symlink has to be created after `configs/b.1` exists, because the kernel
only accepts an `os_desc` link whose target is already a registered
configuration. `os_desc/use` is latched into `cdev->use_os_string` when the
controller is bound, so it is set before the first bind and re-armed before
every later one.

### Kernel

The kernel is a prebuilt `Image.gz-dtb` (9,979,567 bytes, SHA-256
`76b59114fca90ce744c356c4a373714ea9f07299490d08b3ab52a92ba28bb6fc`). It is a
gzip-compressed kernel followed by the `mediatek/mt6765` base DTB. The board
overlay (`oppo6765_18511`) is not built into the image. The bootloader merges it
at boot from the `odmdtbo` partition, which is exposed in `twrp.fstab`.

`TARGET_KERNEL_SOURCE` and `TARGET_KERNEL_CONFIG` point to the source tree and
`oppo6765_18511_defconfig` for reference. The build does not compile the kernel
from source, because `TARGET_FORCE_PREBUILT_KERNEL` is set.

### Boot header

`BoardConfig.mk` sets the header values to match the stock image: page size
2048, kernel base `0x40078000`, kernel offset `0x8000`, ramdisk offset
`0x14f88000`, and tags offset `0x13f88000`. The kernel command line is
`bootopt=64S3,32N2,64N2`, without `buildvariant`. Stock carries
`buildvariant=user`, but it is deliberately left out here: the build system
appends `buildvariant=$(TARGET_BUILD_VARIANT)` at `mkbootimg` time, and keeping
the stock value as well produced a duplicated pair on the image
(`buildvariant=user buildvariant=eng`). A recovery built from this tree
therefore carries `buildvariant=eng`. Check the header of a freshly built image
before flashing.

## Experimental features

These are included in the tree but are not yet verified on hardware. Each one can
be reverted as described below.

### vold-based decryption (`TW_CRYPTO_USE_SYSTEM_VOLD`) — removed

This was tried and taken back out. It set
`TW_CRYPTO_USE_SYSTEM_VOLD := keymaster-3-0 hwservicemanager mobicore` and added
`recovery/root/fstab.mt6765` plus `init.recovery.vold_decrypt.mobicore.rc`, so
that TWRP would mount `/system` and let the OEM Oreo vold decrypt.

It could not have worked here. TWRP's `vold_decrypt` starts `/system/bin/vold`
and this tree does not ship that binary, so the path had nothing to exec. The
extra services did line up — `ven_keymaster-3-0` runs
`/vendor/bin/hw/android.hardware.keymaster@3.0-service`, which this tree ships —
but vold itself was the blocker.

No MT6765 device tree sets this knob either: the eleven trees declaring
`TARGET_BOARD_PLATFORM := mt6765` were checked, and none does.

Decryption therefore goes through TWRP's own FDE path, as below.

### Keymaster HAL implementation

The following libraries were added so that the keymaster HAL can be loaded from
the manifest:

- `vendor/lib64/hw/android.hardware.keymaster@3.0-impl.so`
- `vendor/lib64/hw/libMcTeeKeymaster.so`
- `vendor/lib64/hw/kmsetkey.trustonic.so`
- `vendor/bin/kmsetkey_ca.trustonic`

Without the implementation, the keymaster HAL service has no default
implementation to load, so `e367bd6` is what lets `hwservicemanager` register
`IKeymasterDevice/default` at all. The known-good TWRP build for this device does
**not** ship `android.hardware.keymaster@3.0-impl.so`, which is why it never
registers the HAL and spends boot time in a decrypt timeout before falling back to
the password prompt.

What registers is a **software** keymaster, checked against a built image rather
than assumed: `android.hardware.keymaster@3.0-impl.so` has
`libsoftkeymasterdevice.so` in its `DT_NEEDED` list, and that library imports no
`dlopen` or `dlsym` and contains no reference to kmsetkey or Trustonic. The
vendored `manifest.xml` has no `<library>` tags, so passthrough resolves to the
AOSP `<name>@<version>-impl.so` convention and nothing else is loaded.

### MTK attestation and cryptoeng HALs

The manifest declares two more crypto HALs that this tree now carries. Both are
the TEE-facing half of the keymaster chain on this device, and both were missing,
so `hwservicemanager` logged a load failure for each on every boot:

| HAL | files added |
|---|---|
| `vendor.mediatek.hardware.keymaster_attestation` 1.1 | `vendor/lib64/hw/…@1.1-impl.so`, `vendor/lib64/…@1.0_vendor.so`, `vendor/lib64/…@1.1_vendor.so`, `vendor/bin/hw/…@1.1-service`, `system/lib64/…@1.0.so`, `system/lib64/…@1.1.so` |
| `vendor.oppo.hardware.cryptoeng` 1.0 | `vendor/lib64/…@1.0_vendor.so`, `vendor/bin/hw/…@1.0-service`, `system/lib64/…@1.0.so` |

All ten are byte-identical to the A.46 dump, 651 KiB in total, and their
dependency closure resolves entirely within the ramdisk.

`system/lib64/libkmsetkey.so` is the keybox verifier: it carries
`ree_check_attest_keybox` / `ree_import_attest_keybox` and has
`vendor.mediatek.hardware.keymaster_attestation@1.1.so` in its `DT_NEEDED` list,
so it talks to the attestation HAL over HIDL. An earlier revision of this file
called it unsupported, because across the whole ROM dump only `system/bin/meta_tst`
links it directly; that missed the HIDL link, which is the one that matters.

`init.recovery.mt6765.rc` starts both services, and `kmsetkey_ca.trustonic` is
now started as a oneshot. This tree has carried that binary since `e367bd6`
without ever running it; the sibling MT6765 tree runs its equivalent
(`bp_kmsetkey_ca -c`) as a `late_start` oneshot. It is a verification step, not
part of the decrypt path, and failure is harmless.

The HALs are re-started on `init.svc.hwservicemanager=running`. Starting them in
the same `on post-fs` block as hwservicemanager is a race: a HIDL service that
starts before hwservicemanager is listening loses its registration and exits. All
the HAL services are `oneshot`, so the second start is a no-op when the first
already worked.

How the attestation service reaches the TEE is still not fully established. The
impl carries `kmsetkey` and `Error to open kmsetkey device.` but imports no
`dlopen` and holds no absolute paths. What is established is the shape: it
registers through the manifest, and `kmsetkey.trustonic.so` — which this tree has
carried all along — links `libMcClient.so` and so is a real TEE client through
`mcDriverDaemon`. Whether this closes the decrypt gap is untested on hardware.

To revert, remove the files and their entries in `device.mk`, and drop the three
service blocks and the property trigger from `init.recovery.mt6765.rc`.

## CI and workflows

**`.github/workflows/ci.yml` (Device Tree CI)** runs on pushes, pull requests, and
manual dispatch. It checks that:

1. Every path listed in `device.mk` `PRODUCT_COPY_FILES` exists on disk.
2. `prebuilt/kernel` exists and is larger than 5 MB.
3. `twrp.fstab` contains the required mount points: `/system`, `/vendor`, `/data`,
   `/boot`, `/recovery`, `/external_sd`, and `/usb_otg`.
4. The `NEEDED` libraries of every vendored ELF file are either vendored or part
   of the TWRP platform set.
5. `PLATFORM_VERSION` in `BoardConfig.mk` matches the manifest branch
   (`twrp-8.1` → `8.1.0`, `twrp-9.0` → `9.0.0`, `twrp-10.0` → `10.0.0`).

**`.github/workflows/recovery-build.yml` (Recovery Build, legacy)** is a manual
workflow. It runs a guard step right after checkout that fails if
`MANIFEST_BRANCH` does not match `PLATFORM_VERSION`. The rest of the workflow
syncs the manifest, clones this tree into `device/oppo/CPH1909`, runs
`lunch <MAKEFILE_NAME>-eng` and `make <BUILD_TARGET>image`, and publishes the
resulting `.img` and any `vendor*.img` or `.zip` files as a GitHub Release.
It uses OpenJDK 8, which the android-8.1 build requires.

## Known gaps

- **`ueventd.reserve.rc` is not used.** Ueventd only loads `ueventd.rc` and
  `ueventd.$hardware.rc`, so the stock `opporeserve1` rules in this file have no
  effect. Add the rules to a file that ueventd loads if they are needed.
- **There is nothing to set for FBE.** TWRP 3.x has no `TW_INCLUDE_FBE`
  variable, and neither FBE flag can be turned off from a device tree:
  `TW_INCLUDE_CRYPTO_FBE` is force-enabled for SDK 24 and above, and the FBE
  metadata-decrypt flag is gated on SDK 28. At `PLATFORM_SDK_VERSION 27` this
  tree gets FDE decrypt plus FBE without metadata decrypt. `BoardConfig.mk`
  records this in comments; do not add settings for it.
- **Unverified on hardware.** Decryption, keymaster, MTP, and the boot header
  have not been checked on a device. Test each feature on a device before relying
  on it.
- **Touch firmware coverage.** Firmware for the Himax, ILITEK, Novatek, and Goodix
  panels is included. Only the panel in use on a specific unit will load.
- **The keymaster auth token is only half-wired.** `mcDriverDaemon` reads the
  auth token container from `$MC_AUTH_TOKEN_PATH/00000000.authtokcont`, so
  `trustonic.rc` exports `MC_AUTH_TOKEN_PATH=/vendor/persist` before starting
  the daemon and symlinks the container into `/data/misc/mcRegistry`, which is
  the daemon's first registry search path. The stock value is `/efs`, which
  does not exist on this device. Whether the keymaster TA actually stores and
  reuses the token has not been checked on hardware.

## References

- Base manifest: https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni
  (branch `twrp-8.1`)
- Reference device tree for the lunch and product structure:
  https://github.com/SQR11211/android_device_OPPO_CPH1920
- Kernel source used for the defconfig reference:
  https://github.com/yeojhenrie/A5S-8.1-kernel-source
- Community CPH1909 device tree: https://github.com/J0shua-code/Oppo-CPH1909-Device-Tree
