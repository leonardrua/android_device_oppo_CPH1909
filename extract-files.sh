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
        # /system-side copies of the same MTK ION util library. These are not
        # reached by the vendor-side injection above, and unlike the MTK camera
        # libraries they have no dependency in their closure that pulls
        # libutilscallstack.so in, so they fail dlopen with
        # "cannot locate symbol _ZN7android9CallStackC1EPKci" without this.
        system/lib*/libion_ulit_sys.so)
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
        # /system-side blobs that import the 8.1 android::base ABI.
        # Android 9 added a `const char* tag` parameter to LogMessage's
        # constructor and Android 10 dropped the 5-argument overload entirely
        # (base/include/android-base/logging.h:434), so pointing these at
        # AOSP 10's libbase.so makes them fail BIND_NOW with
        # "cannot locate symbol _ZN7android4base10LogMessageC1EPKcjNS0_5LogIdENS0_11LogSeverityEi".
        # libbase-v28.so (prebuilts/vndk/v28, copied to both /vendor and
        # /system by device.mk) still exports that 5-arg form.
        system/lib*/libnvram_mtk.so)
            patchelf --replace-needed "libbase.so" "libbase-v28.so" "${2}"
            ;;
        system/lib*/libshowlogo.so)
            patchelf --replace-needed "libbase.so" "libbase-v28.so" "${2}"
            ;;
        system/lib*/libsysenv_system.so)
            patchelf --replace-needed "libbase.so" "libbase-v28.so" "${2}"
            ;;
        # Android 10 dropped audio::V2_0::toString(Result) from the VNDK
        # audio@2.0 interface lib; the 8.1 vendor HAL still imports it.
        vendor/bin/hw/android.hardware.audio@2.0-service-mediatek)
            patchelf --add-needed "libaudio_abi_v28.so" "${2}"
            ;;
        vendor/lib*/hw/android.hardware.audio@2.0-impl-mediatek.so | \
        vendor/lib*/hw/android.hardware.audio.effect@2.0-impl.so)
            patchelf --add-needed "libaudio_abi_v28.so" "${2}"
            ;;
        # These blobs use the v28 LogMessage ABI but their process also loads
        # Android 10 VNDK-SP libs needing the current string_view helpers.
        vendor/bin/hw/android.hardware.drm@1.0-service.widevine | \
        vendor/bin/hw/android.hardware.wifi@1.0-service)
            patchelf --add-needed "libbase_compat.so" "${2}"
            ;;
        # Android 10 dropped hidl::base::V1_0::toString(DebugInfo) and
        # changed GraphicBufferMapper::lock's signature. The 8.1 camera
        # HALs still import both old forms.
        vendor/lib*/hw/android.hardware.camera.provider@2.4-impl-mediatek.so | \
        vendor/lib*/hw/vendor.mediatek.hardware.camera.callbackclient@1.0-impl.so | \
        vendor/lib*/libmtkcam_device1.so | \
        vendor/lib*/libmtkcam_device3_app.so | \
        vendor/lib*/libmtkcam_cct.so)
            patchelf --add-needed "libcamera_abi_v28.so" "${2}"
            ;;
        # 8.1 MTK ViLTE libs import the MediaSource destructor thunk that
        # Android 10 no longer generates; vtservice cannot link without it.
        vendor/lib*/libaudio_param_parser-vnd.so)
            patchelf --remove-needed "libicuuc.so" "${2}"
            ;;
        vendor/bin/hw/vtservice_hidl)
            patchelf --replace-needed "vendor.mediatek.hardware.videotelephony@1.0.so" "vendor.mediatek.hardware.videotelephony@1.0_vendor.so" "${2}"
            ;;
        system/lib/libsource.so | \
        system/lib/libsink.so | \
        system/lib/libimsma.so | \
        system/lib/libstagefright_wfd_mtk.so | \
        system/lib/libmtkavenhancements.so)
            patchelf --add-needed "libvtservice_abi_v28.so" "${2}"
            ;;
        # Android 10 no longer exports the radio@1.0 struct helpers the
        # stock MTK RIL imports.
        vendor/lib*/vendor.mediatek.hardware.radio@2.0_vendor.so)
            patchelf --add-needed "libradio_abi_v28.so" "${2}"
            ;;
        # 8.1 IMS stack imports HTTPBase socket tagging helpers.
        system/lib/libimsma_socketwrapper.so)
            patchelf --add-needed "libims_abi_v28.so" "${2}"
            ;;
        # libsensor.so (shipped into /vendor) imports hidden AppOpsManager
        # symbols; provide them in the process that loads it.
        vendor/lib*/libFactoryHALSensor.so)
            patchelf --add-needed "libsensor_abi_v28.so" "${2}"
            ;;
        # 8.1 wifi service imports a HIDL toString helper dropped in Android 10.
        vendor/bin/hw/android.hardware.wifi@1.0-service)
            patchelf --add-needed "libwifi_abi_v28.so" "${2}"
            ;;
        # Android 10 removed the SurfaceFlinger APIs the stock libshowlogo
        # imports; kpoc_charger cannot start offline charging without it.
        system/lib/libshowlogo.so)
            patchelf --add-needed "libshim_showlogo.so" "${2}"
            ;;
        system/lib/libsysenv_system.so)
            patchelf --add-needed "libshim_showlogo.so" "${2}"
            ;;
        vendor/lib*/hw/vendor.mediatek.hardware.nvram@1.0-impl.so)
            patchelf --replace-needed "libbase.so" "libbase-v28.so" "${2}"
            ;;
        vendor/lib*/libFactoryHALCommon.so)
            patchelf --replace-needed "libbase.so" "libbase-v28.so" "${2}"
            ;;
        vendor/lib*/libwifi-hal.so)
            patchelf --replace-needed "libbase.so" "libbase-v28.so" "${2}"
            ;;
        # These four were linked with an NDK toolchain whose RUNPATH/RPATH points
        # at the build machine (/opt/ndk17/..., /data/Project_Code/...). bionic
        # ignores DT_RPATH/DT_RUNPATH so it is harmless, but it embeds the
        # builder's filesystem in the image; strip it.
        vendor/lib*/libmegsegment.so | vendor/lib*/libwa_common_wt98607.so)
            patchelf --remove-rpath "${2}"
            ;;
        vendor/lib*/libmtkcam_sysutils.so)
            patchelf --add-needed "libutilscallstack.so" "${2}"
            ;;
        vendor/lib*/libmtk-ril.so)
            patchelf --add-needed "libutilscallstack.so" "${2}"
            # The 8.1 blob reserves the 8.1 Parcel size (104 bytes), but
            # Android 10's libbinder Parcel is 120 bytes.  Move the two
            # thermal-handler Parcels down by 8 bytes and grow the two AGPS
            # heap allocations; see the script for the full explanation.
            python3 "${MY_DIR}/tools/patch-mtk-ril-parcel-abi.py" "${2}"
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
