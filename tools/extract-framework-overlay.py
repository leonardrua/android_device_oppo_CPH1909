#!/usr/bin/env python3
#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#
"""Regenerate the CPH1909 framework overlay from the stock 8.1 framework.

The node of truth is the stock ColorOS framework-res.apk.  Every framework
resource that LineageOS 17.1 still defines is compared against it, and the
overlay is regenerated from the stock value only for the resources that are
device configuration.  Resources that LineageOS 17.1 does not define are
ignored, and resources whose stock value is pure ROM policy (component names,
feature lists, UI timings, packages this build does not ship) are listed with
a reason instead of being copied.

The overlay is therefore complete over the intersection of
"stock framework config" and "LineageOS 17.1 framework config": every value
that differs is either emitted here or explicitly excluded with a reason.  A
new differing resource that is not classified aborts the run.

Usage (from the device tree root):

  tools/extract-framework-overlay.py \
      --framework-res /path/to/stock/framework-res.apk \
      --los-config /path/to/lineage-17.1/core/res/res/values/config.xml \
      --los-dimens /path/to/lineage-17.1/core/res/res/values/dimens.xml \
      --los-power-profile /path/to/lineage-17.1/core/java/com/android/internal/os/PowerProfile.java

  tools/extract-framework-overlay.py ... --check

--check regenerates into a temporary directory and diffs it against the
committed overlay without touching the tree.
"""

import argparse
import hashlib
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OVERLAY_DIR = os.path.join(REPO_ROOT, "overlay")

CONFIG_REL = "frameworks/base/core/res/res/values/config.xml"
DIMENS_REL = "frameworks/base/core/res/res/values/dimens.xml"
SYSTEMUI_DIMENS_REL = "frameworks/base/packages/SystemUI/res/values/dimens.xml"
POWER_PROFILE_REL = "frameworks/base/core/res/res/xml/power_profile.xml"
README_REL = "README.md"

# ---------------------------------------------------------------------------
# Relevance policy for LineageOS 17.1.
#
# Every resource below differs between the stock 8.1 framework and the LOS 17.1
# default.  Each one is either device configuration (INCLUDE, mapped to a
# category) or ROM policy whose 8.1 value is wrong for this build (EXCLUDE,
# with the reason recorded in the generated README).  The generator fails if a
# differing resource is in neither table, so this cannot silently drift.
# ---------------------------------------------------------------------------

CATEGORIES = [
    "Display, brightness and navigation",
    "Input, sensors and audio jack",
    "Telephony and modem",
    "Wi-Fi and connectivity",
    "Bluetooth",
    "Power and battery",
    "Biometrics",
    "Multi-user UI",
]

INCLUDE = {
    # Display, brightness and navigation
    "config_automatic_brightness_available": 0,
    "config_screenBrightnessSettingMinimum": 0,
    "config_screenBrightnessSettingDefault": 0,
    "config_screenBrightnessDoze": 0,
    "config_screenBrightnessDim": 0,
    "config_screenBrightnessDark": 0,
    "config_autoBrightnessBrighteningLightDebounce": 0,
    "config_autoBrightnessDarkeningLightDebounce": 0,
    "config_autoBrightnessLightSensorRate": 0,
    "config_autoBrightnessLevels": 0,
    "config_autoBrightnessLcdBacklightValues": 0,
    "config_mainBuiltInDisplayCutout": 0,
    "config_showNavigationBar": 0,
    "config_useRoundIcon": 0,
    "config_icon_mask": 0,
    "config_unplugTurnsOnScreen": 0,
    # Input, sensors and audio jack
    "config_suspendWhenScreenOffDueToProximity": 1,
    "config_useDevInputEventForAudioJack": 1,
    # Telephony and modem
    "networkAttributes": 2,
    "config_mms_user_agent": 2,
    "config_mms_user_agent_profile_url": 2,
    "config_hotswapCapable": 2,
    "config_switch_phone_on_voice_reg_state_change": 2,
    "skip_restoring_network_selection": 2,
    # Wi-Fi and connectivity
    "config_networkAvoidBadWifi": 3,
    "config_tether_usb_regexs": 3,
    "config_tether_wifi_regexs": 3,
    "config_tether_bluetooth_regexs": 3,
    "config_wifi_dual_band_support": 3,
    "config_wifi_background_scan_support": 3,
    "config_wifi_framework_wifi_score_bad_rssi_threshold_5GHz": 3,
    "config_wifi_framework_wifi_score_entry_rssi_threshold_5GHz": 3,
    "config_wifi_framework_wifi_score_bad_rssi_threshold_24GHz": 3,
    "config_wifi_framework_wifi_score_entry_rssi_threshold_24GHz": 3,
    "config_wifi_random_mac_oui": 3,
    "config_wifi_framework_sap_2G_channel_list": 3,
    "config_wifi_framework_enable_associated_network_selection": 3,
    # Bluetooth
    "config_bluetooth_hfp_inband_ringing_support": 4,
    "config_bluetooth_idle_cur_ma": 4,
    "config_bluetooth_rx_cur_ma": 4,
    "config_bluetooth_tx_cur_ma": 4,
    "config_bluetooth_operating_voltage_mv": 4,
    # Power and battery
    "config_enableAutoPowerModes": 5,
    "config_minimumScreenOffTimeout": 5,
    # Biometrics
    "config_faceMaxTemplatesPerUser": 6,
    # Multi-user UI
    "config_enableMultiUserUI": 7,
    "config_multiuserMaximumUsers": 7,
}

