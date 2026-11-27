//
// Copyright (C) 2026 The LineageOS Project
//
// SPDX-License-Identifier: Apache-2.0
//

// The stock MediaTek/Trustonic keymaster 2.0 module (libMcTeeKeymaster.so) is
// not CFI-instrumented. libkeymaster3device.so, built from AOSP 17.1 source,
// dispatches through that module's ops table via __cfi_slowpath(); Android 10's
// CFI check rejects the non-instrumented targets and aborts
// android.hardware.keymaster@3.0-service in Keymaster2PassthroughContext::
// DeleteKey(). A dead keymaster makes LockSettingsService.verifyCredential()
// return null, which crashes Settings while setting up a fingerprint.
//
// This library is LD_PRELOADed by the keymaster service only. It interposes the
// versioned bionic symbol and turns the check into a no-op for that process;
// CFI remains enabled everywhere else.

#include <stdint.h>

extern "C" void __cfi_slowpath(uint64_t /* type */, const void* /* target */) {}
