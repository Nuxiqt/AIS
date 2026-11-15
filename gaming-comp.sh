#!/usr/bin/env bash

# Gaming Compatibility Tweaks Script
# Applies SteamOS-style kernel tweaks that are still relevant on current Arch
# Based on arch wiki - https://wiki.archlinux.org/title/Gaming
# and https://github.com/AdelKS/LinuxGamingGuide
# Run with: sudo bash gaming-comp.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo "================================================"
    echo "$1"
    echo "================================================"
}

print_status() {
    echo -e "${GREEN}[*]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1" >&2
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root"
    exit 1
fi

print_header "SteamOS-style Gaming Compatibility Tweaks"

# Remove tweaks from older versions of this script that are no longer needed:
#  - 80-inotify.conf: Arch already sets sane inotify limits (10-arch.conf)
#  - 80-shm.conf: kernel shm defaults are already near unlimited; old values lowered them
#  - 99-gaming.conf: nofile limits were for esync, superseded by ntsync; systemd sets hard limit 524288
for obsolete in \
    /etc/sysctl.d/80-inotify.conf \
    /etc/sysctl.d/80-shm.conf \
    /etc/security/limits.d/99-gaming.conf; do
    if [ -f "$obsolete" ]; then
        print_status "Removing obsolete tweak: $obsolete"
        rm -f "$obsolete"
    fi
done

# Split-lock mitigation (SteamOS default; some Wine/Proton games slow down heavily with it on)
print_status "Disabling kernel split-lock mitigation..."
cat > /etc/sysctl.d/75-kernelsplitlock.conf << 'EOF'
kernel.split_lock_mitigate = 0
EOF

# Swappiness (avoid swapping unless memory is actually full)
print_status "Setting swappiness..."
cat > /etc/sysctl.d/80-swappiness.conf << 'EOF'
vm.swappiness = 10
EOF

# Transparent Huge Pages (Arch kernel defaults to "always")
print_status "Setting Transparent Huge Pages to madvise..."
cat > /etc/tmpfiles.d/thp.conf << 'EOF'
w /sys/kernel/mm/transparent_hugepage/enabled - - - - madvise
w /sys/kernel/mm/transparent_hugepage/defrag - - - - madvise
EOF

# vm.max_map_count (optional: Arch default 1048576 is sufficient for current games)
echo ""
echo "Arch already sets vm.max_map_count to 1048576, which is enough for current games."
read -r -p "Raise it to the SteamOS value 2147483642 anyway? [y/N]: " map_choice
case "$map_choice" in
    y|Y)
        print_status "Setting vm.max_map_count to SteamOS value..."
        cat > /etc/sysctl.d/80-gamecompatibility.conf << 'EOF'
vm.max_map_count = 2147483642
EOF
        ;;
    *)
        if [ -f /etc/sysctl.d/80-gamecompatibility.conf ]; then
            print_status "Removing custom vm.max_map_count, using Arch default"
            rm -f /etc/sysctl.d/80-gamecompatibility.conf
        else
            print_status "Keeping Arch default vm.max_map_count"
        fi
        ;;
esac

# Apply sysctl and tmpfiles immediately
print_status "Applying sysctl settings..."
sysctl --system &>/dev/null
print_status "Applying Transparent Huge Pages settings..."
systemd-tmpfiles --create /etc/tmpfiles.d/thp.conf

echo ""
print_header "Tweaks applied!"
echo ""
echo "Applied tweaks:"
echo "  - kernel.split_lock_mitigate = 0"
echo "  - vm.swappiness = 10"
echo "  - Transparent Huge Pages: madvise"
echo "  - vm.max_map_count: $(sysctl -n vm.max_map_count)"
echo ""
print_warning "IMPORTANT: Reboot to fully reset removed tweaks to their defaults!"
echo ""
