#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=CPH1909
VENDOR=oppo

INITIAL_COPYRIGHT_YEAR=2026

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

# LineageOS 17.1 ships the helper as vendor/lineage/build/tools/extract_utils.sh;
# LineageOS 18.1+ moved it to the standalone tools/extract-utils project. Try
# both so this tree works on a 17.1 checkout (its target) without breaking on a
# newer one.
HELPER="${ANDROID_ROOT}/vendor/lineage/build/tools/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
fi
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find extract_utils.sh in either:"
    echo "  ${ANDROID_ROOT}/vendor/lineage/build/tools/extract_utils.sh   (LineageOS 17.1)"
    echo "  ${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh          (LineageOS 18.1+)"
    exit 1
fi
source "${HELPER}"

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}"

# Warning headers and guards
write_headers

write_makefiles "${MY_DIR}/proprietary-files.txt" true

# Finish
write_footers
