#!/usr/bin/env python3
import os
import subprocess
import sys

def run_cmd(cmd):
    print(f"[+] Running: {cmd}")
    result = subprocess.run(cmd, shell=True)
    if result.returncode != 0:
        print(f"[-] Error executing: {cmd}")
        sys.exit(1)

def check_root():
    if os.geteuid() != 0:
        print("[-] Please run this script with sudo / root privileges!")
        sys.exit(1)

def main():
    check_root()
    
    print("=== ATHEX OS BUILDER ===")
    print("[*] Updating system and installing dependencies...")
    run_cmd("apt update && apt install -y live-build debootstrap squashfs-tools xorriso wget curl")

    # Workspace directory
    workspace = "athex_os_build"
    if not os.path.exists(workspace):
        os.makedirs(workspace)
    os.chdir(workspace)

    print("[*] Initializing live-build configuration...")
    # Configure for Kali/Debian rolling architecture
    run_cmd("lb clean")
    lb_config_cmd = (
        "lb config "
        "--distribution kali-rolling "
        "--archive-areas \"main contrib non-free non-free-firmware\" "
        "--parent-distribution kali-rolling "
        "--architectures amd64 "
        "--linux-flavours amd64 "
        "--binary-images iso"
    )
    run_cmd(lb_config_cmd)

    # Create package list directory
    os.makedirs("config/package-lists", exist_ok=True)
    
    print("[*] Writing package list (Penetration testing tools, Tor, VS Code dependencies)...")
    packages = """
# Desktop Environment & Essentials
kali-desktop-xfce
kali-defaults
network-manager
net-tools
sudo
git
python3
python3-pip

# Security & Anonymity
tor
torbrowser-launcher
proxychains4
macchanger
wireshark
nmap
metasploit-framework
sqlmap
aircrack-ng

# Development
code
build-essential
"""
    with open("config/package-lists/athex.list.chroot", "w") as f:
        f.write(packages.strip())

    # Create hooks directory for custom configurations (Logos, Terminals, Branding)
    os.makedirs("config/hooks/normal", exist_ok=True)
    
    print("[*] Creating customization hook script...")
    hook_script = """#!/bin/sh
set -e

# 1. Set Custom OS Name in os-release
echo "Setting Athex OS branding..."
cat << 'EOF' > /etc/os-release
NAME="Athex OS"
VERSION="1.0 (Cyberpunk Edition)"
ID=athex
ID_LIKE=kali
PRETTY_NAME="Athex OS 1.0"
ANSI_COLOR="1;31"
HOME_URL="https://athexithouse.site.je"
SUPPORT_URL="https://athexithouse.site.je"
BUG_REPORT_URL="https://athexithouse.site.je"
EOF

# 2. Configure Dual Terminals (Normal & Root Terminals shortcuts/aliases)
echo "Configuring Normal and Root terminals..."
echo "alias root-term='sudo -i'" >> /etc/skel/.bashrc
echo "alias athex-banner='echo -e \"\\e[31m===================================\\n     ATHEX OS - ROOT TERMINAL      \\n===================================\\e[0m\"'" >> /root/.bashrc

# 3. Install VS Code manually via .deb if repo needs extra setup
echo "Preparing VS Code..."
wget -qO /tmp/vscode.deb https://update.code.visualstudio.com/latest/linux-deb-x64/stable || true
dpkg -i /tmp/vscode.deb || apt-get install -f -y || true
rm -f /tmp/vscode.deb

echo "Athex OS customization hook completed successfully!"
"""
    
    hook_path = "config/hooks/normal/99-athex-customization.hook.chroot"
    with open(hook_path, "w") as f:
        f.write(hook_script)
    run_cmd(f"chmod +x {hook_path}")

    print("[*] Starting ISO Build Process (This may take 20-40 minutes depending on your internet and PC speed)...")
    run_cmd("lb build")

    print("\n[+] SUCCESS! Your Athex OS ISO has been built successfully.")
    print("[+] Check the current directory for the generated .iso file.")

if _name_ == "_main_":
    main()