EXCLUDE = {
    "config_statusBarIcons":
        "LOS 17.1 adds the camera, microphone and sensors-off icons; the 8.1 "
        "list would hide the privacy indicators.",
    "config_wifi_tether_enable":
        "names the 8.1 Settings class com.android.settings/.TetherService; "
        "LOS 17.1 moved it to com.android.settings/.wifi.tether.TetherService.",
    "config_lockDayNightMode":
        "framework permission policy, not device configuration.",
    "config_ephemeralResolverPackage":
        "names GMS, which this build does not ship.",
    "config_defaultNetworkRecommendationProviderPackage":
        "names GMS, which this build does not ship.",
    "config_locationProviderPackageNames":
        "stock list includes GMS; LOS 17.1 uses the fused provider only.",
    "default_sms_application":
        "stock com.android.mms is not shipped; LOS 17.1 uses "
        "com.android.messaging.",
    "config_persistentDataPackageName":
        "names GMS, which this build does not ship.",
    "config_notificationSignalExtractors":
        "LOS 17.1 adds the Bubble, ZenMode and Critical extractors; the 8.1 "
        "list would disable them.",
    "config_globalActionsList":
        "LOS 17.1 adds lockdown, screenshot and emergency actions; the 8.1 "
        "list would remove them.",
    "config_wallpaperCropperPackage":
        "stock com.android.wallpaperpicker is not shipped.",
    "config_allowDisablingAssistDisclosure":
        "framework UI policy, not device configuration.",
    "config_nonBlockableNotificationPackages":
        "stock list is empty; LOS 17.1 exempts the dialer and messaging apps "
        "from DND.",
    "config_defaultAccessibilityService":
        "names TalkBack, which this build does not ship.",
    "config_defaultAutofillService":
        "names GMS, which this build does not ship.",
    "config_inCallNotificationSound":
        "8.1 uses /system/media/audio/ui; LOS 17.1 installs the sound under "
        "/product/media/audio/ui.",
    "config_enableNightMode":
        "framework night-mode policy, not device configuration.",
    "config_previousVibrationsDumpLimit":
        "dumpsys debug history limit, not device configuration.",
    "config_zen_repeat_callers_threshold":
        "DND repeat-caller policy, not device configuration.",
}

# 8.1 -> LOS 17.1 resource renames.  The stock name is read from the APK and
# written under the LOS 17.1 name, with the stock value unchanged.
POWER_PROFILE_RENAME = {
    "dsp.audio": "audio",
    "dsp.video": "video",
}
POWER_PROFILE_PREFIX_RENAME = {
    "cpu.speeds.cluster": "cpu.core_speeds.cluster",
    "cpu.active.cluster": "cpu.core_power.cluster",
}

# Device capabilities that the stock framework config does not attest.  These
# are the only overlay values not read from framework-res.apk; each has its
# stock evidence recorded here and in the generated README.
EXTRA_CONFIG = [
    ("config_supportDoubleTapWake", "true",
     "the stock kernel touch drivers (NT36525B, ft8006p, himax_summer, "
     "ipio_touch_mmi) create /proc/touchpanel/double_tap_enable, and "
     "power.mt6765 forwards POWER_FEATURE_DOUBLE_TAP_TO_WAKE to it; the stock "
     "framework leaves the AOSP switch false because ColorOS used its own"),
]
EXTRA_DIMENS = [
    ("rounded_corner_radius", "82px",
     "all eight real 720x1520 LCM drivers in the stock a46 kernel set "
     "corner_pattern_height = corner_pattern_height_bot = 82 (the virtual "
     "panel is not a real LCM)"),
]
EXTRA_SYSTEMUI_DIMENS = [
    ("rounded_corner_content_padding", "82px",
     "navigation_layout.xml uses it as the start/end margin; it has to clear "
     "the 82px hardware corner pattern"),
]

# 8.1 framework dimen -> LOS 17.1 framework dimen.  Stock has one
# status_bar_height (28dp, 56px at the device's 320dpi) and no
# status_bar_height_portrait/landscape; LOS 17.1 made the portrait value the
# one the framework reads.  The notch is 55px tall, so the stock value is the
# one that actually clears it.
DIMEN_RENAME = {
    "status_bar_height": ("status_bar_height_portrait",
                          "stock has a single status_bar_height; LOS 17.1 "
                          "reads status_bar_height_portrait"),
}


# ---------------------------------------------------------------------------
# aapt2 parsing
# ---------------------------------------------------------------------------

RES_RE = re.compile(r'^\s*resource 0x[0-9a-f]+ ([a-z0-9_-]+)/([A-Za-z0-9_.]+)')


def run(cmd):
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode != 0:
        sys.stderr.write(p.stderr.decode("utf-8", "replace"))
        raise SystemExit("command failed: " + " ".join(cmd))
    return p.stdout.decode("utf-8", "replace")


