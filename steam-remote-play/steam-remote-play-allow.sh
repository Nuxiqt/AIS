#!/usr/bin/env bash

# Steam Remote Play Fix for KDE Wayland
# Disables the RemoteDesktop portal so Remote Play doesn't prompt on every connection
# Run with: bash steam-remote-play-allow.sh [install|revert]
# Portal config template: kde-portals.conf (next to this script)

set -e

SCRIPT_VERSION="1.3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORTAL_BASE_CONFIG="$SCRIPT_DIR/kde-portals.conf"
PORTAL_CONFIG_DIR="$HOME/.config/xdg-desktop-portal"
PORTAL_CONFIG="$PORTAL_CONFIG_DIR/kde-portals.conf"
PORTAL_CONFIG_BACKUP="$PORTAL_CONFIG_DIR/kde-portals.conf.backup"
# Written by script versions <= 1.1; overrides all KDE portal defaults
LEGACY_PORTAL_CONFIG="$PORTAL_CONFIG_DIR/portals.conf"
LEGACY_PORTAL_CONFIG_BACKUP="$PORTAL_CONFIG_DIR/portals.conf.backup"
# steam.desktop override written by script versions <= 1.2 (cleaned up on install/revert)
STEAM_DESKTOP_LOCAL="$HOME/.local/share/applications/steam.desktop"
STEAM_DESKTOP_BACKUP="$HOME/.local/share/applications/steam.desktop.backup"

# Required packages
REQUIRED_PACKAGES=("xdg-desktop-portal" "xdg-desktop-portal-kde" "steam")

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

check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Please do not run this script as root"
        echo "Usage: $0 [install|revert]"
        exit 1
    fi
}

