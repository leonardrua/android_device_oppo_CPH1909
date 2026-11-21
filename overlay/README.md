# CPH1909 framework overlay

This directory is extracted from the stock OPPO CPH1909 (Android
8.1 / ColorOS 5.2) framework.  It contains only values whose
resource still exists in LineageOS 17.1: a value that Android 10
does not read is never copied, and a value whose 8.1 meaning is ROM
policy rather than device configuration is excluded with a reason.
The four values that are not stock framework values are listed
under "Device capabilities" below with their evidence.

The files are extracted from the stock `framework-res.apk` and the stock
vendor `build.prop`; the LineageOS 17.1 inputs are used only to decide which
resources are still read. The input hashes below pin the exact sources the
extraction was made from.

## Inputs

| Input | SHA-256 |
|---|---|
| `stock framework-res.apk` | `bd1f49eb5422c2e3136b6576c6803b9868764b2cd447323d97c1050b5c0c5be8` |
| `stock vendor build.prop` | `41e8b49c501f0a82522ea57678b89b71002b4ea0a89a92161208e1779ff26380` |
| `LOS 17.1 config.xml` | `0b08039fcedb0921b08878e873b23db3a6ff3ee151cdfa8bdc064c3acad42392` |
| `LOS 17.1 dimens.xml` | `3beae676320ae6cba7389682eddb47b989a8408bec5bb6feb95ab2441b565cc5` |
| `LOS 17.1 PowerProfile.java` | `b273043e3b75bebc90772bc2fb908268c8c65b2ddf8fb25688dec8f2f48a4f97` |

The stock APK comes from the CPH1909 A.46 dump.  The LineageOS
inputs are the 17.1 sources named on the command line; their hashes
above pin the exact revision the extraction was made against.

## Accounting

| Item | Count |
|---|---|
| LOS 17.1 `config.xml` resources | 868 |
| ... also defined by the stock 8.1 framework | 603 |
| ... stock value differs from the LOS 17.1 default | 66 |
| ... stock device configuration (emitted) | 47 |
| ... device capabilities not in the stock framework | 4 |
| ... ROM policy, excluded with a reason | 19 |
| ... stock value equals the LOS 17.1 default (no override needed) | 537 |
| LOS 17.1 resources not present in the stock framework | 265 |

Every resource that differs is either emitted or listed under
"Excluded" below.

## Emitted values

### Display, brightness and navigation

| Resource | LOS 17.1 default | Stock value |
|---|---|---|
| `config_autoBrightnessBrighteningLightDebounce` | `4000` | `1000` |
| `config_autoBrightnessDarkeningLightDebounce` | `8000` | `4000` |
| `config_autoBrightnessLcdBacklightValues` | `0 items` | `7 items` |
| `config_autoBrightnessLevels` | `0 items` | `6 items` |
| `config_autoBrightnessLightSensorRate` | `250` | `500` |
| `config_automatic_brightness_available` | `false` | `true` |
| `config_icon_mask` | `M50,0L92,0C96.42,0 100,4.58 100 8L100,92C100, 96.42 96.42 100 92 100L8 100C4.58, 100 0 96.42 0 92L0 8 C 0 4.42 4.42 0 8 0L50 0Z` | `M50 0C77.6 0 100 22.4 100 50C100 77.6 77.6 100 50 100C22.4 100 0 77.6 0 50C0 22.4 22.4 0 50 0Z` |
| `config_mainBuiltInDisplayCutout` | `` | `M -105,0 L -105,55 L 105,55 L 105,0 Z` |
| `config_screenBrightnessDark` | `1` | `2` |
| `config_screenBrightnessDim` | `10` | `2` |
| `config_screenBrightnessDoze` | `1` | `2` |
| `config_screenBrightnessSettingDefault` | `102` | `44` |
| `config_screenBrightnessSettingMinimum` | `10` | `1` |
| `config_showNavigationBar` | `false` | `true` |
| `config_unplugTurnsOnScreen` | `false` | `true` |
| `config_useRoundIcon` | `false` | `true` |

### Input, sensors and audio jack

| Resource | LOS 17.1 default | Stock value |
|---|---|---|
| `config_suspendWhenScreenOffDueToProximity` | `false` | `true` |
| `config_useDevInputEventForAudioJack` | `false` | `true` |

### Telephony and modem

