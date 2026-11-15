#!/usr/bin/env bash

# Steam Remote Play Fix for KDE Wayland
# Configures Steam to use XWayland and disables remote desktop portal prompts
# Run with: bash steam-remote-play-allow.sh [install|revert]

set -e

SCRIPT_VERSION="1.1"
PORTAL_CONFIG="$HOME/.config/xdg-desktop-portal/portals.conf"
PORTAL_CONFIG_BACKUP="$HOME/.config/xdg-desktop-portal/portals.conf.backup"
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

apply_portal_config() {
    print_header "Configuring xdg-desktop-portal for Steam Remote Play"

    # Create config directory
    mkdir -p ~/.config/xdg-desktop-portal

    # Backup existing config if present
    if [ -f "$PORTAL_CONFIG" ] && [ ! -f "$PORTAL_CONFIG_BACKUP" ]; then
        print_status "Backing up existing portal configuration..."
        cp "$PORTAL_CONFIG" "$PORTAL_CONFIG_BACKUP"
    fi

    # Create portal config to disable RemoteDesktop prompts
    print_status "Creating portal configuration..."
    cat <<EOF > "$PORTAL_CONFIG"
[preferred]
default=kde
org.freedesktop.impl.portal.RemoteDesktop=none
EOF

    print_status "Portal configuration created"

    # Unmask and restart portals
    print_status "Unmasking xdg-desktop-portal-kde (if masked)..."
    systemctl --user unmask xdg-desktop-portal-kde 2>/dev/null || true

    print_status "Restarting desktop portals..."
    systemctl --user restart xdg-desktop-portal-kde 2>/dev/null || true
    systemctl --user restart xdg-desktop-portal 2>/dev/null || true

    print_status "Desktop portals restarted"
}

revert_portal_config() {
    print_header "Reverting portal configuration"

    if [ -f "$PORTAL_CONFIG_BACKUP" ]; then
        print_status "Restoring original portal configuration..."
        cp "$PORTAL_CONFIG_BACKUP" "$PORTAL_CONFIG"
        rm "$PORTAL_CONFIG_BACKUP"
        print_status "Original portal configuration restored"
    elif [ -f "$PORTAL_CONFIG" ]; then
        print_status "Removing portal configuration..."
        rm "$PORTAL_CONFIG"
        print_status "Portal configuration removed"
    else
        print_status "No portal configuration found, skipping"
    fi

    # Restart portals
    print_status "Restarting desktop portals..."
    systemctl --user restart xdg-desktop-portal-kde 2>/dev/null || true
    systemctl --user restart xdg-desktop-portal 2>/dev/null || true

    print_status "Desktop portals restarted"
}

apply_steam_desktop_fix() {
    print_header "Modifying Steam to use XWayland"

    # Check if steam is installed
    if [ ! -f /usr/share/applications/steam.desktop ]; then
        print_error "Steam desktop file not found at /usr/share/applications/steam.desktop"
        print_error "Please install Steam first"
        exit 1
    fi

    # Create local applications directory if it doesn't exist
    mkdir -p ~/.local/share/applications

    # Backup original if it exists and no backup exists yet
    if [ -f "$STEAM_DESKTOP_LOCAL" ] && [ ! -f "$STEAM_DESKTOP_BACKUP" ]; then
        print_status "Backing up existing steam.desktop..."
        cp "$STEAM_DESKTOP_LOCAL" "$STEAM_DESKTOP_BACKUP"
    elif [ ! -f "$STEAM_DESKTOP_LOCAL" ]; then
        print_status "Copying steam.desktop from system..."
        cp /usr/share/applications/steam.desktop "$STEAM_DESKTOP_LOCAL"
        cp "$STEAM_DESKTOP_LOCAL" "$STEAM_DESKTOP_BACKUP"
    fi

    # Modify all Exec lines to use XWayland
    print_status "Modifying Exec lines to use XWayland..."
    sed -i 's|^Exec=/usr/bin/steam|Exec=env GDK_BACKEND=x11 /usr/bin/steam|g' "$STEAM_DESKTOP_LOCAL"

    # Update desktop database
    print_status "Updating desktop database..."
    update-desktop-database ~/.local/share/applications/

    print_status "Steam desktop file modified to use XWayland (like SteamOS)"
}

revert_steam_desktop_fix() {
    print_header "Reverting Steam desktop file"

    if [ -f "$STEAM_DESKTOP_BACKUP" ]; then
        print_status "Restoring original steam.desktop..."
        cp "$STEAM_DESKTOP_BACKUP" "$STEAM_DESKTOP_LOCAL"
        rm "$STEAM_DESKTOP_BACKUP"
        update-desktop-database ~/.local/share/applications/
        print_status "Steam desktop file restored"
    else
        print_status "No backup found, removing local steam.desktop..."
        rm -f "$STEAM_DESKTOP_LOCAL"
        update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
        print_status "Local steam.desktop removed"
    fi
}

install_fix() {
    print_header "Installing Steam Remote Play fix (v$SCRIPT_VERSION)"
    echo ""

    check_packages
    apply_portal_config
    echo ""
    apply_steam_desktop_fix
    echo ""

    print_header "Installation complete!"
    echo ""
    echo -e "${YELLOW}NEXT STEPS:${NC}"
    echo "  1. Fully quit Steam: killall steam"
    echo "  2. Relaunch Steam from application menu"
    echo "  3. Test Steam Remote Play - no more input prompts!"
    echo ""
    echo -e "${YELLOW}What was changed:${NC}"
    echo "  • Created: $PORTAL_CONFIG"
    echo "  • Modified: $STEAM_DESKTOP_LOCAL"
    echo "  • Steam now launches with: env GDK_BACKEND=x11"
    echo ""
    echo -e "${YELLOW}Backups created:${NC}"
    if [ -f "$PORTAL_CONFIG_BACKUP" ]; then
        echo "  • $PORTAL_CONFIG_BACKUP"
    fi
    if [ -f "$STEAM_DESKTOP_BACKUP" ]; then
        echo "  • $STEAM_DESKTOP_BACKUP"
    fi
}

revert_fix() {
    print_header "Reverting Steam Remote Play fix"

    revert_portal_config
    echo ""
    revert_steam_desktop_fix
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
  install    Apply the fix (XWayland + portal config)
  revert     Remove the fix and restore defaults

What this does:
  - Checks and installs required packages if missing
  - Configures Steam to use XWayland (like SteamOS)
  - Disables xdg-desktop-portal RemoteDesktop prompts
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