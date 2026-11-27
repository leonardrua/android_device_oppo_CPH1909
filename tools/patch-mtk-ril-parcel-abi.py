#!/usr/bin/env python3
"""Fix the Android 8.1 Parcel ABI mismatch in the stock libmtk-ril.so.

The CPH1909 ColorOS 5.2 RIL blob was built against Android 8.1's libbinder,
where sizeof(android::Parcel) is 104 bytes.  LineageOS 17.1 runs Android 10's
libbinder, where Parcel is 120 bytes: two fields were inserted before the
flags and the trailing mOpenAshmemSize moved from offset 96 to 112.

The blob still reserves the 8.1 size, so Parcel::initState() writes
mOpenAshmemSize eight bytes past the end of the object.  In the two
RilOemClient thermal handlers the object starts at sp+8 and the stack canary
is at sp+120, so that store lands exactly on the canary and every
THERMAL,0,0,0,0 indication aborts mtkfusionrild with "stack corruption
detected".  The two AGPS handlers allocate their Parcel with new(0x68), so
the same store overflows the heap allocation.

This script:
  * moves the Parcel in executeThermal() and executeShutDownByThermal()
    from sp+8 to sp, so the 120-byte object ends at the canary at sp+120
    instead of overwriting it (the old sp+0..7 slot is unused);
  * grows the two heap Parcel allocations from 104 to 120 bytes.

It is idempotent and verifies every original instruction word first, so it
fails loudly if the blob is not the expected CPH1909 build.  The 32-bit copy
in /vendor/lib is skipped: only the 64-bit mtkfusionrild loads this library.
"""

import struct
import sys

# (virtual address, original instruction, patched instruction, description)
PATCHES = (
    (0x1CA8B4, 0x910023E0, 0x910003E0, "executeThermal: Parcel base sp+8 -> sp"),
    (0x1CAA48, 0x910023E0, 0x910003E0, "executeThermal: Parcel base sp+8 -> sp"),
    (0x1CAAE0, 0x910023E0, 0x910003E0, "executeShutDownByThermal: Parcel base sp+8 -> sp"),
    (0x1CAC6C, 0x910023E0, 0x910003E0, "executeShutDownByThermal: Parcel base sp+8 -> sp"),
    (0x1CEAA8, 0x52800D00, 0x52800F00, "sendAgpsMessage: Parcel allocation 104 -> 120"),
    (0x1CF874, 0x52800D00, 0x52800F00, "processInput: Parcel allocation 104 -> 120"),
)


def load_segments(data):
    if data[:4] != b"\x7fELF" or data[4] != 2 or data[5] != 1:
        raise SystemExit("not a little-endian ELF64 file")
    e_phoff = struct.unpack_from("<Q", data, 32)[0]
    e_phentsize = struct.unpack_from("<H", data, 54)[0]
    e_phnum = struct.unpack_from("<H", data, 56)[0]

    segments = []
    for index in range(e_phnum):
        offset = e_phoff + index * e_phentsize
        p_type, _, p_offset, p_vaddr, _, p_filesz, _, _ = struct.unpack_from(
            "<IIQQQQQQ", data, offset
        )
        if p_type == 1:  # PT_LOAD
            segments.append((p_vaddr, p_offset, p_filesz))
    return segments


def vaddr_to_offset(segments, vaddr):
    for p_vaddr, p_offset, p_filesz in segments:
        if p_vaddr <= vaddr < p_vaddr + p_filesz:
            return p_offset + (vaddr - p_vaddr)
    raise SystemExit("virtual address %#x is not backed by a PT_LOAD segment" % vaddr)


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: %s libmtk-ril.so" % sys.argv[0])

    path = sys.argv[1]
    with open(path, "rb") as blob:
        data = bytearray(blob.read())

    if data[:4] != b"\x7fELF":
        raise SystemExit("%s: not an ELF file" % path)
    if data[4] == 1:
        # Only the 64-bit daemon loads libmtk-ril.so; the 32-bit copy in
        # /vendor/lib is not used by mtkfusionrild.
        print("%s: 32-bit ELF, skipping (the 64-bit daemon uses lib64)" % path)
        return

    segments = load_segments(data)
    changed = 0
    for vaddr, expected, replacement, description in PATCHES:
        offset = vaddr_to_offset(segments, vaddr)
        word = struct.unpack_from("<I", data, offset)[0]
        if word == replacement:
            print("already patched: %s" % description)
            continue
        if word != expected:
            raise SystemExit(
                "%s: unexpected instruction %08x at %#x (file offset %#x)"
                % (description, word, vaddr, offset)
            )
        struct.pack_into("<I", data, offset, replacement)
        print("patched: %s" % description)
        changed += 1

    if changed:
        with open(path, "wb") as blob:
            blob.write(data)
        print("wrote %s (%d instruction%s)" % (path, changed, "" if changed == 1 else "s"))
    else:
        print("nothing to do")


if __name__ == "__main__":
    main()
