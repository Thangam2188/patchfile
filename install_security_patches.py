#!/usr/bin/env python3

import os
import subprocess
import sys
from datetime import datetime

LOG_FILE = "/usr/bin/patchscript/patch_install_log.txt"

def log(message):
    timestamp = datetime.now().strftime("[%Y-%m-%d %H:%M:%S]")
    with open(LOG_FILE, "a") as log_file:
        log_file.write(f"{timestamp} {message}\n")

def get_instance_id():
    try:
        result = subprocess.check_output(
            ["curl", "-s", "http://169.254.169.254/latest/meta-data/instance-id"]
        )
        return result.decode().strip()
    except subprocess.CalledProcessError:
        log("[ERROR] Failed to fetch instance ID.")
        sys.exit(1)

def get_package_manager():
    for cmd in ["dnf", "yum", "apt-get"]:
        if subprocess.call(["which", cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0:
            return cmd
    log("[ERROR] No supported package manager found (dnf, yum, apt-get).")
    sys.exit(1)

def read_patch_file(file_path):
    try:
        with open(file_path, "r") as f:
            lines = f.readlines()
        packages = []
        for line in lines:
            cleaned = line.strip()
            if cleaned and not cleaned.startswith("=") and not cleaned.isdigit():
                packages.append(cleaned)
        return packages
    except FileNotFoundError:
        log(f"[ERROR] Patch file not found: {file_path}")
        sys.exit(1)

def install_packages(package_manager, packages):
    if not packages:
        log("[INFO] No valid packages found to install.")
        return

    log("[INFO] Installing packages:")
    for pkg in packages:
        log(f"- {pkg}")

    try:
        subprocess.run(
            [package_manager, "install", "-y"] + packages,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        log("[INFO] Package installation completed successfully.")
    except subprocess.CalledProcessError as e:
        log(f"[ERROR] Installation failed: {e}")
        if e.stdout:
            log(e.stdout.decode())
        if e.stderr:
            log(e.stderr.decode())
        sys.exit(1)

def main():
    log("=== Starting patch install for instance: {} ===".format(get_instance_id()))
    instance_id = get_instance_id()
    patch_file = f"/usr/bin/patchscript/{instance_id}_patches.txt"
    log(f"Reading patch file: {patch_file}")
    package_manager = get_package_manager()
    log(f"Using package manager: {package_manager}")

    packages = read_patch_file(patch_file)
    install_packages(package_manager, packages)

if __name__ == "__main__":
    main()
