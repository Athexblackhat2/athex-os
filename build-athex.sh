#!/usr/bin/env bash
#
# ATHEX OS build script
# Run this INSIDE a Kali Linux VM (VMware Workstation) with internet access.
# Produces: athex-os-<date>.iso  ->  copy it out and boot it in a NEW VMware VM.
#
# Usage:
#   sudo ./build-athex.sh
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[!] Run this as root: sudo ./build-athex.sh"
  exit 1
fi

BUILD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BUILD_DIR"

echo "=== [1/6] Installing build dependencies ==="
# VMware NAT networks often have no working IPv6 route, which makes apt hang/fail
# when a mirror's hostname resolves to an AAAA record. Force IPv4 to avoid that.
echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4
apt-get update
apt-get install -y live-build live-config live-boot debootstrap git imagemagick \
                    syslinux-utils fonts-dejavu-core

echo "=== [2/6] Configuring live-build (Kali rolling, Debian live-build engine) ==="
rm -rf config .build 2>/dev/null || true
lb config \
  --distribution kali-rolling \
  --archive-areas "main contrib non-free non-free-firmware" \
  --parent-distribution kali-rolling \
  --parent-archive-areas "main contrib non-free non-free-firmware" \
  --mirror-bootstrap http://http.kali.org/kali \
  --mirror-chroot http://http.kali.org/kali \
  --mirror-binary http://http.kali.org/kali \
  --parent-mirror-bootstrap http://http.kali.org/kali \
  --parent-mirror-chroot http://http.kali.org/kali \
  --parent-mirror-binary http://http.kali.org/kali \
  --apt-recommends false \
  --security false \
  --updates false \
  --debian-installer false \
  --binary-images iso-hybrid \
  --iso-application "ATHEX OS" \
  --iso-volume "ATHEX_OS" \
  --iso-publisher "ATHEX" \
  --linux-flavours amd64 \
  --bootappend-live "boot=live components quiet splash"

# Re-create the dirs this script needs inside config/ (lb config wipes them)
mkdir -p config/includes.chroot/etc
mkdir -p config/includes.chroot/usr/local/bin
mkdir -p config/includes.chroot/usr/share/backgrounds/athex
mkdir -p config/includes.chroot/usr/share/plymouth/themes/athex
mkdir -p config/includes.chroot/etc/plymouth
mkdir -p config/package-lists
mkdir -p config/hooks/live
mkdir -p config/includes.chroot/etc/apt/apt.conf.d
echo 'Acquire::ForceIPv4 "true";' > config/includes.chroot/etc/apt/apt.conf.d/99force-ipv4
mkdir -p config/archives

echo "=== [3/6] Copying ATHEX branding files into chroot ==="
cp -r "$BUILD_DIR"/branding/etc/*            config/includes.chroot/etc/ 2>/dev/null || true
cp -r "$BUILD_DIR"/branding/usr/*            config/includes.chroot/usr/ 2>/dev/null || true
cp "$BUILD_DIR"/hooks/*.hook.chroot          config/hooks/live/ 2>/dev/null || true
chmod +x config/hooks/live/*.hook.chroot 2>/dev/null || true
chmod +x config/includes.chroot/usr/local/bin/* 2>/dev/null || true

echo "=== [4/6] Kali tool meta-packages + generic pentest toolkit ==="
cat > config/package-lists/athex.list.chroot <<'EOF'
# --- Desktop / base ---
kali-desktop-xfce
kali-linux-core
network-manager
network-manager-applet
plymouth
plymouth-themes
xfce4-goodies
lightdm
firefox-esr

# --- Generic pentest toolkit (preinstalled) ---
nmap
wireshark
metasploit-framework
hydra
john
sqlmap
gobuster
nikto
aircrack-ng
netcat-traditional
tcpdump
hashcat
burpsuite
whois
dnsutils
EOF

echo "=== [5/6] Building the ISO (this takes 30-90+ min, needs ~15GB free disk) ==="
lb build 2>&1 | tee build.log

ISO_NAME="athex-os-$(date +%Y%m%d).iso"
mv -f live-image-amd64.hybrid.iso "$ISO_NAME" 2>/dev/null || \
mv -f *.hybrid.iso "$ISO_NAME" 2>/dev/null || true

echo "=== [6/6] Done ==="
echo "ISO built: $BUILD_DIR/$ISO_NAME"
echo "Copy this .iso to your Windows/Mac host (shared folder, scp, or USB),"
echo "then in VMware Workstation: New VM -> Installer disc image (iso) -> point to this file."
