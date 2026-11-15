#!/usr/bin/env bash

# Sunshine Installation Script
# Installs Sunshine (AUR) with GPU encoder dependencies and enables its user service
# Every system change is confirmed first; files are backed up before removal
# Run with: bash install-sunshine.sh            (install and enable)
#           bash install-sunshine.sh --disable  (stop and disable Sunshine services)

set -euo pipefail

SUNSHINE_UNIT="app-dev.lizardbyte.app.Sunshine.service"
BACKUP_DIR="$HOME/.local/share/ais-backups/sunshine-$(date +%Y%m%d-%H%M%S)"

# Files created by older versions of this script
LEGACY_AUTOSSH_START="/usr/local/bin/autossh-sunshine-start"
LEGACY_AUTOSSH_SERVICE="/etc/systemd/system/autossh-sunshine.service"
LEGACY_USER_UNIT="$HOME/.config/systemd/user/sunshine.service"
LEGACY_USER_UNIT_DROPIN="$HOME/.config/systemd/user/sunshine.service.d"

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

# Copy a file or directory into BACKUP_DIR, keeping its full path
backup_path() {
    local path="$1"
    local dest="$BACKUP_DIR$(dirname "$path")"
    mkdir -p "$dest"
    if [ -r "$path" ]; then
        cp -a "$path" "$dest/"
    else
        sudo cp -a "$path" "$dest/"
        sudo chown -R "$(id -u):$(id -g)" "$dest/$(basename "$path")"
    fi
    print_status "Backed up $path"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root"
    exit 1
fi

install_sunshine() {
    if ! command -v yay &>/dev/null; then
        print_error "yay is required to install Sunshine from the AUR (run install.sh first)"
        exit 1
    fi

    local installed
    installed=$(pacman -Qq sunshine sunshine-bin sunshine-git 2>/dev/null | head -n1 || true)
    if [ -n "$installed" ]; then
        print_status "Sunshine already installed: $(pacman -Q "$installed")"
        return
    fi

    echo ""
    echo "Choose Sunshine package (AUR):"
    echo "  1) sunshine-bin (prebuilt, quick install) [default]"
    echo "  2) sunshine (build from source, slower)"
    local choice pkg
    read -r -p "Enter your choice (1-2) [1]: " choice
    case "${choice:-1}" in
        2) pkg="sunshine" ;;
        *) pkg="sunshine-bin" ;;
    esac

    if confirm "Install $pkg from the AUR?"; then
        print_status "Installing $pkg..."
        yay -S --needed "$pkg"
    else
        print_error "Sunshine is required, aborting"
        exit 1
    fi
}

