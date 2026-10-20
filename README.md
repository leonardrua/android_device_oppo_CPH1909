# OPPO A5s (CPH1909) TWRP Recovery Device Tree

Device tree for building a TWRP recovery image for the OPPO A5s (CPH1909),
MediaTek MT6765 (project 18511), running Android 8.1. Built against the
`twrp-9.0` manifest, so `PLATFORM_SDK_VERSION` is 28.

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
- OpenJDK 8, as used by the android-9.0 build

### Local build

```bash
repo init --depth=1 \
  -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni \
  -b twrp-9.0
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
| `MANIFEST_BRANCH` | `twrp-9.0` |
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

`PLATFORM_VERSION := 9.0.0` in `BoardConfig.mk` must match the manifest branch.
The branch sets `PLATFORM_SDK_VERSION` (28), and the SDK level decides several
things: crypto code paths, MTP library choice, and image tooling. The
`PLATFORM_VERSION` value only sets `ro.build.version.release`. CI checks that the
two agree for `twrp-8.1`, `twrp-9.0`, and `twrp-10.0`.

The `twrp-9.0` manifest pins the platform at `refs/tags/android-9.0.0_r47` and
`bootable/recovery` at the TeamWin `android-9.0` revision, so the platform and
the recovery tree are the same vintage — the mismatch the `twrp-8.1` manifest
had (an Android 8.1 platform against a TeamWin `android-9.0` recovery tree).
`bootable/recovery` is overridden by `twrp-extras.xml` in both manifests, and
`remove-minimal.xml` drops `platform/external/libmtp` and
`platform/external/mtpd` in both.

### Build variants

This tree is maintained as two branches that differ only in the platform they
are built against:

| Branch | Manifest | `PLATFORM_SDK_VERSION` | Notes |
|---|---|---|---|
| `recovery` (this branch) | `twrp-9.0` | 28 | platform and recovery tree are the same vintage |
| `recovery-twrp-8.1` | `twrp-8.1` | 27 | Android 8.1 platform against a TeamWin `android-9.0` recovery tree |

Everything else — the init scripts, the vendored blobs, the fstab, the kernel —
is identical on both. The differences that the SDK level causes are:

- **Crypto.** SDK 28 also sets `TW_INCLUDE_FBE_METADATA_DECRYPT`, which adds
  `crypto/ext4crypt`. It is only taken for a file-encrypted `/data`, and this
  device is FDE, so it stays unused.
- **MTP.** SDK 28 links `libtwrpmtp-ffs` instead of `libtwrpmtp-legacy`. It
  still works here: the ffs MTP server falls back to `MtpDevHandle` when
  `/dev/usb-ffs/mtp/ep0` is absent, and it is absent because this kernel has no
  `f_fs_mtp.c`. `MtpDevHandle` opens `/dev/mtp_usb`, which the `mtp.gs0` gadget
  function provides — so `init.recovery.usb.rc` keeps `mtp.gs0` on both branches.

Pick the branch, then the matching `MANIFEST_BRANCH`; the build workflow's
guard step rejects a mismatch.

### Storage and fstab

`BOARD_USES_VENDORIMAGE := true` and `TARGET_COPY_OUT_VENDOR := vendor` keep
`root/vendor` as a real directory in the ramdisk. Without them, the Android 9
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
`TW_INCLUDE_CRYPTO := true`. At `PLATFORM_SDK_VERSION 28`, TWRP builds the FDE
path. That is one shared library, `sbin/libcryptfsfde.so`; there is no separate
`libscrypt.so`, because `crypto/fde/Android.mk` links `libscrypttwrp_static`
into it. The FBE metadata-decrypt flag is now also set, because TWRP enables it
for SDK 28 and above; that adds `crypto/ext4crypt` to the build. It is only
taken for a file-encrypted `/data`, and this device is FDE, so it stays unused.
Whether the FDE path decrypts `/data` on this device is still unconfirmed.

### MTP

TWRP picks its MTP implementation by SDK level in `bootable/recovery/Android.mk`.
SDK 28 and above builds FunctionFS (`libtwrpmtp-ffs`). Lower levels build the
legacy implementation (`libtwrpmtp-legacy`), which talks to `/dev/mtp_usb`.
This tree is at SDK 28, so `libtwrpmtp-ffs` is linked — but it only speaks
FunctionFS-MTP when `/dev/usb-ffs/mtp/ep0` exists, which needs an `ffs.mtp`
gadget function. This tree does not create one, so the ffs MTP server falls
back to `MtpDevHandle`, which opens `/dev/mtp_usb`. `init.recovery.usb.rc`
keeps the `mtp.gs0` function, which is what provides that device. The
`/dev/mtp_usb` node comes from the platform `ueventd.rc`.

An `ffs.mtp` instance would be creatable — the configfs name is
`FUNC.INSTANCE`, `configfs`'s `function_make()` splits it at the first dot, so
FUNC is `ffs` (the f_fs driver, built in) and INSTANCE is `mtp`, and
`f_fs`'s `set_inst_name()` accepts any name. There is no `f_fs_mtp.c` to look
for because the MTP protocol over FunctionFS is implemented in userspace, by
TWRP's `MtpFfsHandle`. This tree keeps `mtp.gs0` anyway, for two reasons: it
is the transport the stock ROM's userspace MTP uses, and the MS OS
descriptor's "MTP" compatible ID can only be published through it — only
`f_mtp.c` creates a configfs `os_desc` group, via
`usb_os_desc_prepare_interf_dir()`, so a FunctionFS instance has nowhere to
put it.

The CPH1920 reference (SQR11211, tag `MTP-fix`) took the other route: it
replaced `mtp.gs0` with an `ffs.mtp` gadget function and a
`/dev/usb-ffs/mtp` mount, which needs `libtwrpmtp-ffs` and so an SDK 28+
platform. Its README describes that change backwards — it says the fix went
"from the old FunctionFS path (`ffs.mtp`, manual `/dev/usb-ffs/mtp` mount) to
ConfigFS-based MTP (`mtp.gs0`)", while commit `4f007b8` did the reverse:
`mtp.gs0` and the `os_desc` setup are what the tree had *before* it, and
`ffs.mtp` is what it has *after*.

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
It uses OpenJDK 8, which the android-9.0 build requires.

## Known gaps

- **`ueventd.reserve.rc` is not used.** Ueventd only loads `ueventd.rc` and
  `ueventd.$hardware.rc`, so the stock `opporeserve1` rules in this file have no
  effect. Add the rules to a file that ueventd loads if they are needed.
- **The fstab uses a flag TWRP does not know.** `twrp.fstab` marks `/data`
  with `flags=forceencrypt=.../metadata`, but TWRP's fstab flag table
  (`partition.cpp`) only knows `encryptable=` and `fileencryption=` —
  `forceencrypt=` is not in it, so it does not set `Crypto_Key_Location`
  and TWRP has to detect the FDE footer from blkid instead. The stock MTK
  fstab uses the same flag, so this is not a local mistake, but it is worth
  checking that TWRP does see `/data` as encrypted.
- **There is nothing to set for FBE.** TWRP 3.x has no `TW_INCLUDE_FBE`
  variable, and neither FBE flag can be turned off from a device tree:
  `TW_INCLUDE_CRYPTO_FBE` is force-enabled for SDK 24 and above, and the FBE
  metadata-decrypt flag is gated on SDK 28. At `PLATFORM_SDK_VERSION 28` this
  tree gets FDE decrypt plus FBE with metadata decrypt — the metadata path is
  only taken for a file-encrypted `/data`, and this device is FDE, so it stays
  unused. `BoardConfig.mk` records this in comments; do not add settings for it.
- **Unverified on hardware.** Decryption, keymaster, MTP, and the boot header
  have not been checked on a device. Test each feature on a device before relying
  on it.
- **The ramdisk carries Oreo-vintage runtime libraries.** `device.mk` copies
  `libbinder`, `libcrypto`, `libcutils`, `libhidlbase`, `libhidltransport`,
  `libhwbinder`, `libkeymaster_staging`, `libutils`, `libvndksupport` and
  `libkmsetkey` from the A.46 ROM into `root/system/lib64`, plus
  `root/sbin/hwservicemanager`, all verified byte-identical to the stock
  dump. They are there to give the vendored keymaster/gatekeeper stack a
  matching runtime rather than whatever the platform emits. Against an
  Android 9 platform the platform's own copies are a different vintage, so
  whether the copy or the platform module wins in `root/sbin` and `root/system`
  is worth checking on a built image.
- **Touch firmware coverage.** Firmware for the Himax, ILITEK, Novatek, and Goodix
  panels is included. Only the panel in use on a specific unit will load.
- **There is no keymaster auth token container on this device.**
  `mcDriverDaemon` reads `00000000.authtokcont` from `$MC_AUTH_TOKEN_PATH`,
  but the file does not exist — not in `/vendor/persist`, not in
  `/data/misc/mcRegistry`, not in `/vendor/nvcfg`, and not on the stock ROM
  either. Nothing in the tree can create it: it is written by the keymaster TA
  once it has issued an auth token. The export in `trustonic.rc` keeps the
  stock `/efs` value and is ordered before the daemon start (init hands its
  environment to the services it spawns), but the lookup is a no-op on this
  device and there is nothing to point at a different directory.
- **The TEE stack is not on TWRP's FDE decrypt path.** TWRP's FDE code
  (`crypto/fde/cryptfs.cpp`) asks for a *legacy* hardware module by class:
  `hw_get_module_by_class(KEYSTORE_HARDWARE_MODULE_ID, ...)`, which is
  `"keystore"`. In a recovery ramdisk the only module with that id is AOSP's
  software keymaster (`libsoftkeymaster.so`, which registers
  `struct keystore_module`), and TWRP relinks it in at SDK < 28. The vendor
  keymaster on this device is HIDL-only
  (`android.hardware.keymaster@3.0-service`, registered with
  hwservicemanager) and cannot be reached through that API at all. So
  `mobicore`, the vendor keymaster and the gatekeeper serve the fingerprint
  gatekeeper and FBE — neither of which is the FDE decrypt.
- **The daemon opens `/dev/mobicore` and `/dev/mobicore-user` by absolute
  path.** The kernel creates them in the `trustonic_tee` class with
  `class_create()` and no devnode callback, so devtmpfs applies its default
  of `0600 root:root`, and the stock MTK `ueventd.rc` has no rule for them.
  The `mobicore` service therefore runs as root, not as `system` — see the
  comment on the service.
- **TWRP does not run vold, so no `vold.decrypt=trigger_*` property is ever
  set.** `trustonic.rc` therefore keys its FDE block off `ro.crypto.state` and
  `ro.crypto.type`, which TWRP sets itself in `Decrypt_Device()`. The
  unencrypted block keys off `ro.crypto.state=unsupported`, which is the Oreo
  spelling, but TWRP never sets `ro.crypto.state` at all for an unencrypted
  `/data` — on this device `/data` is always forceencrypt, so that block is
  expected never to fire.

## References

- Base manifest: https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni
  (branch `twrp-9.0`)
- Reference device tree for the lunch and product structure:
  https://github.com/SQR11211/android_device_OPPO_CPH1920
- Kernel source used for the defconfig reference:
  https://github.com/yeojhenrie/A5S-8.1-kernel-source
- Community CPH1909 device tree: https://github.com/J0shua-code/Oppo-CPH1909-Device-Tree