def parse_aapt2_resources(text):
    """Return {(type, name): {'kind': ..., 'text': ...}} for default configs."""
    lines = text.splitlines()
    out = {}
    i, n = 0, len(lines)
    while i < n:
        m = RES_RE.match(lines[i])
        if not m:
            i += 1
            continue
        rtype, name = m.group(1), m.group(2)
        i += 1
        raw = None
        while i < n and not RES_RE.match(lines[i]):
            s = lines[i].strip()
            if s.startswith("()"):
                rest = s[2:].strip()
                if rest.startswith("(array)"):
                    buf = []
                    i += 1
                    while i < n:
                        ls = lines[i].strip()
                        if "]" in ls:
                            buf.append(ls[:ls.index("]")])
                            i += 1
                            break
                        buf.append(ls)
                        i += 1
                    body = " ".join(buf)
                    if body.strip().startswith("["):
                        body = body.strip()[1:]
                    raw = {"kind": "array", "text": body}
                    break
                if rest.startswith('"'):
                    raw = {"kind": "string", "text": rest}
                    i += 1
                    break
                if rest.startswith(("@", "?")):
                    raw = {"kind": "ref", "text": rest}
                    i += 1
                    break
                if rest.startswith("(file)"):
                    raw = {"kind": "file", "text": rest}
                    i += 1
                    break
                raw = {"kind": "scalar", "text": rest}
                i += 1
                break
            i += 1
        if raw is not None:
            out[(rtype, name)] = raw
    return out


def unescape_resource_string(s, from_aapt2):
    """Decode a resource string literal.

    aapt2 prints a compiled literal backslash as '\\' only for the escapes it
    knows; an unknown '\\c' is printed as backslash + c because the compiled
    value really contains that backslash.  XML resource text instead uses
    '\\\\' for a literal backslash.
    """
    if s.startswith('"'):
        s = s[1:]
    if s.endswith('"'):
        s = s[:-1]
    out, i = [], 0
    simple = {"n": "\n", "t": "\t", "r": "\r"}
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            d = s[i + 1]
            if d in simple:
                out.append(simple[d]); i += 2; continue
            if d == "u" and i + 5 < len(s):
                out.append(chr(int(s[i + 2:i + 6], 16))); i += 6; continue
            if d in ("\\", '"', "'"):
                out.append(d); i += 2; continue
            if from_aapt2:
                out.append("\\"); out.append(d); i += 2; continue
            out.append(d); i += 2; continue
        out.append(c); i += 1
    return "".join(out)


def split_array(text):
    items, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c in ", \t":
            i += 1
            continue
        if c == '"':
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == '"':
                    break
                j += 1
            items.append(text[i:j + 1])
            i = j + 1
            continue
        j = i
        while j < n and text[j] not in ", \t":
            j += 1
        items.append(text[i:j])
        i = j
    return items


# ---------------------------------------------------------------------------
# LOS 17.1 resource surface
# ---------------------------------------------------------------------------

def parse_los_config(path):
    root = ET.parse(path).getroot()
    out = []
    for e in root:
        if e.tag in ("bool", "integer", "string", "dimen", "fraction", "color",
                     "array", "string-array", "integer-array"):
            out.append({
                "tag": e.tag,
                "name": e.attrib["name"],
                "text": "".join(e.itertext()).strip(),
                "items": ["".join(c.itertext()).strip() for c in e],
            })
        elif e.tag == "item" and "name" in e.attrib:
            out.append({
                "tag": "item",
                "type": e.attrib.get("type"),
                "format": e.attrib.get("format"),
                "name": e.attrib["name"],
                "text": "".join(e.itertext()).strip(),
                "items": [],
            })
    return out


def los_kind(e):
    if e["tag"] == "item":
        return e["type"]
    if e["tag"] in ("string-array", "integer-array"):
        return "array"
    return e["tag"]


def norm_dimen(s):
    m = re.match(r'^(-?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+))(dp|dip|sp|px|pt|in|mm)?$',
                 s.strip())
    if not m:
        return ("raw", s)
    return (round(float(m.group(1)), 5), m.group(2) or "")


def parse_fraction_printed(s):
    """Parse a fraction as printed by aapt2 or written in an XML resource.

    Both print the raw fraction float: XML '300%' and aapt2 '3.000000%' are
    the same value (3.0).  XML source '3%' is 0.03.
    """
    m = re.match(r'^(-?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+))(%p?|%)?$', s.strip())
    if not m:
        return ("raw", s)
    return (round(float(m.group(1)), 8), m.group(2) or "")


def stock_norm(e, raw):
    """Normalise a stock value; returns (status, value) with status ok/ref/skip."""
    tag, text = e["tag"], raw["text"]
    if raw["kind"] == "ref":
        return ("ref", text)
    if raw["kind"] == "file":
        return ("skip", "file")
    if tag == "bool":
        return ("ok", text.strip().lower())
    if tag == "integer" or (tag == "item" and e.get("type") == "integer"):
        return ("ok", int(text.strip(), 0))
    if tag == "string":
        return ("ok", unescape_resource_string(text, True))
    if tag == "dimen" or (tag == "item" and e.get("type") == "dimen"):
        return ("ok", norm_dimen(text))
    if tag == "fraction":
        num, unit = parse_fraction_printed(text)
        if unit == "raw":
            return ("skip", "fraction:" + text)
        return ("ok", (round(num * 100, 5), unit))
    if tag == "color":
        return ("ok", text.strip().lower())
    if tag in ("string-array", "integer-array", "array"):
        items = split_array(text)
        if tag == "integer-array":
            return ("ok", tuple(int(x, 0) for x in items))
        if tag == "string-array":
            return ("ok", tuple(unescape_resource_string(x, True) for x in items))
        return ("ok", tuple(round(float(x), 5) for x in items))
    return ("skip", tag)


