#!/bin/bash

INSTANCE_ID="$1"
PATCH_DIR="/usr/bin/patchscript"
PATCH_FILE="${PATCH_DIR}/${INSTANCE_ID}_patches.txt"
INSTALL_LOG="${PATCH_DIR}/patch_install_log.txt"

echo "[INFO] === Starting Patch Installation ===" >> "$INSTALL_LOG"
echo "[INFO] Timestamp: $(date)" >> "$INSTALL_LOG"
echo "[INFO] Using package manager: dnf" >> "$INSTALL_LOG"

if [[ ! -s "$PATCH_FILE" ]]; then
    echo "[WARN] Patch file not found or empty: $PATCH_FILE" >> "$INSTALL_LOG"
    exit 0
fi

# Extract package names from the tail end of the patch file
PKG_LIST=$(awk '/Available Critical\/Important security updates:/,0' "$PATCH_FILE" | awk '{print $1}' | grep -v 'Available' | grep -v '^$' | sort | uniq)

if [[ -z "$PKG_LIST" ]]; then
    echo "[WARN] No valid package names found in patch file: $PATCH_FILE" >> "$INSTALL_LOG"
    exit 0
fi

echo "[INFO] Packages to install:" >> "$INSTALL_LOG"
echo "$PKG_LIST" >> "$INSTALL_LOG"

dnf install -y $PKG_LIST >> "$INSTALL_LOG" 2>&1

STATUS=$?
if [[ $STATUS -eq 0 ]]; then
    echo "[SUCCESS] Patch installation completed successfully." >> "$INSTALL_LOG"
else
    echo "[ERROR] Patch installation failed with exit code $STATUS." >> "$INSTALL_LOG"
    exit $STATUS
fi