| Resource | LOS 17.1 default | Stock value |
|---|---|---|
| `config_hotswapCapable` | `false` | `true` |
| `config_mms_user_agent` | `` | `Android-Mms/0.1` |
| `config_mms_user_agent_profile_url` | `` | `http://www.google.com/oha/rdf/ua-profile-kila.xml` |
| `config_switch_phone_on_voice_reg_state_change` | `true` | `false` |
| `networkAttributes` | `12 items` | `18 items` |
| `skip_restoring_network_selection` | `false` | `true` |

### Wi-Fi and connectivity

| Resource | LOS 17.1 default | Stock value |
|---|---|---|
| `config_networkAvoidBadWifi` | `1` | `0` |
| `config_tether_bluetooth_regexs` | `0 items` | `2 items` |
| `config_tether_usb_regexs` | `0 items` | `1 items` |
| `config_tether_wifi_regexs` | `0 items` | `1 items` |
| `config_wifi_background_scan_support` | `false` | `true` |
| `config_wifi_dual_band_support` | `false` | `true` |
| `config_wifi_framework_enable_associated_network_selection` | `true` | `false` |
| `config_wifi_framework_sap_2G_channel_list` | `1,6,11` | `0` |
| `config_wifi_framework_wifi_score_bad_rssi_threshold_24GHz` | `-83` | `-85` |
| `config_wifi_framework_wifi_score_bad_rssi_threshold_5GHz` | `-80` | `-82` |
| `config_wifi_framework_wifi_score_entry_rssi_threshold_24GHz` | `-80` | `-85` |
| `config_wifi_framework_wifi_score_entry_rssi_threshold_5GHz` | `-77` | `-82` |
| `config_wifi_random_mac_oui` | `DA-A1-19` | `00-0C-E7` |

### Bluetooth

| Resource | LOS 17.1 default | Stock value |
|---|---|---|
| `config_bluetooth_hfp_inband_ringing_support` | `false` | `true` |
| `config_bluetooth_idle_cur_ma` | `0` | `1` |
| `config_bluetooth_operating_voltage_mv` | `0` | `3300` |
| `config_bluetooth_rx_cur_ma` | `0` | `2` |
| `config_bluetooth_tx_cur_ma` | `0` | `3` |

### Power and battery

| Resource | LOS 17.1 default | Stock value |
|---|---|---|
| `config_enableAutoPowerModes` | `false` | `true` |
| `config_minimumScreenOffTimeout` | `10000` | `5000` |

### Biometrics

| Resource | LOS 17.1 default | Stock value |
|---|---|---|
| `config_faceMaxTemplatesPerUser` | `1` | `5` |

### Multi-user UI

| Resource | LOS 17.1 default | Stock value |
|---|---|---|
| `config_enableMultiUserUI` | `false` | `true` |
| `config_multiuserMaximumUsers` | `1` | `4` |

## Excluded

These differ between stock and LOS 17.1 but are not device
configuration, or the 8.1 value is wrong for this build.  The
LineageOS 17.1 default is kept.

