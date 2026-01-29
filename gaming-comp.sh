#!/usr/bin/env bash
# Based on arch wiki - https://wiki.archlinux.org/title/Gaming
# and https://github.com/AdelKS/LinuxGamingGuide
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Run as root"
  exit 1
fi

echo "== Applying SteamOS-style gaming compatibility tweaks =="

# --- vm.max_map_count ---
cat <<EOF > /etc/sysctl.d/80-gamecompatibility.conf
vm.max_map_count = 2147483642
EOF

# --- Inotify limits ---
cat <<EOF > /etc/sysctl.d/80-inotify.conf
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
EOF

# --- Shared memory ---
cat <<EOF > /etc/sysctl.d/80-shm.conf
kernel.shmmni = 8192
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
EOF

# --- Swappiness ---
cat <<EOF > /etc/sysctl.d/80-swappiness.conf
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF

# --- File descriptor limits ---
cat <<EOF > /etc/security/limits.d/99-gaming.conf
* soft nofile 1048576
* hard nofile 1048576
EOF

# --- Transparent Huge Pages ---
cat <<EOF > /etc/tmpfiles.d/thp.conf
w /sys/kernel/mm/transparent_hugepage/enabled - - - - madvise
w /sys/kernel/mm/transparent_hugepage/defrag - - - - madvise
EOF

# --- Apply sysctl immediately ---
sysctl --system

echo "== Done. Reboot recommended for full effect =="
