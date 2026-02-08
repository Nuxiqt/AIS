#!/usr/bin/env bash
# Steam Remote Play Fix for KDE Wayland
# Configures Steam to use XWayland and auto-allows remote desktop input

set -e

SCRIPT_VERSION="1.0"
POLKIT_RULE="/etc/polkit-1/rules.d/50-steam-remote-input.rules"
STEAM_DESKTOP_LOCAL="$HOME/.local/share/applications/steam.desktop"
STEAM_DESKTOP_BACKUP="$HOME/.local/share/applications/steam.desktop.backup"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
        echo "Usage: sudo $0 [install|revert]"
        exit 1
    fi
}

get_real_user() {
    if [ -n "$SUDO_USER" ]; then
        echo "$SUDO_USER"
    else
        echo "$USER"
    fi
}

apply_steam_remote_play_fix() {
    print_header "Applying Steam Remote Play fix for KDE Wayland"
    
    REAL_USER=$(get_real_user)
    
    # --- Create polkit rule ---
    print_info "Creating polkit rule to auto-allow remote desktop input..."
    cat <<EOF > "$POLKIT_RULE"
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.impl.portal.desktop.RemoteDesktop" ||
         action.id == "org.freedesktop.portal.RemoteDesktop") &&
        subject.user == "$REAL_USER") {
        return polkit.Result.YES;
    }
});
EOF
    
    print_info "Restarting polkit..."
    systemctl restart polkit
    
    print_success "Polkit rule created for user: $REAL_USER"
    
    # --- Modify Steam desktop file ---
    print_info "Modifying Steam desktop file to use XWayland..."
    
    # Run as the actual user, not root
    su - "$REAL_USER" -c "
        # Create local applications directory if it doesn't exist
        mkdir -p ~/.local/share/applications
        
        # Backup original if it exists and no backup exists yet
        if [ -f '$STEAM_DESKTOP_LOCAL' ] && [ ! -f '$STEAM_DESKTOP_BACKUP' ]; then
            cp '$STEAM_DESKTOP_LOCAL' '$STEAM_DESKTOP_BACKUP'
            echo 'Backed up existing steam.desktop'
        elif [ ! -f '$STEAM_DESKTOP_LOCAL' ]; then
            cp /usr/share/applications/steam.desktop '$STEAM_DESKTOP_LOCAL'
            cp '$STEAM_DESKTOP_LOCAL' '$STEAM_DESKTOP_BACKUP'
            echo 'Copied and backed up steam.desktop from system'
        fi
        
        # Modify all Exec lines to use XWayland
        sed -i 's|^Exec=/usr/bin/steam|Exec=env GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb /usr/bin/steam|g' '$STEAM_DESKTOP_LOCAL'
        
        # Update desktop database
        update-desktop-database ~/.local/share/applications/
    "
    
    print_success "Steam desktop file modified to use XWayland"
    print_info "Steam will now use XWayland (like SteamOS does)"
}

revert_steam_remote_play_fix() {
    print_header "Reverting Steam Remote Play fix"
    
    REAL_USER=$(get_real_user)
    
    # --- Remove polkit rule ---
    if [ -f "$POLKIT_RULE" ]; then
        print_info "Removing polkit rule..."
        rm -f "$POLKIT_RULE"
        systemctl restart polkit
        print_success "Polkit rule removed"
    else
        print_info "No polkit rule found, skipping"
    fi
    
    # --- Restore Steam desktop file ---
    su - "$REAL_USER" -c "
        if [ -f '$STEAM_DESKTOP_BACKUP' ]; then
            echo 'Restoring original steam.desktop...'
            cp '$STEAM_DESKTOP_BACKUP' '$STEAM_DESKTOP_LOCAL'
            rm '$STEAM_DESKTOP_BACKUP'
            update-desktop-database ~/.local/share/applications/
            echo 'Steam desktop file restored'
        else
            echo 'No backup found, removing local steam.desktop...'
            rm -f '$STEAM_DESKTOP_LOCAL'
            update-desktop-database ~/.local/share/applications/
            echo 'Local steam.desktop removed'
        fi
    "
    
    print_success "Steam Remote Play fix reverted"
}

install_fix() {
    print_header "Installing Steam Remote Play fix (v$SCRIPT_VERSION)"
    apply_steam_remote_play_fix
    echo ""
    print_success "Installation complete!"
    echo ""
    echo -e "${YELLOW}NEXT STEPS:${NC}"
    echo "  1. Fully quit Steam: killall steam"
    echo "  2. Relaunch Steam from application menu"
    echo "  3. Test Steam Remote Play - no more input prompts!"
    echo ""
    echo -e "${YELLOW}What was changed:${NC}"
    echo "  • Created: $POLKIT_RULE"
    echo "  • Modified: $STEAM_DESKTOP_LOCAL"
    echo "  • Backup: $STEAM_DESKTOP_BACKUP"
}

revert_fix() {
    print_header "Reverting Steam Remote Play fix"
    revert_steam_remote_play_fix
    echo ""
    print_success "Revert complete!"
    echo ""
    echo -e "${YELLOW}Note:${NC}"
    echo "  - Restart Steam for changes to take effect"
    echo "  - All modifications have been removed"
}

show_usage() {
    echo "Steam Remote Play Fix for KDE Wayland on Arch Linux"
    echo ""
    echo "Usage: sudo $0 [command]"
    echo ""
    echo "Commands:"
    echo "  install    Apply the fix (XWayland + polkit rule)"
    echo "  revert     Remove the fix and restore defaults"
    echo ""
    echo "What this does:"
    echo "  - Configures Steam to use XWayland (like SteamOS)"
    echo "  - Creates polkit rule to auto-allow remote desktop input"
    echo "  - Fixes 'Remote control requested' prompts in Remote Play"
    echo ""
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