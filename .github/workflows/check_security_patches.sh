#!/bin/bash

OUTPUT_FILE="/usr/bin/security_patches.txt"

# Create or clear the file
sudo touch "$OUTPUT_FILE"
sudo chmod 644 "$OUTPUT_FILE"
echo "Security patch summary generated on $(date)" > "$OUTPUT_FILE"
echo "------------------------------------------" >> "$OUTPUT_FILE"

# Check for DNF or YUM and run appropriate command with repo disabled
if command -v dnf &>/dev/null; then
    echo "Using dnf to check for critical and important security updates..." >> "$OUTPUT_FILE"
    sudo dnf --disablerepo=docker-ce-stable-debuginfo updateinfo list security all 2>>"$OUTPUT_FILE" | \
    grep -E 'Critical|Important' >> "$OUTPUT_FILE"
elif command -v yum &>/dev/null; then
    echo "Using yum to check for critical and important security updates..." >> "$OUTPUT_FILE"
    sudo yum --disablerepo=docker-ce-stable-debuginfo updateinfo list security all 2>>"$OUTPUT_FILE" | \
    grep -E 'Critical|Important' >> "$OUTPUT_FILE"
else
    echo "Error: Neither dnf nor yum found. Cannot proceed." >> "$OUTPUT_FILE"
fi

echo "✅ Security patch check complete. Results saved in $OUTPUT_FILE"
