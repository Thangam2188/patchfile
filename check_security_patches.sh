#!/bin/bash

OUTPUT_FILE="/usr/bin/instance_patches.txt"
sudo touch "$OUTPUT_FILE"
sudo chmod 644 "$OUTPUT_FILE"

echo "=== Security Patches Report ===" > "$OUTPUT_FILE"
echo "Generated at: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

if command -v dnf &> /dev/null; then
    echo "Using dnf..." >> "$OUTPUT_FILE"
    sudo dnf --disablerepo=docker-ce-stable-debuginfo updateinfo list security all | grep -E 'Critical|Important' >> "$OUTPUT_FILE"
elif command -v yum &> /dev/null; then
    echo "Using yum..." >> "$OUTPUT_FILE"
    sudo yum --disablerepo=docker-ce-stable-debuginfo updateinfo list security all | grep -E 'Critical|Important' >> "$OUTPUT_FILE"
else
    echo "Error: Neither dnf nor yum found." >> "$OUTPUT_FILE"
    exit 1
fi

echo "" >> "$OUTPUT_FILE"
echo "Security patch check completed."