| Resource | Stock value | Reason |
|---|---|---|
| `config_allowDisablingAssistDisclosure` | `false` | framework UI policy, not device configuration. |
| `config_defaultAccessibilityService` | `com.google.android.marvin.talkback/.TalkBackService` | names TalkBack, which this build does not ship. |
| `config_defaultAutofillService` | `com.google.android.gms/.autofill.service.AutofillService` | names GMS, which this build does not ship. |
| `config_defaultNetworkRecommendationProviderPackage` | `com.google.android.gms` | names GMS, which this build does not ship. |
| `config_enableNightMode` | `false` | framework night-mode policy, not device configuration. |
| `config_ephemeralResolverPackage` | `1 items` | names GMS, which this build does not ship. |
| `config_globalActionsList` | `4 items` | LOS 17.1 adds lockdown, screenshot and emergency actions; the 8.1 list would remove them. |
| `config_inCallNotificationSound` | `/system/media/audio/ui/InCallNotification.ogg` | 8.1 uses /system/media/audio/ui; LOS 17.1 installs the sound under /product/media/audio/ui. |
| `config_locationProviderPackageNames` | `2 items` | stock list includes GMS; LOS 17.1 uses the fused provider only. |
| `config_lockDayNightMode` | `false` | framework permission policy, not device configuration. |
| `config_nonBlockableNotificationPackages` | `0 items` | stock list is empty; LOS 17.1 exempts the dialer and messaging apps from DND. |
| `config_notificationSignalExtractors` | `8 items` | LOS 17.1 adds the Bubble, ZenMode and Critical extractors; the 8.1 list would disable them. |
| `config_persistentDataPackageName` | `com.google.android.gms` | names GMS, which this build does not ship. |
| `config_previousVibrationsDumpLimit` | `20` | dumpsys debug history limit, not device configuration. |
| `config_statusBarIcons` | `30 items` | LOS 17.1 adds the camera, microphone and sensors-off icons; the 8.1 list would hide the privacy indicators. |
| `config_wallpaperCropperPackage` | `com.android.wallpaperpicker` | stock com.android.wallpaperpicker is not shipped. |
| `config_wifi_tether_enable` | `com.android.settings/.TetherService` | names the 8.1 Settings class com.android.settings/.TetherService; LOS 17.1 moved it to com.android.settings/.wifi.tether.TetherService. |
| `config_zen_repeat_callers_threshold` | `3` | DND repeat-caller policy, not device configuration. |
| `default_sms_application` | `com.android.mms` | stock com.android.mms is not shipped; LOS 17.1 uses com.android.messaging. |

## Device capabilities not in the stock framework config

These are the only overlay values that are not read from
`framework-res.apk`.  Each is required by hardware the stock dump
attests, and the evidence is recorded here so the value is not
mistaken for a stock framework default.

| Resource | Value | Evidence |
|---|---|---|
| `config_supportDoubleTapWake` | `true` | the stock kernel touch drivers (NT36525B, ft8006p, himax_summer, ipio_touch_mmi) create /proc/touchpanel/double_tap_enable, and power.mt6765 forwards POWER_FEATURE_DOUBLE_TAP_TO_WAKE to it; the stock framework leaves the AOSP switch false because ColorOS used its own |
| `config_num_physical_slots` | `2` | the stock vendor build.prop sets ro.telephony.sim.count=2 |
| `rounded_corner_radius` | `82px` | all eight real 720x1520 LCM drivers in the stock a46 kernel set corner_pattern_height = corner_pattern_height_bot = 82 (the virtual panel is not a real LCM) |
| `rounded_corner_content_padding` | `82px` | navigation_layout.xml uses it as the start/end margin; it has to clear the 82px hardware corner pattern |

## Power profile

`frameworks/base/core/res/res/xml/power_profile.xml` is the stock
profile with the 8.1 keys mapped to the names LOS 17.1
`PowerProfile` reads:

| 8.1 key | LOS 17.1 key |
|---|---|
| `dsp.audio` | `audio` |
| `dsp.video` | `video` |
| `cpu.speeds.cluster0` | `cpu.core_speeds.cluster0` |
| `cpu.speeds.cluster1` | `cpu.core_speeds.cluster1` |
| `cpu.active.cluster0` | `cpu.core_power.cluster0` |
| `cpu.active.cluster1` | `cpu.core_power.cluster1` |

This matters: `cpu.speeds.clusterN`/`cpu.active.clusterN` are
**not read** by Android 10, which uses
`cpu.core_speeds.clusterN`/`cpu.core_power.clusterN` together with
`cpu.clusters.cores`, so the old overlay's cluster arrays had no
effect on battery statistics.

Dropped because LOS 17.1 does not read them:

- `none` (0)
- `cpu.awake` (9.8)

## Framework dimensions

| Stock resource | LOS 17.1 resource | Value |
|---|---|---|
| `status_bar_height` | `status_bar_height_portrait` | `28dp` |

The stock status bar is 28dp (56px at 320dpi, and the notch is
55px tall); LOS 17.1 made `status_bar_height_portrait` the value the
framework reads, so that is the name used here.

## Layout

| Path | Meaning |
|---|---|
| `frameworks/base/core/res/res/values/config.xml` | device configuration |
| `frameworks/base/core/res/res/values/dimens.xml` | stock status bar height and the 82px hardware corner radius |
| `frameworks/base/packages/SystemUI/res/values/dimens.xml` | nav content margin for the 82px corners |
| `frameworks/base/core/res/res/xml/power_profile.xml` | stock power model, LOS 17.1 keys |