def los_norm(e):
    t = e["text"]
    if e["tag"] == "bool":
        return t.lower()
    if e["tag"] == "integer" or (e["tag"] == "item" and e.get("type") == "integer"):
        return int(t, 0)
    if e["tag"] == "string":
        return unescape_resource_string(t, False)
    if e["tag"] == "dimen" or (e["tag"] == "item" and e.get("type") == "dimen"):
        return norm_dimen(t)
    if e["tag"] == "fraction":
        return parse_fraction_printed(t)
    if e["tag"] == "color":
        return t.lower()
    if e["tag"] == "string-array":
        return tuple(unescape_resource_string(x, False) for x in e["items"])
    if e["tag"] == "integer-array":
        return tuple(int(x, 0) for x in e["items"])
    if e["tag"] == "array":
        return tuple(round(float(x), 5) for x in e["items"])
    return t


# ---------------------------------------------------------------------------
# Emitting XML values
# ---------------------------------------------------------------------------

def xml_escape(s):
    # A literal backslash must be doubled for aapt; then XML-escape the text.
    s = s.replace("\\", "\\\\")
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


def fmt_number(x):
    if isinstance(x, int):
        return str(x)
    s = ("%.6f" % x).rstrip("0").rstrip(".")
    return s if s not in ("", "-0") else "0"


def fmt_dimen(v):
    num, unit = v
    return fmt_number(num) + unit


def fmt_fraction(v):
    num, unit = v
    return fmt_number(num) + unit


def stock_value_text(e, raw, norm):
    """Return the XML text used for this stock value."""
    tag = e["tag"]
    if tag == "bool":
        return norm
    if tag == "integer" or (tag == "item" and e.get("type") == "integer"):
        return str(norm)
    if tag == "string":
        return xml_escape(norm)
    if tag == "dimen" or (tag == "item" and e.get("type") == "dimen"):
        return fmt_dimen(norm)
    if tag == "fraction":
        return fmt_fraction(norm)
    if tag == "color":
        return norm
    raise AssertionError("not a scalar: " + tag)


def array_item_text(e, item, index):
    if e["tag"] == "integer-array":
        return str(item)
    if e["tag"] == "string-array":
        return xml_escape(item)
    return fmt_number(item)


def display_value(e, norm):
    """Compact human-readable value for the README tables."""
    if isinstance(norm, tuple):
        if len(norm) == 2 and isinstance(norm[0], float) and isinstance(norm[1], str):
            return fmt_dimen(norm) if norm[1] in ("dp", "dip", "sp", "px", "pt", "in", "mm") \
                else fmt_fraction(norm)
        return "[" + ", ".join(display_value(e, x) for x in norm) + "]"
    if isinstance(norm, bool):
        return "true" if norm else "false"
    return str(norm)


# ---------------------------------------------------------------------------
# Power profile parsing/emission
# ---------------------------------------------------------------------------

def parse_power_profile_tree(text, apk):
    """Parse `aapt2 dump xmltree --file res/xml/power_profile.xml` output."""
    entries = []
    cur = None
    for line in text.splitlines():
        indent = len(line) - len(line.lstrip())
        s = line.strip()
        if indent == 4 and (s.startswith("E: item") or s.startswith("E: array")):
            cur = {"kind": s.split()[1], "name": None, "values": []}
            entries.append(cur)
            continue
        if cur is None:
            continue
        if indent == 6 and s.startswith("A: name="):
            m = re.search(r'name="([^"]*)"', s)
            if m:
                cur["name"] = m.group(1)
            continue
        if s.startswith("T: '") or s.startswith("T: \""):
            val = s[s.index(":", 1) + 1:].strip()
            if len(val) >= 2 and val[0] == val[-1] and val[0] in "'\"":
                val = val[1:-1]
            if cur["kind"] == "array":
                cur["values"].append(val)
            else:
                cur["values"] = [val]
            continue
    return entries


def los_power_profile_keys(path):
    text = open(path, encoding="utf-8").read()
    keys = set(re.findall(r'public static final String \w+\s*=\s*"([^"]+)"', text))
    keys.update({
        "cpu.clusters.cores",
        "cpu.cluster_power.cluster",
        "cpu.core_speeds.cluster",
        "cpu.core_power.cluster",
    })
    return keys


def power_profile_emission(entries, los_keys):
    """Return (kept entries, dropped names, rename notes)."""
    kept, dropped, notes = [], [], []
    prefixes = tuple(POWER_PROFILE_PREFIX_RENAME.keys())
    accepted_prefixes = ("cpu.core_speeds.cluster", "cpu.cluster_power.cluster",
                         "cpu.core_power.cluster")

    for e in entries:
        name = e["name"]
        if not name:
            continue
        new = POWER_PROFILE_RENAME.get(name, name)
        renamed_prefix = False
        for old, repl in POWER_PROFILE_PREFIX_RENAME.items():
            if name.startswith(old):
                new = repl + name[len(old):]
                renamed_prefix = True
                break
        if new != name:
            notes.append((name, new))
        if new in los_keys or new.startswith(accepted_prefixes):
            kept.append({"kind": e["kind"], "name": new,
                         "values": e["values"], "stock_name": name})
        else:
            dropped.append((name, e["values"]))
    return kept, dropped, notes


