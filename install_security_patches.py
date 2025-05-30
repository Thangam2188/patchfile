#!/usr/bin/env python3

import subprocess
import sys
import os
from datetime import datetime

def log(message):
    timestamp = datetime.now().strftime("[%Y-%m-%d %H:%M:%S]")
    with open(LOG_FILE, "a") as f:
        f.write(f"{timestamp} {message}\n")
    print(f"{timestamp} {message}")

# Validate arguments
if len(sys.argv) != 2:
    print("Usage: install_security_patches.py <instance-id>")
    sys.exit(1)

INSTANCE_ID = sys.argv[1]
PATCH_DIR = "/usr/bin/patchscript"
PATCH_FILE = os.path.join(PATCH_DIR, f"{INSTANCE_ID}_patches.txt")
LOG_FILE = os.path.join(PATCH_DIR, "patch_install_log.txt")

log(f"=== Starting patch install for instance: {INSTANCE_ID} ===")
log(f"Reading patch file: {PATCH_FILE}")

if not os.path.exists(PATCH_FILE):
    log(f"[WARN] Patch file not found: {PATCH_FILE}")
    sys.exit(0)

# Extract valid package names
valid_packages = []
with open(PATCH_FILE, "r") as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith("=") or line.split()[0].isdigit():
            continue  # Skip header or malformed lines
        parts = line.split()
        if len(parts) > 2:
            pkg = parts[-1]
            if "-" in pkg:  # crude filter to only include real packages
                valid_packages.append(pkg)

if not valid_packages:
    log("[INFO] No valid packages found to install.")
    sys.exit(0)

log("[INFO] Installing packages:")
for pkg in valid_packages:
    log(f"- {pkg}")

try:
    result = subprocess.run(
        ["dnf", "--disablerepo=docker-ce-stable-debuginfo", "install", "-y"] + valid_packages,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    log(result.stdout.decode())
    log("[SUCCESS] Installation completed successfully.")
except subprocess.CalledProcessError as e:
    log(f"[ERROR] Installation failed: {e}")
    if e.stdout:
        log(e.stdout.decode())
    if e.stderr:
        log(e.stderr.decode())
    sys.exit(1)
