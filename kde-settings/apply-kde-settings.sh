#!/usr/bin/env bash

# KDE Plasma Settings Script
# Applies my personal KDE setup on a (new) Plasma install: custom keyboard
# shortcuts, keyboard layouts, and disables the volume change audio feedback
# These are personal preferences - export your own with: apply-kde-settings.sh export
# Settings are stored in settings.conf next to this script
# Run with: bash apply-kde-settings.sh [apply|export]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS_FILE="$SCRIPT_DIR/settings.conf"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR="$HOME/.local/share/ais-backups/kde-$(date +%Y%m%d-%H%M%S)"
CONFIG_FILES=(kglobalshortcutsrc kxkbrc plasmaparc)

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

# Turn a raw KConfig file value back into the real value for kwriteconfig6
# (KConfig escapes: \\ -> \, \t -> tab)
unescape_kconfig() {
    local value="$1"
    value=${value//\\\\/$'\x01'}
    value=${value//\\t/$'\t'}
    value=${value//$'\x01'/\\}
    printf '%s' "$value"
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Please do not run this script as root"
        exit 1
    fi
}

# Save current custom settings from this machine into settings.conf
export_settings() {
    print_header "Exporting KDE Settings"

    local shortcuts="$CONFIG_DIR/kglobalshortcutsrc"
    local layouts="$CONFIG_DIR/kxkbrc"
    if [ ! -f "$shortcuts" ] || [ ! -f "$layouts" ]; then
        print_error "KDE config files not found in $CONFIG_DIR"
        exit 1
    fi

    if [ -f "$SETTINGS_FILE" ] && ! confirm "Overwrite $SETTINGS_FILE?"; then
        print_status "Nothing changed"
        return
    fi

    {
        echo "# Personal KDE settings for apply-kde-settings.sh (custom keybinds and preferences,"
        echo "# not KDE defaults - review before applying on another setup)"
        echo "# Format: file|group|key|value (value as stored in the KDE config file)"
        echo "# Regenerate with: bash apply-kde-settings.sh export"
        echo ""
        echo "# Disable volume change audio feedback"
        echo "plasmaparc|General|AudioFeedback|false"
        echo ""
        echo "# Keyboard layouts"
        awk '
            /^\[/ { in_layout = ($0 == "[Layout]"); next }
            in_layout && /=/ {
                key = substr($0, 1, index($0, "=") - 1)
                print "kxkbrc|Layout|" key "|" substr($0, index($0, "=") + 1)
            }
        ' "$layouts"
        echo ""
        echo "# Custom global shortcuts (only entries changed from KDE defaults)"
        # Skip "activate widget" shortcuts: widget IDs differ on every install
        awk '
            /^\[/ {
                group = substr($0, 2, length($0) - 2)
                skip = (index(group, "][") > 0)
                next
            }
            skip || !/=/ { next }
            {
                key = substr($0, 1, index($0, "=") - 1)
                value = substr($0, index($0, "=") + 1)
                if (key == "_k_friendly_name" || key ~ /^activate widget /) next
                fields = value
                gsub(/\\\\,/, "\001", fields)
                split(fields, f, ",")
                if (f[1] != f[2]) print "kglobalshortcutsrc|" group "|" key "|" value
            }
        ' "$shortcuts"
    } > "$SETTINGS_FILE"

    print_status "Saved settings to $SETTINGS_FILE"
    echo ""
    grep -v '^#' "$SETTINGS_FILE" | grep -v '^$' | cut -d'|' -f1-3 | sed 's/^/  - /'
}

apply_settings() {
    print_header "Applying KDE Settings"

    if ! command -v kwriteconfig6 &>/dev/null; then
        print_error "kwriteconfig6 not found (is KDE Plasma 6 installed?)"
        exit 1
    fi
    if [ ! -f "$SETTINGS_FILE" ]; then
        print_error "Settings file not found: $SETTINGS_FILE"
        exit 1
    fi

    echo "Settings to apply from $SETTINGS_FILE:"
    grep -v '^#' "$SETTINGS_FILE" | grep -v '^$' | cut -d'|' -f1-3 | sed 's/^/  - /'
    echo ""
    echo "Current config files will be backed up to $BACKUP_DIR first."
    if ! confirm "Apply these settings?"; then
        print_status "Nothing changed"
        return
    fi

    # Backup current config files
    mkdir -p "$BACKUP_DIR"
    for file in "${CONFIG_FILES[@]}"; do
        if [ -f "$CONFIG_DIR/$file" ]; then
            cp -a "$CONFIG_DIR/$file" "$BACKUP_DIR/"
            print_status "Backed up $CONFIG_DIR/$file"
        fi
    done

    local file group key value count=0
    while IFS='|' read -r file group key value; do
        [[ -z "$file" || "$file" == \#* ]] && continue
        kwriteconfig6 --file "$file" --group "$group" --key "$key" -- "$(unescape_kconfig "$value")"
        count=$((count + 1))
    done < "$SETTINGS_FILE"
    print_status "Applied $count settings"

    # Reload keyboard layouts in the running session
    if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        dbus-send --session --type=signal /Layouts org.kde.keyboard.reloadConfig 2>/dev/null || true
        print_status "Keyboard layouts reloaded"
    fi

    echo ""
    print_header "Settings applied!"
    echo ""
    print_warning "IMPORTANT: Log out and log back in for shortcuts and audio feedback to take effect!"
    echo ""
    echo "Backup of previous config: $BACKUP_DIR"
    echo "To undo, copy the files from the backup back to $CONFIG_DIR and log out."
    echo ""
}

show_usage() {
    cat << EOF
Personal KDE Plasma settings (custom shortcuts, keyboard layouts, audio feedback)

Usage: $0 [command]

Commands:
  apply     Apply settings.conf to this machine (default)
  export    Save this machine's custom shortcuts and layouts to settings.conf

Notes:
  - settings.conf holds personal/custom keybinds, not KDE defaults
  - Only shortcuts changed from KDE defaults are exported
  - "Activate widget" shortcuts are skipped (widget IDs differ per install)
  - Run as your regular user, not with sudo
EOF
}

check_root

case "${1:-apply}" in
    apply)
        apply_settings
        ;;
    export)
        export_settings
        ;;
    -h|--help)
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac
