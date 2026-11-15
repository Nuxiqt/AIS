#!/usr/bin/env bash

# GPU Control Setup Script
# Installs LACT (Linux GPU Configuration Tool) for fan curves, power limits,
# clocks and undervolting; on AMD GPUs also installs amdgpu_top and can unlock
# overclocking (amdgpu overdrive / ppfeaturemask)
# Every system change is confirmed first; files are backed up before changes
# Run with: bash install-gpu-control.sh           (install)
#           bash install-gpu-control.sh --revert  (disable LACT, remove overdrive unlock)

set -euo pipefail

OVERDRIVE_CONF="/etc/modprobe.d/99-amdgpu-overdrive.conf"
OVERDRIVE_MASK="0xffffffff"
LACT_CONFIG="/etc/lact/config.yaml"
BACKUP_DIR="$HOME/.local/share/ais-backups/gpu-control-$(date +%Y%m%d-%H%M%S)"

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

# Ask a yes/no question, default No
confirm() {
    local answer
    read -r -p "$1 [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

# Copy a file into BACKUP_DIR, keeping its full path
backup_path() {
    local path="$1"
    local dest="$BACKUP_DIR$(dirname "$path")"
    mkdir -p "$dest"
    sudo cp -a "$path" "$dest/"
    sudo chown -R "$(id -u):$(id -g)" "$dest/$(basename "$path")"
    print_status "Backed up $path"
}

# Rebuild the initramfs so modprobe.d changes apply when amdgpu loads early (kms hook)
regenerate_initramfs() {
    if command -v mkinitcpio &>/dev/null; then
        print_status "Regenerating initramfs (mkinitcpio -P)..."
        sudo mkinitcpio -P
    elif command -v dracut &>/dev/null; then
        print_status "Regenerating initramfs (dracut)..."
        sudo dracut --regenerate-all --force
    elif command -v booster &>/dev/null; then
        print_status "Regenerating initramfs (booster)..."
        sudo /usr/lib/booster/regenerate_images
    else
        print_warning "No known initramfs generator found, regenerate it manually"
    fi
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root"
    exit 1
fi

# Only look at display controllers, so AMD/Intel chipsets and CPUs don't count as GPUs
gpu_list=$(lspci | grep -iE 'vga|3d|display' || true)
has_amd=false
if echo "$gpu_list" | grep -qiE 'amd|radeon'; then
    has_amd=true
fi

install_lact() {
    echo ""
    print_status "LACT: fan curves, power limits, clocks/voltage and monitoring (AMD, NVIDIA, Intel)"

    if pacman -Q lact &>/dev/null; then
        print_status "LACT already installed: $(pacman -Q lact)"
    elif confirm "Install LACT?"; then
        sudo pacman -S --needed --noconfirm lact
    else
        print_warning "Skipping LACT"
        return 0
    fi

    if systemctl is-enabled --quiet lactd 2>/dev/null; then
        print_status "lactd service already enabled"
    elif confirm "Enable and start the lactd service (applies GPU settings at boot)?"; then
        sudo systemctl enable --now lactd
        print_status "lactd service enabled"
    else
        print_warning "lactd not enabled; the LACT GUI needs it to change settings"
    fi

    # LACT only lets members of its admin group change settings (wheel by default)
    local admin_group="wheel"
    if [ -f "$LACT_CONFIG" ]; then
        admin_group=$(awk '/admin_group:/ { print $2; exit }' "$LACT_CONFIG")
        admin_group=${admin_group:-wheel}
    fi
    if ! id -nG | tr ' ' '\n' | grep -qx "$admin_group"; then
        print_warning "$USER is not in the '$admin_group' group, so LACT can't change settings"
        if confirm "Add $USER to '$admin_group'?"; then
            sudo usermod -aG "$admin_group" "$USER"
            print_warning "Log out and back in for the group change to take effect"
        fi
    fi
}

install_amd_tools() {
    echo ""
    print_status "amdgpu_top: detailed AMD GPU usage, clocks, power and temperature monitor"
    if pacman -Q amdgpu_top &>/dev/null; then
        print_status "amdgpu_top already installed: $(pacman -Q amdgpu_top)"
    elif confirm "Install amdgpu_top?"; then
        sudo pacman -S --needed --noconfirm amdgpu_top
    else
        print_warning "Skipping amdgpu_top"
    fi
}

overdrive_enabled() {
    local current
    current=$(cat /sys/module/amdgpu/parameters/ppfeaturemask 2>/dev/null || echo 0)
    # Overdrive is bit 14 (0x4000) of ppfeaturemask
    [ $(( current & 0x4000 )) -ne 0 ]
}

enable_overdrive() {
    echo ""
    print_status "AMD overclocking unlock (amdgpu overdrive via ppfeaturemask=$OVERDRIVE_MASK)"
    echo "  Needed for LACT to change clocks, voltage offset (undervolt) and some power limits."

    if overdrive_enabled; then
        print_status "Overdrive already enabled in the running kernel"
        if grep -qo 'amdgpu.ppfeaturemask=[^ ]*' /proc/cmdline; then
            print_status "Set via kernel command line: $(grep -o 'amdgpu.ppfeaturemask=[^ ]*' /proc/cmdline)"
        fi
        return 0
    fi
    if [ -f "$OVERDRIVE_CONF" ]; then
        print_status "$OVERDRIVE_CONF already exists, reboot to apply it"
        return 0
    fi

    print_warning "Overclocking/undervolting can cause instability and is at your own risk."
    print_warning "Your kernel will be marked as tainted while overdrive is enabled."
    if ! confirm "Unlock AMD overclocking (writes $OVERDRIVE_CONF and rebuilds initramfs)?"; then
        print_status "Skipping overclocking unlock"
        return 0
    fi

    echo "options amdgpu ppfeaturemask=$OVERDRIVE_MASK" | sudo tee "$OVERDRIVE_CONF" >/dev/null
    print_status "Created $OVERDRIVE_CONF"
    regenerate_initramfs
    reboot_needed=true
}

revert() {
    print_header "Revert GPU Control Setup"

    if systemctl is-enabled --quiet lactd 2>/dev/null || systemctl is-active --quiet lactd 2>/dev/null; then
        if confirm "Stop and disable the lactd service (LACT stays installed)?"; then
            sudo systemctl disable --now lactd
            print_status "lactd disabled"
        else
            print_status "Keeping lactd enabled"
        fi
    else
        print_status "lactd is not enabled"
    fi

    if [ -f "$OVERDRIVE_CONF" ]; then
        echo "It will be backed up to $BACKUP_DIR before removal."
        if confirm "Remove the AMD overclocking unlock ($OVERDRIVE_CONF)?"; then
            backup_path "$OVERDRIVE_CONF"
            sudo rm -f "$OVERDRIVE_CONF"
            print_status "Removed $OVERDRIVE_CONF"
            regenerate_initramfs
            reboot_needed=true
        fi
    else
        print_status "No overclocking unlock file from this script found"
    fi

    if grep -q 'amdgpu.ppfeaturemask=' /proc/cmdline; then
        print_warning "amdgpu.ppfeaturemask is also set on the kernel command line:"
        print_warning "  $(grep -o 'amdgpu.ppfeaturemask=[^ ]*' /proc/cmdline)"
        print_warning "Remove it from your bootloader entry to fully disable overdrive"
    fi
}

show_usage() {
    cat << EOF
Usage: $0 [option]

Options:
  (none)       Install LACT (+ amdgpu_top and overclocking unlock on AMD)
  --revert     Disable lactd and remove the overclocking unlock (nothing is uninstalled)
  -h, --help   Show this help
EOF
}

reboot_needed=false

case "${1:-}" in
    "")
        print_header "GPU Control Setup"
        if [ -z "$gpu_list" ]; then
            print_warning "No GPU detected"
        else
            echo "$gpu_list" | sed 's/^/  /'
        fi
        install_lact
        if [ "$has_amd" = true ]; then
            install_amd_tools
            enable_overdrive
        else
            print_status "No AMD GPU detected, skipping AMD-specific tools"
        fi
        echo ""
        print_header "Setup complete!"
        echo ""
        echo "Next steps:"
        echo "  - Open 'LACT' from your application menu to set fan curves, power limit and clocks"
        echo "  - Settings are applied by lactd at every boot"
        if [ "$has_amd" = true ]; then
            echo "  - Monitor the GPU with: amdgpu_top (or amdgpu_top --gui)"
        fi
        ;;
    --revert)
        revert
        ;;
    -h|--help)
        show_usage
        exit 0
        ;;
    *)
        print_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac

echo ""
if [ "$reboot_needed" = true ]; then
    print_warning "IMPORTANT: Reboot for the overclocking change to take effect!"
    echo ""
fi
if [ -d "$BACKUP_DIR" ]; then
    echo "Backups: $BACKUP_DIR"
    echo ""
fi
