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

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        vendor/lib*/hw/gralloc.mt6765.so)
            patchelf --add-needed "libutilscallstack.so" "${2}"
            ;;
        vendor/lib*/hw/hwcomposer.mt6765.so)
            patchelf --add-needed "libutilscallstack.so" "${2}"
            ;;
        vendor/lib*/libsrv_um.so)
            patchelf --add-needed "libutilscallstack.so" "${2}"
            ;;
        vendor/lib*/libion_ulit.so)
            patchelf --add-needed "libutilscallstack.so" "${2}"
            ;;
        vendor/lib*/libmtkcam_stdutils.so)
            patchelf --add-needed "libutilscallstack.so" "${2}"
            ;;
        vendor/lib*/libmtkcam_debugutils.so)
            # DT_NEEDED android::CallStack ctor/dtor (moved out of libutils
            # into libutilscallstack in Android 10); blob only NEEDs libutils.
            patchelf --add-needed "libutilscallstack.so" "${2}"
            ;;
        vendor/lib*/hw/android.hardware.sensors@1.0-impl-mediatek.so)
            patchelf --replace-needed "libbase.so" "libbase-v28.so" "${2}"
            ;;
        vendor/lib*/libnvram.so)
            patchelf --replace-needed "libbase.so" "libbase-v28.so" "${2}"
            ;;
        vendor/lib*/libsysenv.so)
            patchelf --replace-needed "libbase.so" "libbase-v28.so" "${2}"
            ;;
        vendor/bin/hw/android.hardware.drm@1.0-service.widevine)
            patchelf --replace-needed "libbase.so" "libbase-v28.so" "${2}"
            ;;
        vendor/bin/hw/android.hardware.wifi@1.0-service)
            patchelf --replace-needed "libbase.so" "libbase-v28.so" "${2}"
            ;;
        vendor/lib*/libavservices_minijail_vendor.so)
            patchelf --replace-needed "libbase.so" "libbase-v28.so" "${2}"
            ;;
        vendor/lib*/hw/vendor.mediatek.hardware.nvram@1.0-impl.so)
            patchelf --replace-needed "libbase.so" "libbase-v28.so" "${2}"
            ;;
        vendor/bin/hw/android.hardware.media.omx@1.0-service)
            patchelf --replace-needed "libbase.so" "libbase-v28.so" "${2}"
            ;;
        vendor/bin/hw/android.hardware.broadcastradio@1.1-service)
            patchelf --replace-needed "libbase.so" "libbase-v28.so" "${2}"
            ;;
        vendor/lib*/libFactoryHALCommon.so)
            patchelf --replace-needed "libbase.so" "libbase-v28.so" "${2}"
            ;;
        vendor/lib*/libhwminijail.so)
            patchelf --replace-needed "libbase.so" "libbase-v28.so" "${2}"
            ;;
        vendor/lib*/libwifi-hal.so)
            patchelf --replace-needed "libbase.so" "libbase-v28.so" "${2}"
            ;;
        vendor/lib*/libmtkcam_sysutils.so)
            patchelf --add-needed "libutilscallstack.so" "${2}"
            ;;
        vendor/lib*/libmtk-ril.so)
            patchelf --add-needed "libutilscallstack.so" "${2}"
            ;;
        vendor/lib*/libcam.camadapter.so)
            patchelf --add-needed "libutilscallstack.so" "${2}"
            ;;
        vendor/lib*/libcam1_utils.so)
            patchelf --add-needed "libutilscallstack.so" "${2}"
            ;;
        vendor/lib*/libmtkcam_device3.so)
            patchelf --add-needed "libutilscallstack.so" "${2}"
            ;;
        vendor/lib*/libaudiocomponentengine_vendor.so)
            patchelf --add-needed "libutilscallstack.so" "${2}"
            ;;
        vendor/bin/mnld)
            patchelf --add-needed "libutilscallstack.so" "${2}"
            ;;
    esac
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
