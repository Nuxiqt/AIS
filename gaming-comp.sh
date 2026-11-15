#!/usr/bin/env bash

# Gaming Compatibility Tweaks Script
# Applies SteamOS-style sysctl/limits tweaks
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

# vm.max_map_count
print_status "Setting vm.max_map_count..."
cat > /etc/sysctl.d/80-gamecompatibility.conf << 'EOF'
vm.max_map_count = 2147483642
EOF

# Inotify limits
print_status "Setting inotify limits..."
cat > /etc/sysctl.d/80-inotify.conf << 'EOF'
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
EOF

# Shared memory
print_status "Setting shared memory limits..."
cat > /etc/sysctl.d/80-shm.conf << 'EOF'
kernel.shmmni = 8192
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
EOF

# Swappiness
print_status "Setting swappiness..."
cat > /etc/sysctl.d/80-swappiness.conf << 'EOF'
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF

# File descriptor limits
print_status "Setting file descriptor limits..."
cat > /etc/security/limits.d/99-gaming.conf << 'EOF'
* soft nofile 1048576
* hard nofile 1048576
EOF

# Transparent Huge Pages
print_status "Configuring Transparent Huge Pages..."
cat > /etc/tmpfiles.d/thp.conf << 'EOF'
w /sys/kernel/mm/transparent_hugepage/enabled - - - - madvise
w /sys/kernel/mm/transparent_hugepage/defrag - - - - madvise
EOF

# Apply sysctl immediately
print_status "Applying sysctl settings..."
sysctl --system

echo ""
print_header "Tweaks applied!"
echo ""
print_warning "IMPORTANT: Reboot recommended for full effect!"
echo ""
