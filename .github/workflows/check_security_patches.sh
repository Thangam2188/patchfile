#!/bin/bash

# Check for critical and important security patches
echo "Checking for critical and important security patches..."

# Use yum or dnf depending on availability
if command -v yum &> /dev/null; then
    sudo yum updateinfo list security | grep -E 'Critical|Important'
elif command -v dnf &> /dev/null; then
    sudo dnf updateinfo list security | grep -E 'Critical|Important'
else
    echo "Neither yum nor dnf are installed."
    exit 1
fi