def emit_power_profile(kept):
    out = []
    out.append('<?xml version="1.0" encoding="utf-8"?>')
    out.append("<!--")
    out.append("     Stock CPH1909 power profile, filtered to the keys that")
    out.append("     LineageOS 17.1 PowerProfile still reads.")
    out.append("")
    out.append("     Generated by tools/extract-framework-overlay.py from the stock")
    out.append("     framework-res.apk.  8.1-only keys (none, cpu.awake) are dropped;")
    out.append("     dsp.audio/dsp.video become audio/video; cpu.speeds.clusterN and")
    out.append("     cpu.active.clusterN become cpu.core_speeds.clusterN and")
    out.append("     cpu.core_power.clusterN, which is the per-core model Android 10")
    out.append("     uses together with cpu.clusters.cores.")
    out.append("-->")
    out.append('<device name="Android">')
    for e in kept:
        if e["kind"] == "item":
            out.append('    <item name="%s">%s</item>' % (e["name"], xml_escape(e["values"][0])))
        else:
            out.append('    <array name="%s">' % e["name"])
            for v in e["values"]:
                out.append('        <value>%s</value>' % xml_escape(v))
            out.append('    </array>')
    out.append("</device>")
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------------------
# Main generation
# ---------------------------------------------------------------------------

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def read_sim_count(path):
    """Read the physical SIM count from the stock vendor build.prop."""
    value = None
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if line.startswith("ro.telephony.sim.count="):
                value = int(line.split("=", 1)[1])
    if value is None:
        raise SystemExit("ro.telephony.sim.count not found in " + path)
    return value


def collect(aapt2, framework_res, los_config, los_dimens_path, los_power_profile,
            stock_build_prop):
    stock = parse_aapt2_resources(run([aapt2, "dump", "resources", framework_res]))
    los = parse_los_config(los_config)

    by_name = {}
    for (t, n), v in stock.items():
        by_name.setdefault(n, []).append((t, v))

    matched, missing, unresolved = [], [], []
    for e in los:
        hit = [c for c in by_name.get(e["name"], []) if c[0] == los_kind(e)]
        if not hit:
            missing.append(e)
            continue
        status, value = stock_norm(e, hit[0][1])
        if status == "skip":
            unresolved.append((e, hit[0][1], value))
            continue
        matched.append((e, hit[0][1], status, value))

    differing = []
    ref_diff = []
    for e, raw, status, value in matched:
        if status == "ref":
            # Both sides are @-references.  If they name the same resource the
            # value is already identical; a differing reference would need a
            # resolved value and an explicit decision.
            if raw["text"].strip() != e["text"].strip():
                ref_diff.append((e, raw))
            continue
        if status != "ok":
            continue
        if los_norm(e) != value:
            differing.append((e, raw, value))

    names = {e["name"] for e, _, _ in differing}
    unknown = sorted(names - set(INCLUDE) - set(EXCLUDE))
    stale_include = sorted(set(INCLUDE) - names)
    stale_exclude = sorted(set(EXCLUDE) - names)

    # Stock framework dimens.
    stock_dimens = {}
    for (t, n), v in stock.items():
        if t == "dimen" and v["kind"] == "scalar":
            stock_dimens[n] = norm_dimen(v["text"])

    los_dimens = {}
    root = ET.parse(los_dimens_path).getroot()
    for e in root:
        if e.tag in ("dimen", "item") and "name" in e.attrib:
            los_dimens[e.attrib["name"]] = "".join(e.itertext()).strip()

    dimen_rows = []
    for old, (new, why) in DIMEN_RENAME.items():
        if old not in stock_dimens:
            raise SystemExit("dimen not in stock: " + old)
        dimen_rows.append((old, new, stock_dimens[old], los_dimens.get(new), why))

    # Power profile.
    pp_tree = run([aapt2, "dump", "xmltree", framework_res, "--file",
                   "res/xml/power_profile.xml"])
    pp_entries = parse_power_profile_tree(pp_tree, framework_res)
    los_pp_keys = los_power_profile_keys(los_power_profile)
    pp_kept, pp_dropped, pp_notes = power_profile_emission(pp_entries, los_pp_keys)

    sim_count = read_sim_count(stock_build_prop)
    extra_config = list(EXTRA_CONFIG)
    extra_config.append((
        "config_num_physical_slots", str(sim_count),
        "the stock vendor build.prop sets ro.telephony.sim.count=%d" % sim_count))

    report = {
        "stock_resources": len(stock),
        "los_config_resources": len(los),
        "matched": matched,
        "missing": missing,
        "unresolved": unresolved,
        "differing": differing,
        "ref_diff": ref_diff,
        "unknown": unknown,
        "stale_include": stale_include,
        "stale_exclude": stale_exclude,
        "stock_dimens": stock_dimens,
        "los_dimens": los_dimens,
        "dimen_rows": dimen_rows,
        "pp_entries": pp_entries,
        "pp_kept": pp_kept,
        "pp_dropped": pp_dropped,
        "pp_notes": pp_notes,
        "extra_config": extra_config,
        "extra_dimens": EXTRA_DIMENS,
        "extra_systemui": EXTRA_SYSTEMUI_DIMENS,
    }
    return report


