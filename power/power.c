/*
 * Copyright (C) 2012 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#define LOG_TAG "CPH1909PowerHAL"

#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include <log/log.h>

#include <hardware/hardware.h>
#include <hardware/power.h>

static void sysfs_write(const char *path, const char *s)
{
    char buf[80];
    int len;
    int fd;

    fd = open(path, O_WRONLY | O_CLOEXEC);
    if (fd < 0) {
        strerror_r(errno, buf, sizeof(buf));
        ALOGE("Error opening %s: %s", path, buf);
        return;
    }

    len = write(fd, s, strlen(s));
    if (len < 0) {
        strerror_r(errno, buf, sizeof(buf));
        ALOGE("Error writing to %s: %s", path, buf);
    }

    close(fd);
}

static void power_init(struct power_module *module)
{
    (void)module;

    ALOGI("CPH1909 power HAL shim init");
}

static void power_set_interactive(struct power_module *module, int on)
{
    (void)module;

    ALOGV("power_set_interactive: %d", on);
}

static void power_hint(struct power_module *module, power_hint_t hint,
                       void *data)
{
    (void)module;
    (void)data;

    ALOGV("power_hint: %d", hint);
}

static void set_feature(struct power_module *module, feature_t feature, int state)
{
    (void)module;

    switch (feature) {
#ifdef TAP_TO_WAKE_NODE
    case POWER_FEATURE_DOUBLE_TAP_TO_WAKE:
        ALOGI("double tap to wake: %s (%s)", state ? "on" : "off", TAP_TO_WAKE_NODE);
        sysfs_write(TAP_TO_WAKE_NODE, state ? "1" : "0");
        break;
#endif
    default:
        break;
    }
}

static struct hw_module_methods_t power_module_methods = {
    .open = NULL,
};

struct power_module HAL_MODULE_INFO_SYM = {
    .common = {
        .tag = HARDWARE_MODULE_TAG,
        .module_api_version = POWER_MODULE_API_VERSION_0_3,
        .hal_api_version = HARDWARE_HAL_API_VERSION,
        .id = POWER_HARDWARE_MODULE_ID,
        .name = "CPH1909 Power HAL Shim",
        .author = "The Android Open Source Project",
        .methods = &power_module_methods,
    },

    .init = power_init,
    .setInteractive = power_set_interactive,
    .powerHint = power_hint,
    .setFeature = set_feature,
};