install_gpu_deps() {
    local gpus packages=() missing=()
    gpus=$(lspci | grep -iE 'vga|3d|display' || true)

    if echo "$gpus" | grep -qi nvidia; then
        print_status "NVIDIA GPU detected"
        print_warning "cuda is several GB, but the Sunshine AUR packages need it for NVIDIA encoding"
        packages+=(nvidia-utils cuda)
    fi
    if echo "$gpus" | grep -qiE 'amd|radeon'; then
        print_status "AMD GPU detected (VA-API encoding is provided by mesa)"
        packages+=(mesa)
    fi
    if echo "$gpus" | grep -qi intel; then
        print_status "Intel GPU detected"
        packages+=(intel-media-driver)
    fi

    if [ ${#packages[@]} -eq 0 ]; then
        print_warning "No supported GPU detected, Sunshine will fall back to software encoding"
        return
    fi

    for pkg in "${packages[@]}"; do
        pacman -Q "$pkg" &>/dev/null || missing+=("$pkg")
    done

    if [ ${#missing[@]} -eq 0 ]; then
        print_status "GPU encoder dependencies already installed: ${packages[*]}"
        return
    fi

    if confirm "Install GPU encoder dependencies: ${missing[*]}?"; then
        sudo pacman -S --needed --noconfirm "${missing[@]}"
    else
        print_warning "Skipping GPU encoder dependencies, hardware encoding may not work"
    fi
}

# Remove the autossh fallback and custom user unit written by older script versions
cleanup_legacy_setup() {
    local found=()
    [ -e "$LEGACY_AUTOSSH_SERVICE" ] && found+=("$LEGACY_AUTOSSH_SERVICE")
    [ -e "$LEGACY_AUTOSSH_START" ] && found+=("$LEGACY_AUTOSSH_START")
    [ -e "$LEGACY_USER_UNIT" ] && found+=("$LEGACY_USER_UNIT")
    [ -e "$LEGACY_USER_UNIT_DROPIN" ] && found+=("$LEGACY_USER_UNIT_DROPIN")

    if [ ${#found[@]} -eq 0 ]; then
        return
    fi

    echo ""
    print_warning "Found files from an older Sunshine setup (replaced by Sunshine's own user service):"
    for path in "${found[@]}"; do
        echo "  - $path"
    done
    echo "They will be backed up to $BACKUP_DIR before removal."
    if ! confirm "Back up and remove them?"; then
        print_warning "Keeping old setup files"
        return
    fi

    for path in "${found[@]}"; do
        backup_path "$path"
    done

    if [ -e "$LEGACY_AUTOSSH_SERVICE" ]; then
        print_status "Disabling and removing autossh-sunshine.service..."
        sudo systemctl disable --now autossh-sunshine.service 2>/dev/null || true
        sudo rm -f "$LEGACY_AUTOSSH_SERVICE"
        sudo systemctl daemon-reload
    fi
    if [ -e "$LEGACY_AUTOSSH_START" ]; then
        print_status "Removing $LEGACY_AUTOSSH_START..."
        sudo rm -f "$LEGACY_AUTOSSH_START"
    fi
    if [ -e "$LEGACY_USER_UNIT" ]; then
        print_status "Disabling and removing custom sunshine.service..."
        systemctl --user disable --now sunshine.service 2>/dev/null || true
        rm -f "$LEGACY_USER_UNIT"
    fi
    if [ -e "$LEGACY_USER_UNIT_DROPIN" ]; then
        print_status "Removing $LEGACY_USER_UNIT_DROPIN..."
        rm -rf "$LEGACY_USER_UNIT_DROPIN"
    fi
    systemctl --user daemon-reload

    # Older versions enabled linger so the custom unit started at boot; Sunshine's
    # own unit waits for the graphical session, so linger is no longer needed
    if [ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null)" = "yes" ]; then
        print_warning "Linger is enabled for $USER (older versions enabled it for Sunshine)"
        echo "Keep it if other user services need to run without you logged in."
        if confirm "Disable linger?"; then
            loginctl disable-linger "$USER"
            print_status "Linger disabled"
        fi
    fi
}

enable_startup() {
    if ! systemctl --user list-unit-files "$SUNSHINE_UNIT" &>/dev/null; then
        print_error "$SUNSHINE_UNIT not found, check your Sunshine package"
        return
    fi

    if systemctl --user is-enabled --quiet "$SUNSHINE_UNIT" 2>/dev/null; then
        print_status "Sunshine user service already enabled"
        return
    fi

    if [ -e "$LEGACY_USER_UNIT" ]; then
        print_warning "Custom $LEGACY_USER_UNIT still exists and conflicts with $SUNSHINE_UNIT"
        print_warning "Skipping startup enable; remove the old setup and re-run this script"
        return
    fi

    echo ""
    if confirm "Start Sunshine automatically when you log in?"; then
        systemctl --user enable --now "$SUNSHINE_UNIT"
        print_status "Sunshine user service enabled and started"
    else
        print_status "Skipping startup enable"
    fi
}

# Stop and disable Sunshine services without uninstalling anything
disable_services() {
    print_header "Disable Sunshine Services"

    local user_units=() system_units=() unit_id
    # sunshine.service may be an alias of $SUNSHINE_UNIT or an old custom unit;
    # resolve to the real unit name so each service is listed once
    for unit in "$SUNSHINE_UNIT" sunshine.service; do
        if systemctl --user is-enabled --quiet "$unit" 2>/dev/null || systemctl --user is-active --quiet "$unit" 2>/dev/null; then
            unit_id=$(systemctl --user show -p Id --value "$unit" 2>/dev/null || echo "$unit")
            if [[ ! " ${user_units[*]} " =~ " ${unit_id} " ]]; then
                user_units+=("$unit_id")
            fi
        fi
    done
    if systemctl is-enabled --quiet autossh-sunshine.service 2>/dev/null || systemctl is-active --quiet autossh-sunshine.service 2>/dev/null; then
        system_units+=(autossh-sunshine.service)
    fi

    if [ ${#user_units[@]} -eq 0 ] && [ ${#system_units[@]} -eq 0 ]; then
        print_status "No enabled or running Sunshine services found"
        return
    fi

    echo "Services to stop and disable:"
    for unit in "${user_units[@]}"; do
        echo "  - $unit (user)"
    done
    for unit in "${system_units[@]}"; do
        echo "  - $unit (system)"
    done
    if ! confirm "Stop and disable them?"; then
        print_status "Nothing changed"
        return
    fi

    for unit in "${user_units[@]}"; do
        systemctl --user disable --now "$unit" 2>/dev/null || true
        print_status "Disabled $unit"
    done
    for unit in "${system_units[@]}"; do
        sudo systemctl disable --now "$unit"
        print_status "Disabled $unit"
    done

    echo ""
    print_header "Sunshine services disabled"
    echo ""
    echo "Sunshine is still installed. Re-enable it by running this script without --disable."
    echo ""
}

show_usage() {
    cat << EOF
Usage: $0 [option]

Options:
  (none)       Install Sunshine, GPU encoder deps and enable its user service
  --disable    Stop and disable Sunshine services (nothing is uninstalled)
  -h, --help   Show this help
EOF
}

install_all() {
    print_header "Sunshine Installation"

    install_sunshine
    install_gpu_deps
    cleanup_legacy_setup
    enable_startup

    echo ""
    print_header "Installation complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Open https://localhost:47990 to set up a username and password"
    echo "  2. Pair Moonlight on your other device using the PIN it shows"
    echo ""
    echo "Notes:"
    echo "  - Sunshine starts when you log in; enable autologin in Plasma to have it ready after boot"
    echo "  - If you use a firewall, allow TCP 47984, 47989, 47990, 48010 and UDP 47998-48000"
    if [ -d "$BACKUP_DIR" ]; then
        echo "  - Backups of removed files: $BACKUP_DIR"
    fi
    echo ""
}

main() {
    case "${1:-}" in
        "")
            install_all
            ;;
        --disable)
            disable_services
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