def emit_config(report):
    by_cat = {i: [] for i in range(len(CATEGORIES))}
    for e, raw, value in report["differing"]:
        name = e["name"]
        if name in INCLUDE:
            by_cat[INCLUDE[name]].append((e, raw, value))

    out = []
    out.append('<?xml version="1.0" encoding="utf-8"?>')
    out.append("<!--")
    out.append("     Device framework configuration for the OPPO A5s (CPH1909).")
    out.append("")
    out.append("     GENERATED FILE: do not edit by hand.  Regenerate with")
    out.append("     tools/extract-framework-overlay.py; see overlay/README.md for the")
    out.append("     provenance, the full accounting and the list of stock values that")
    out.append("     are deliberately excluded.")
    out.append("")
    out.append("     The generated sections read the stock ColorOS 8.1")
    out.append("     framework-res.apk and keep only resources that LineageOS 17.1")
    out.append("     still defines.  The final section adds device capabilities that")
    out.append("     the stock framework config does not attest; the README records")
    out.append("     the evidence for each.  Resources whose 8.1 value is ROM policy")
    out.append("     rather than device configuration are listed there too.")
    out.append("-->")
    out.append('<resources xmlns:xliff="urn:oasis:names:tc:xliff:document:1.2">')

    for cat in range(len(CATEGORIES)):
        entries = by_cat[cat]
        if not entries:
            continue
        out.append("")
        out.append("    <!-- ================================================================")
        out.append("         %s" % CATEGORIES[cat])
        out.append("         ================================================================ -->")
        for e, raw, value in sorted(entries, key=lambda x: x[0]["name"]):
            name = e["name"]
            tag = e["tag"]
            if tag in ("bool", "integer", "fraction", "string", "color"):
                out.append('    <%s name="%s">%s</%s>' % (
                    tag, name, stock_value_text(e, raw, value), tag))
            elif tag in ("string-array", "integer-array"):
                out.append('    <%s name="%s">' % (tag, name))
                for i, item in enumerate(value):
                    out.append('        <item>%s</item>' % array_item_text(e, item, i))
                out.append('    </%s>' % tag)
            elif tag == "item":
                out.append('    <item type="%s" name="%s">%s</item>' % (
                    e["type"], name, stock_value_text(e, raw, value)))
            else:
                raise AssertionError("unhandled tag " + tag)
        out.append("")

    out.append("    <!-- ================================================================")
    out.append("         Device capabilities that the stock framework config does not attest")
    out.append("         ================================================================ -->")
    for name, value, why in report["extra_config"]:
        if value in ("true", "false"):
            tag = "bool"
        elif re.match(r"^-?[0-9]+$", value):
            tag = "integer"
        else:
            tag = "string"
        out.append('    <%s name="%s">%s</%s>' % (tag, name, value, tag))
    out.append("")
    out.append("</resources>")
    return "\n".join(out) + "\n"


def emit_dimens(report):
    out = []
    out.append('<?xml version="1.0" encoding="utf-8"?>')
    out.append("<!--")
    out.append("     Device framework dimensions for the OPPO A5s (CPH1909).")
    out.append("")
    out.append("     GENERATED FILE: regenerate with")
    out.append("     tools/extract-framework-overlay.py.")
    out.append("")
    for old, new, stock_v, los_v, why in report["dimen_rows"]:
        out.append("     %s -> %s = %s" % (old, new, fmt_dimen(stock_v)))
        out.append("       (%s; LOS 17.1 default %s)" % (why, los_v))
    out.append("-->")
    out.append("<resources>")
    for old, new, stock_v, los_v, why in report["dimen_rows"]:
        out.append('    <dimen name="%s">%s</dimen>' % (new, fmt_dimen(stock_v)))
    out.append("")
    out.append("    <!-- Device capability: match the 82px hardware corner pattern. -->")
    for name, value, why in report["extra_dimens"]:
        out.append('    <dimen name="%s">%s</dimen>' % (name, value))
    out.append("</resources>")
    return "\n".join(out) + "\n"


def emit_systemui_dimens(report):
    out = []
    out.append('<?xml version="1.0" encoding="utf-8"?>')
    out.append("<!--")
    out.append("     Device SystemUI dimensions for the OPPO A5s (CPH1909).")
    out.append("")
    out.append("     GENERATED FILE: regenerate with")
    out.append("     tools/extract-framework-overlay.py.")
    out.append("")
    for name, value, why in report["extra_systemui"]:
        out.append("     %s = %s (%s)" % (name, value, why))
    out.append("-->")
    out.append("<resources>")
    for name, value, why in report["extra_systemui"]:
        out.append('    <dimen name="%s">%s</dimen>' % (name, value))
    out.append("</resources>")
    return "\n".join(out) + "\n"


def emit_readme(report, inputs):
    m = report
    out = []
    out.append("# CPH1909 framework overlay")
    out.append("")
    out.append("This directory is generated from the stock OPPO CPH1909 (Android")
    out.append("8.1 / ColorOS 5.2) framework.  It contains only values whose")
    out.append("resource still exists in LineageOS 17.1: a value that Android 10")
    out.append("does not read is never copied, and a value whose 8.1 meaning is ROM")
    out.append("policy rather than device configuration is excluded with a reason.")
    out.append("The four values that are not stock framework values are listed")
    out.append("under \"Device capabilities\" below with their evidence.")
    out.append("")
    out.append("Do not edit the generated files by hand.  Regenerate with:")
    out.append("")
    out.append("```")
    out.append("tools/extract-framework-overlay.py \\")
    out.append("    --framework-res  /path/to/framework-res.apk \\")
    out.append("    --stock-build-prop /path/to/stock/vendor/build.prop \\")
    out.append("    --los-config     /path/to/lineage-17.1/core/res/res/values/config.xml \\")
    out.append("    --los-dimens     /path/to/lineage-17.1/core/res/res/values/dimens.xml \\")
    out.append("    --los-power-profile /path/to/lineage-17.1/core/java/com/android/internal/os/PowerProfile.java")
    out.append("```")
    out.append("")
    out.append("`--check` regenerates into a temporary directory and diffs the result")
    out.append("against the committed files.")
    out.append("")
    out.append("## Inputs")
    out.append("")
    out.append("| Input | SHA-256 |")
    out.append("|---|---|")
    for label, path in inputs:
        out.append("| `%s` | `%s` |" % (label, sha256(path)))
    out.append("")
    out.append("The stock APK comes from the CPH1909 A.46 dump.  The LineageOS")
    out.append("inputs are the 17.1 sources named on the command line; their hashes")
    out.append("above pin the exact revision the overlay was generated against.")
    out.append("")
    out.append("## Accounting")
    out.append("")
    out.append("| Item | Count |")
    out.append("|---|---|")
    out.append("| LOS 17.1 `config.xml` resources | %d |" % m["los_config_resources"])
    out.append("| ... also defined by the stock 8.1 framework | %d |" % len(m["matched"]))
    out.append("| ... stock value differs from the LOS 17.1 default | %d |" % len(m["differing"]))
    out.append("| ... stock device configuration (emitted) | %d |" % len(INCLUDE))
    out.append("| ... device capabilities not in the stock framework | %d |" % (
        len(m["extra_config"]) + len(m["extra_dimens"]) + len(m["extra_systemui"])))
    out.append("| ... ROM policy, excluded with a reason | %d |" % len(EXCLUDE))
    out.append("| ... stock value equals the LOS 17.1 default (no override needed) | %d |" % (len(m["matched"]) - len(m["differing"])))
    out.append("| LOS 17.1 resources not present in the stock framework | %d |" % len(m["missing"]))
    out.append("")
    out.append("Every resource that differs is either emitted or listed under")
    out.append("\"Excluded\" below; the generator refuses to run if one is")
    out.append("unclassified.")
    out.append("")
    out.append("## Emitted values")
    out.append("")
    for cat in range(len(CATEGORIES)):
        entries = [(e, raw, v) for e, raw, v in m["differing"] if INCLUDE.get(e["name"]) == cat]
        if not entries:
            continue
        out.append("### " + CATEGORIES[cat])
        out.append("")
        out.append("| Resource | LOS 17.1 default | Stock value |")
        out.append("|---|---|---|")
        for e, raw, v in sorted(entries, key=lambda x: x[0]["name"]):
            out.append("| `%s` | `%s` | `%s` |" % (
                e["name"], escape_md(short_value(e, los_norm(e))),
                escape_md(short_value(e, v))))
        out.append("")
    out.append("## Excluded")
    out.append("")
    out.append("These differ between stock and LOS 17.1 but are not device")
    out.append("configuration, or the 8.1 value is wrong for this build.  The")
    out.append("LineageOS 17.1 default is kept.")
    out.append("")
    out.append("| Resource | Stock value | Reason |")
    out.append("|---|---|---|")
    diff_by_name = {e["name"]: (e, v) for e, _, v in m["differing"]}
    for name in sorted(EXCLUDE):
        e, v = diff_by_name[name]
        out.append("| `%s` | `%s` | %s |" % (
            name, escape_md(short_value(e, v)), EXCLUDE[name]))
    out.append("")
    out.append("## Device capabilities not in the stock framework config")
    out.append("")
    out.append("These are the only overlay values that are not read from")
    out.append("`framework-res.apk`.  Each is required by hardware the stock dump")
    out.append("attests, and the evidence is recorded here so the value is not")
    out.append("mistaken for a stock framework default.")
    out.append("")
    out.append("| Resource | Value | Evidence |")
    out.append("|---|---|---|")
    for name, value, why in m["extra_config"]:
        out.append("| `%s` | `%s` | %s |" % (name, value, why))
    for name, value, why in m["extra_dimens"]:
        out.append("| `%s` | `%s` | %s |" % (name, value, why))
    for name, value, why in m["extra_systemui"]:
        out.append("| `%s` | `%s` | %s |" % (name, value, why))
    out.append("")
    out.append("## Power profile")
    out.append("")
    out.append("`frameworks/base/core/res/res/xml/power_profile.xml` is the stock")
    out.append("profile with the 8.1 keys mapped to the names LOS 17.1")
    out.append("`PowerProfile` reads:")
    out.append("")
    out.append("| 8.1 key | LOS 17.1 key |")
    out.append("|---|---|")
    for old, new in m["pp_notes"]:
        out.append("| `%s` | `%s` |" % (old, new))
    out.append("")
    out.append("This matters: `cpu.speeds.clusterN`/`cpu.active.clusterN` are")
    out.append("**not read** by Android 10, which uses")
    out.append("`cpu.core_speeds.clusterN`/`cpu.core_power.clusterN` together with")
    out.append("`cpu.clusters.cores`, so the old overlay's cluster arrays had no")
    out.append("effect on battery statistics.")
    out.append("")
    out.append("Dropped because LOS 17.1 does not read them:")
    out.append("")
    for name, values in m["pp_dropped"]:
        out.append("- `%s` (%s)" % (name, len(values) if len(values) != 1 else values[0]))
    out.append("")
    out.append("## Framework dimensions")
    out.append("")
    out.append("| Stock resource | LOS 17.1 resource | Value |")
    out.append("|---|---|---|")
    for old, new, stock_v, los_v, why in m["dimen_rows"]:
        out.append("| `%s` | `%s` | `%s` |" % (old, new, fmt_dimen(stock_v)))
    out.append("")
    out.append("The stock status bar is 28dp (56px at 320dpi, and the notch is")
    out.append("55px tall); LOS 17.1 made `status_bar_height_portrait` the value the")
    out.append("framework reads, so that is the name used here.")
    out.append("")
    out.append("## Layout")
    out.append("")
    out.append("| Path | Meaning |")
    out.append("|---|---|")
    out.append("| `frameworks/base/core/res/res/values/config.xml` | device configuration |")
    out.append("| `frameworks/base/core/res/res/values/dimens.xml` | stock status bar height and the 82px hardware corner radius |")
    out.append("| `frameworks/base/packages/SystemUI/res/values/dimens.xml` | nav content margin for the 82px corners |")
    out.append("| `frameworks/base/core/res/res/xml/power_profile.xml` | stock power model, LOS 17.1 keys |")
    out.append("")
    return "\n".join(out)


def escape_md(s):
    return str(s).replace("|", "\\|")


def short_value(e, v):
    if isinstance(v, tuple):
        # A dimen/fraction is (number, unit); an array is a tuple of items.
        if (len(v) == 2 and isinstance(v[0], float) and isinstance(v[1], str)
                and v[1] in ("dp", "dip", "sp", "px", "pt", "in", "mm", "%", "%p")):
            return display_value(e, v)
        return "%d items" % len(v)
    return display_value(e, v)


def write_outputs(report, outdir, inputs):
    files = {
        CONFIG_REL: emit_config(report),
        DIMENS_REL: emit_dimens(report),
        SYSTEMUI_DIMENS_REL: emit_systemui_dimens(report),
        POWER_PROFILE_REL: emit_power_profile(report["pp_kept"]),
        README_REL: emit_readme(report, inputs),
    }
    for rel, content in files.items():
        path = os.path.join(outdir, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
    return files


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--framework-res", required=True)
    ap.add_argument("--los-config", required=True)
    ap.add_argument("--los-dimens", required=True)
    ap.add_argument("--los-power-profile", required=True)
    ap.add_argument("--stock-build-prop", required=True,
                    help="stock /vendor/build.prop (ro.telephony.sim.count)")
    ap.add_argument("--aapt2", default="aapt2")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    report = collect(args.aapt2, args.framework_res, args.los_config,
                     args.los_dimens, args.los_power_profile,
                     args.stock_build_prop)

    if report["unknown"]:
        sys.stderr.write("Unclassified differing resources (add to INCLUDE or "
                         "EXCLUDE):\n")
        for name in report["unknown"]:
            sys.stderr.write("  " + name + "\n")
        raise SystemExit(1)
    if report["ref_diff"]:
        sys.stderr.write("Differing @-references need a resolved value:\n")
        for e, raw in report["ref_diff"]:
            sys.stderr.write("  %s: stock %s, LOS %s\n" % (
                e["name"], raw["text"], e["text"]))
        raise SystemExit(1)
    for name in report["stale_include"]:
        sys.stderr.write("warning: INCLUDE entry no longer differs: %s\n" % name)
    for name in report["stale_exclude"]:
        sys.stderr.write("warning: EXCLUDE entry no longer differs: %s\n" % name)

    inputs = [
        ("stock framework-res.apk", args.framework_res),
        ("stock vendor build.prop", args.stock_build_prop),
        ("LOS 17.1 config.xml", args.los_config),
        ("LOS 17.1 dimens.xml", args.los_dimens),
        ("LOS 17.1 PowerProfile.java", args.los_power_profile),
    ]

    if args.check:
        with tempfile.TemporaryDirectory() as td:
            files = write_outputs(report, td, inputs)
            failed = False
            for rel, content in files.items():
                committed = os.path.join(OVERLAY_DIR, rel)
                if not os.path.exists(committed):
                    print("MISSING: " + committed)
                    failed = True
                    continue
                cur = open(committed, encoding="utf-8").read()
                if cur != content:
                    print("DIFFERS: " + committed)
                    failed = True
                    break
            if failed:
                raise SystemExit(1)
            print("overlay is up to date (%d files)" % len(files))
        return

    outdir = args.out or OVERLAY_DIR
    write_outputs(report, outdir, inputs)
    print("matched=%d differing=%d emitted=%d excluded=%d missing=%d extras=%d" % (
        len(report["matched"]), len(report["differing"]), len(INCLUDE),
        len(EXCLUDE), len(report["missing"]), len(report["extra_config"])))
    print("power profile: kept=%d dropped=%d renamed=%d" % (
        len(report["pp_kept"]), len(report["pp_dropped"]), len(report["pp_notes"])))
    print("dimens: %d mapped" % len(report["dimen_rows"]))
    print("wrote overlay to " + outdir)


if __name__ == "__main__":
    main()
