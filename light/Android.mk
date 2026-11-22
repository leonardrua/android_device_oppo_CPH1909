# Custom lights HAL for OPPO CPH1909 (MT6765), adapted from the LineageOS
# light@2.0 template (xiaomi-lotus lineage-17.1 / oppo OP4BFB lineage-20).
#
# Uses Android.mk (not Android.bp) for the same reason as power/Android.mk:
# the top-level Android.mk makes Soong's finder stop descending, so a
# subdirectory Android.bp would never be parsed. This file is picked up by the
# all-makefiles-under() include at the end of the top-level Android.mk.

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := android.hardware.light@2.0-service.CPH1909
LOCAL_MODULE_RELATIVE_PATH := hw
LOCAL_PROPRIETARY_MODULE := true
LOCAL_MODULE_TAGS := optional

LOCAL_INIT_RC := android.hardware.light@2.0-service.CPH1909.rc
LOCAL_SRC_FILES := service.cpp Light.cpp

LOCAL_SHARED_LIBRARIES := \
    libhardware \
    libhidlbase \
    liblog \
    libutils \
    android.hardware.light@2.0

LOCAL_CFLAGS := -Wall -Werror

include $(BUILD_EXECUTABLE)