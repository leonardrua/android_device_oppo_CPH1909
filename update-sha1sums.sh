#!/bin/bash
#
# Copyright (C) 2017 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
# Refresh (or add) the SHA-1 pins in proprietary-files.txt.
#
#   ./update-sha1sums.sh          refresh existing "path|sha1" pins
#   ./update-sha1sums.sh --add    also pin every entry that has no sha1 yet
#
# A pin is optional: extract_utils.sh strips "|sha1" before using the path, so
# an unpinned list still extracts normally. Pins only add an early failure when
# a blob is stale or corrupted.
#
# Paths are read line by line and quoted, so entries containing spaces work.
# Comments, blank lines and (unless --add) unpinned entries are preserved
# verbatim. The file is rewritten atomically.

set -e

MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILENAME="${MY_DIR}/proprietary-files.txt"
VENDOR="${MY_DIR}/../../../vendor/oppo/CPH1909/proprietary"

ADD_PINS=false
case "${1:-}" in
    --add|-a) ADD_PINS=true ;;
    "")       ;;
    *)        echo "usage: $0 [--add]" >&2; exit 2 ;;
esac

if [ ! -f "${FILENAME}" ]; then
    echo "error: ${FILENAME} not found" >&2
    exit 1
fi

tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT

while IFS= read -r line || [ -n "${line}" ]; do
    # Preserve comments and blank lines exactly as they are.
    if [[ "${line}" =~ ^[[:space:]]*# ]] || [[ -z "${line//[[:space:]]/}" ]]; then
        printf '%s\n' "${line}"
        continue
    fi

    has_pin=false
    if [[ "${line}" == *"|"* ]]; then
        has_pin=true
    fi

    if ! ${has_pin} && ! ${ADD_PINS}; then
        printf '%s\n' "${line}"
        continue
    fi

    blob="${line%%|*}"
    prefix="${blob}"          # keep the optional leading '-' marker
    blob="${blob#-}"

    if [ ! -f "${VENDOR}/${blob}" ]; then
        echo "warning: ${VENDOR}/${blob} not found; keeping line unchanged" >&2
        printf '%s\n' "${line}"
        continue
    fi

    sha="$(sha1sum -- "${VENDOR}/${blob}" | cut -d' ' -f1)"
    printf '%s|%s\n' "${prefix}" "${sha}"
done < "${FILENAME}" > "${tmp}"

# Only replace the list when something actually changed.
if cmp -s "${FILENAME}" "${tmp}"; then
    if ${ADD_PINS}; then
        echo "No changes: every entry is already pinned."
    else
        echo "No SHA-1 pins to refresh (use --add to pin every entry)."
    fi
    rm -f "${tmp}"
    trap - EXIT
    exit 0
fi

mv -- "${tmp}" "${FILENAME}"
trap - EXIT
echo "Updated ${FILENAME}."
