#!/usr/bin/env python3

import os
import subprocess
from datetime import datetime

PATCH_DIR = "/usr/bin/patchscript"
PATCH_LOG = os.path.join(PATCH_DIR, "patch_install_log.txt")

def log(msg):
    with open(PATCH_LOG, "a") as f:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        f.write(f"[{timestamp}] {msg}\n")
    print(msg)

def detect_package_manager():
    if os.path.exists("/usr/bin/dnf"):
        return "dnf"
    elif os.path.exists("/usr/bin/yum"):
        return "yum"
    else:
        return None

def parse_patch_file():
    files = [f for f in os.listdir(PATCH_DIR) if f.endswith("_patches.txt")]
    if not files:
        log("No patch file found.")
        return []

    patch_file = os.path.join(PATCH_DIR, files[0])
    with open(patch_file, "r") as f:
        lines = f.readlines()

    packages = []
    for line in lines:
        tokens = line.strip().split()
        for token in tokens:
            if token.endswith(".x86_64") or token.endswith(".noarch"):
                pkg = token.split(":")[-1]
                packages.append(pkg)
                break
    return packages

def install_patches(pkg_mgr, packages):
    if not packages:
        log("No packages to install.")
        return

    for pkg in packages:
        log(f"Installing: {pkg}")
        try:
            result = subprocess.run(
                ["sudo", pkg_mgr, "-y", "install", pkg],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            if result.returncode == 0:
                log(f"✅ Success: {pkg}")
            else:
                log(f"❌ Failed: {pkg}")
                log(result.stderr)
        except Exception as e:
            log(f"❌ Exception while installing {pkg}: {e}")

def main():
    log("=== Starting Patch Installation ===")

    pkg_mgr = detect_package_manager()
    if not pkg_mgr:
        log("ERROR: No package manager found (dnf or yum).")
        return

    log(f"Using package manager: {pkg_mgr}")

    packages = parse_patch_file()
    if not packages:
        log("No valid packages found in the patch file.")
        return

    install_patches(pkg_mgr, packages)
    log("=== Patch Installation Completed ===")

if __name__ == "__main__":
    main()
