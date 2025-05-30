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

# Accept instance ID as an argument
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

# Read and parse packages
with open(PATCH_FILE, "r") as f:
    lines = f.readlines()

packages = []
for line in lines:
    parts = line.strip().split()
    if len(parts) > 2:
        pkg = parts[-1]
        packages.append(pkg)

if not packages:
    log("[INFO] No packages found to install.")
    sys.exit(0)

log("[INFO] Installing packages:")
for pkg in packages:
    log(f"- {pkg}")

try:
    result = subprocess.run(
        ["dnf", "--disablerepo=docker-ce-stable-debuginfo", "install", "-y"] + packages,
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
