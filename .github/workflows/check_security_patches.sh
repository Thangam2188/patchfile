#!/bin/bash

INSTANCE_ID="$1"
PATCH_DIR="/usr/bin/patchscript"
OUTPUT_FILE="${PATCH_DIR}/${INSTANCE_ID}_patches.txt"

mkdir -p "$PATCH_DIR"

echo "[INFO] === Starting Security Patch Check ===" > "$OUTPUT_FILE"
echo "[INFO] Timestamp: $(date)" >> "$OUTPUT_FILE"
echo "[INFO] Using package manager: dnf" >> "$OUTPUT_FILE"

# Fetch only Critical and Important security updates, excluding docker-ce-stable-debuginfo
SEC_UPDATES=$(sudo dnf --disablerepo=docker-ce-stable-debuginfo updateinfo list security all 2>/dev/null | grep -E 'Critical|Important')

if [[ -z "$SEC_UPDATES" ]]; then
    echo "[INFO] No critical or important security updates found." >> "$OUTPUT_FILE"
    exit 0
fi

echo "[INFO] Available Critical/Important security updates:" >> "$OUTPUT_FILE"
echo "$SEC_UPDATES" >> "$OUTPUT_FILE"

# Append package names to the same file
echo "$SEC_UPDATES" | awk '{print $3}' | grep -v '^$' | sort | uniq >> "$OUTPUT_FILE"
echo "[INFO] Package list appended to: $OUTPUT_FILE"
