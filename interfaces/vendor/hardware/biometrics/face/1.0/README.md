# Reconstructed vendor face HAL interface (built from source)

These `.hal` files are a **reference reconstruction** of the stock OPPO
interface, reverse-engineered from the CPH1909 dump,
primarily `system/lib64/vendor.oppo.hardware.biometrics.face@1.0.so`
(the 32-bit `system/lib/...` twin agrees).

They **are built**: `Android.bp` in this directory declares the
`vendor.oppo.hardware.biometrics.face@1.0` `hidl_interface`, which
`biometrics/face/Android.bp` links so the AOSP face@1.0 service can forward
to the stock backend. They are still **not a byte-exact copy** of the
original, so the regenerated interface hash differs from the vendor's (see
below); that does not block `getService()`, which matches by interface name.

Two build details are easy to get wrong and would fail the build if changed:

* The package root `vendor.oppo` is declared by a `hidl_package_root` module
  in `interfaces/vendor/Android.bp`. Without it Soong aborts with
  "Cannot find package root specification for package root 'vendor.oppo'".
* These files must stay at
  `interfaces/vendor/hardware/biometrics/face/1.0/`, i.e.
  `<hidl_package_root dir>/<package minus root>/<version>/`. hidl-gen is handed
  `-rvendor.oppo:<hidl_package_root dir>` and `opendir`s that path to find the
  `.hal` files, so the directory is not free-form.

Package: `vendor.oppo.hardware.biometrics.face@1.0`

| File | Contents |
|------|----------|
| `types.hal` | 5 enums + 3 structs |
| `IBiometricsFace.hal` | 22 methods (transaction codes 1..22) |
| `IBiometricsFaceClientCallback.hal` | 11 callback methods (codes 1..11) |

## How it was recovered

| Data | Source |
|------|--------|
| Method set, order, transaction codes | `BpHwBiometricsFace::_hidl_<m>` bodies (`mov w1,#code` before `transact`) |
| Argument types | demangled `BpHwBiometricsFace::<m>(...)` / `...ClientCallback::<m>(...)` |
| Return wire types | Bn/Bp parcel decode (`int32_t` / `uint64_t`) |
| Enum names + values | generated `toString(<Enum>)` jump tables in `.text`/`.rodata` |
| Struct layouts | generated `toString(const T&)` bodies (field order/type/offset) |
| Interface hashes | `IBiometricsFace::getHashChain` / `...ClientCallback::getHashChain` `.rodata` blobs |

## Frozen hashes observed in the vendor library

```
IBiometricsFace               fb9438a6ebdaf8052c1d27f21e321317e19f227e6b799cd4bf0bac9ea325d7ce
IBiometricsFaceClientCallback 5d07959171b724da3c1291296e1a975308ccaf395cff2db76e9706398f7207a1
android.hidl.base@1.0::IBase  bddab6184d7a346da6a07dc0828cf19a696f4caa3611c51f2e14565a14b40fd9
```

`getHashChain()` returns `[<this interface hash>, <IBase hash>]`
(`Interface::typeChain()` + `Interface::emitDigestChain`).

## The hash is SHA-256 of the `.hal` source file

hidl-gen computes an interface's frozen hash as
`SHA256(<contents of IBiometricsFace.hal>)`
(`hashing/Hash.cpp::sha256File`; `Coordinator.cpp` passes the `.hal` path to
`AST`; `Interface::emitDigestChain` emits `getFileHash()->raw()`).

Consequence: reproducing `fb9438a6...` would require the **exact original
`.hal` bytes** (comments, whitespace, declaration order), which are not in the
dump. This reconstruction is an ABI-faithful *reference*, not a byte-exact
copy, so its regenerated hash will differ.

**This does not block the proxy.** `getService()` resolves a service by
interface *name* (descriptor), not by hash: `getRawServiceInternal()` in
`libhidltransport` calls `canCastInterface()`, which compares descriptor
strings. The hash is only used by `IServiceManager::listByInterface`. So the
reconstructed library built from `Android.bp` here connects to the stock
vendor service by name even though its `getHashChain()` reports a different
digest.

## Remaining uncertainties (affect source hash, not wire ABI)

1. Whether the int32-returning methods declare `RequestStatus` or `int32_t`
   as their return type (assumed `RequestStatus`).
2. Exact enum member declaration order (values are explicit, so ABI is fixed).
3. Original argument names (only wire types are recoverable).

## Wire ABI summary

`IBiometricsFace` (txn code — signature — return):
```
1  authenticate(uint64_t, uint32_t, uint32_t)              int32_t
2  cancelAuthentication()                                  int32_t
3  enroll(uint8_t[69], uint32_t, uint32_t)                 int32_t
4  cancelEnrollment()                                      int32_t
5  preEnroll()                                             uint64_t
6  remove(uint32_t, uint32_t)                              int32_t
7  getAuthenticatorId()                                    uint64_t
8  setActiveGroup(uint32_t, string)                        int32_t
9  setNotify(IBiometricsFaceClientCallback, bool)          uint64_t
10 postEnroll()                                            int32_t
11 executeCommand(uint32_t)                                int32_t
12 cancelCommand(uint32_t)                                 int32_t
13 get(uint32_t)                                           int32_t
14 verifyFace(vec<uint8_t>, uint64_t, uint32_t)            int32_t
15 getEnrollmentTotalTimes()                               int32_t
16 setPreviewFrame(RectHal)                                int32_t
17 setPreviewSurface()                                     int32_t
18 getPreViewWidth()                                       int32_t
19 getPreViewHeight()                                      int32_t
20 dynamicallyConfigLog(FaceLogType, uint32_t)             int32_t
21 updateRusNativeData(float)                              int32_t
22 updateSettingSwitchStatus(SwitchType, bool)             int32_t
```

`IBiometricsFaceClientCallback` (txn code — signature):
```
1  onEnrollResult(uint64_t, uint32_t, uint32_t, uint32_t)
2  onAcquired(uint64_t, FaceAcquiredInfo)
3  onAuthenticated(uint64_t, uint32_t, uint32_t, uint32_t, vec<uint8_t>)
4  onError(uint64_t, FaceError)
5  onRemoved(uint64_t, uint32_t, uint32_t)
6  onEnumerate(uint64_t, vec<uint32_t>, uint32_t)
7  onCommandResult(uint64_t, vec<uint32_t>, vec<string>)
8  onFilterFailedAcquired(uint64_t, uint32_t)
9  onFailReasonAcquired(uint64_t, uint32_t)
10 unlockRawImageDelivery(uint32_t)
11 onStaticsReport(uint32_t, uint32_t)
```