check_packages() {
    print_header "Checking required packages"

    local missing_packages=()

    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! pacman -Q "$package" &>/dev/null; then
            missing_packages+=("$package")
            print_warning "Package not found: $package"
        else
            print_status "Found: $package"
        fi
    done

    if [ ${#missing_packages[@]} -gt 0 ]; then
        echo ""
        print_error "Missing required packages: ${missing_packages[*]}"
        echo ""
        echo -e "${YELLOW}Would you like to install them now? [y/N]${NC}"
        read -r response

        if [[ "$response" =~ ^[Yy]$ ]]; then
            print_status "Installing missing packages..."
            sudo pacman -S --needed "${missing_packages[@]}"
            print_status "Packages installed successfully"
        else
            print_error "Cannot continue without required packages"
            exit 1
        fi
    else
        print_status "All required packages are installed"
    fi

    echo ""
}

restart_portals() {
    print_status "Restarting desktop portals..."
    systemctl --user restart plasma-xdg-desktop-portal-kde 2>/dev/null || true
    systemctl --user restart xdg-desktop-portal 2>/dev/null || true
    print_status "Desktop portals restarted"
}

# Undo the portals.conf written by script versions <= 1.1
migrate_legacy_portal_config() {
    if [ -f "$LEGACY_PORTAL_CONFIG_BACKUP" ]; then
        print_status "Restoring portals.conf from before older script version..."
        mv "$LEGACY_PORTAL_CONFIG_BACKUP" "$LEGACY_PORTAL_CONFIG"
    elif [ -f "$LEGACY_PORTAL_CONFIG" ] && grep -q "^org.freedesktop.impl.portal.RemoteDesktop=none" "$LEGACY_PORTAL_CONFIG"; then
        print_status "Removing portals.conf created by older script version..."
        rm "$LEGACY_PORTAL_CONFIG"
    fi
}

apply_portal_config() {
    print_header "Configuring xdg-desktop-portal for Steam Remote Play"

    if [ ! -f "$PORTAL_BASE_CONFIG" ]; then
        print_error "Base portal config not found: $PORTAL_BASE_CONFIG"
        exit 1
    fi

    mkdir -p "$PORTAL_CONFIG_DIR"
    migrate_legacy_portal_config

    # Warn if Plasma's defaults changed and the base config is out of date
    local system_config="/usr/share/xdg-desktop-portal/kde-portals.conf"
    if [ -f "$system_config" ]; then
        while IFS= read -r line; do
            case "$line" in
                ""|"#"*|"["*) continue ;;
            esac
            if ! grep -Fxq "$line" "$PORTAL_BASE_CONFIG"; then
                print_warning "Plasma default missing from base config: $line"
                print_warning "Update $PORTAL_BASE_CONFIG to match $system_config"
            fi
        done < "$system_config"
    fi

    # Backup existing config if present (and not already ours from a previous run)
    if [ -f "$PORTAL_CONFIG" ] && [ ! -f "$PORTAL_CONFIG_BACKUP" ] && ! cmp -s "$PORTAL_CONFIG" "$PORTAL_BASE_CONFIG"; then
        print_status "Backing up existing portal configuration..."
        cp "$PORTAL_CONFIG" "$PORTAL_CONFIG_BACKUP"
    fi

    # Install base config (Plasma defaults + RemoteDesktop disabled)
    print_status "Installing portal configuration from $PORTAL_BASE_CONFIG..."
    cp "$PORTAL_BASE_CONFIG" "$PORTAL_CONFIG"
    print_status "Portal configuration installed"

    restart_portals
}

revert_portal_config() {
    print_header "Reverting portal configuration"

    migrate_legacy_portal_config

    if [ -f "$PORTAL_CONFIG_BACKUP" ]; then
        print_status "Restoring original portal configuration..."
        mv "$PORTAL_CONFIG_BACKUP" "$PORTAL_CONFIG"
        print_status "Original portal configuration restored"
    elif [ -f "$PORTAL_CONFIG" ]; then
        print_status "Removing portal configuration..."
        rm "$PORTAL_CONFIG"
        print_status "Portal configuration removed"
    else
        print_status "No portal configuration found, skipping"
    fi

    restart_portals
}

# Undo the GDK_BACKEND=x11 steam.desktop override from script versions <= 1.2
# (Steam is X11-only and not GTK, so it had no effect)
cleanup_legacy_steam_desktop() {
    local system_desktop="/usr/share/applications/steam.desktop"

    if [ -f "$STEAM_DESKTOP_BACKUP" ]; then
        if [ -f "$system_desktop" ] && cmp -s "$STEAM_DESKTOP_BACKUP" "$system_desktop"; then
            # Backup was just a copy of the system file, so no local override existed before
            print_status "Removing steam.desktop override created by older script version..."
            rm -f "$STEAM_DESKTOP_LOCAL" "$STEAM_DESKTOP_BACKUP"
        else
            print_status "Restoring steam.desktop from before older script version..."
            mv "$STEAM_DESKTOP_BACKUP" "$STEAM_DESKTOP_LOCAL"
        fi
    elif [ -f "$STEAM_DESKTOP_LOCAL" ] && grep -q "^Exec=env GDK_BACKEND=x11 " "$STEAM_DESKTOP_LOCAL"; then
        sed -i 's|^Exec=env GDK_BACKEND=x11 |Exec=|' "$STEAM_DESKTOP_LOCAL"
        if [ -f "$system_desktop" ] && cmp -s "$STEAM_DESKTOP_LOCAL" "$system_desktop"; then
            print_status "Removing steam.desktop override created by older script version..."
            rm -f "$STEAM_DESKTOP_LOCAL"
        else
            print_status "Removed GDK_BACKEND=x11 from local steam.desktop (kept your other changes)"
        fi
    else
        return 0
    fi

    update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
}

install_fix() {
    print_header "Installing Steam Remote Play fix (v$SCRIPT_VERSION)"
    echo ""

    check_packages
    apply_portal_config
    cleanup_legacy_steam_desktop
    echo ""

    print_header "Installation complete!"
    echo ""
    echo -e "${YELLOW}NEXT STEPS:${NC}"
    echo "  1. Fully quit Steam: killall steam"
    echo "  2. Relaunch Steam from application menu"
    echo "  3. Test Steam Remote Play - no more input prompts!"
    echo ""
    echo -e "${YELLOW}What was changed:${NC}"
    echo "  • Installed: $PORTAL_CONFIG (from $PORTAL_BASE_CONFIG)"
    echo ""
    if [ -f "$PORTAL_CONFIG_BACKUP" ]; then
        echo -e "${YELLOW}Backup created:${NC}"
        echo "  • $PORTAL_CONFIG_BACKUP"
    fi
}

revert_fix() {
    print_header "Reverting Steam Remote Play fix"

    revert_portal_config
    cleanup_legacy_steam_desktop
    echo ""

    print_header "Revert complete!"
    echo ""
    echo -e "${YELLOW}Note:${NC}"
    echo "  - Restart Steam for changes to take effect"
    echo "  - All modifications have been removed"
}

show_usage() {
    cat << EOF
Steam Remote Play Fix for KDE Wayland on Arch Linux (v$SCRIPT_VERSION)

Usage: $0 [command]

Commands:
  install    Apply the fix (portal config)
  revert     Remove the fix and restore defaults

What this does:
  - Checks and installs required packages if missing
  - Installs kde-portals.conf (Plasma defaults + RemoteDesktop disabled)
    to ~/.config/xdg-desktop-portal/ to stop RemoteDesktop prompts
  - Fixes 'Remote control requested' prompts in Remote Play

Required packages:
  - xdg-desktop-portal
  - xdg-desktop-portal-kde
  - steam

Note: Do NOT run with sudo - run as your regular user

Examples:
  $0 install    # Install the fix
  $0 revert     # Remove the fix

EOF
    exit 1
}

# Main script logic
check_root

case "${1:-}" in
    install)
        install_fix
        ;;
    revert)
        revert_fix
        ;;
    *)
        show_usage
        ;;
esac