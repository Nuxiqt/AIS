#!/usr/bin/env bash

# KDE Plasma Settings Script
# Applies my personal KDE setup on a (new) Plasma install: custom keyboard
# shortcuts, keyboard layouts, application launcher icon (Arch logo), and disables
# the volume change audio feedback. Also restores app shortcuts: Konsole (and
# Yakuake, which embeds Konsole) and VS Code keybindings
# These are personal preferences - export your own with: apply-kde-settings.sh export
# Settings are stored in settings.conf next to this script (VS Code keybindings
# in vscode-keybindings.json)
# Run with: bash apply-kde-settings.sh [apply|export]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS_FILE="$SCRIPT_DIR/settings.conf"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
BACKUP_DIR="$HOME/.local/share/ais-backups/kde-$(date +%Y%m%d-%H%M%S)"
CONFIG_FILES=(kglobalshortcutsrc kxkbrc plasmaparc plasma-org.kde.plasma.desktop-appletsrc)
# KXMLGUI files (in $DATA_DIR/kxmlgui5) whose custom action shortcuts are saved
KXMLGUI_FILES=(konsole/sessionui.rc konsole/konsoleui.rc)
# VS Code builds (config dir name under $CONFIG_DIR) and their Arch packages
VSCODE_VARIANTS=("Code" "Code - OSS" "VSCodium")
VSCODE_KEYBINDINGS_NAME="vscode-keybindings.json"
APPLETS_FILE="plasma-org.kde.plasma.desktop-appletsrc"
# Application launcher widgets whose icon is set
LAUNCHER_PLUGINS=(org.kde.plasma.kickoff org.kde.plasma.kicker org.kde.plasma.kickerdash)
DEFAULT_LAUNCHER_ICON="/usr/share/pixmaps/archlinux-logo.svg"

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

# Set the icon of every application launcher widget through the running plasmashell
# (launcher config is stored under per-install widget IDs, so kwriteconfig6 can't target it)
apply_launcher_icon() {
    local icon="$1"
    if [ ! -f "$icon" ]; then
        print_warning "Launcher icon not found: $icon, skipping"
        return
    fi
    if ! command -v qdbus6 &>/dev/null || ! qdbus6 org.kde.plasmashell /PlasmaShell &>/dev/null; then
        print_warning "Plasma is not running, skipping launcher icon (re-run apply after logging in)"
        return
    fi

    local plugins
    plugins=$(printf '"%s",' "${LAUNCHER_PLUGINS[@]}")
    local script="
        var plugins = [${plugins%,}];
        var count = 0;
        panels().forEach(function (panel) {
            panel.widgets().forEach(function (widget) {
                if (plugins.indexOf(widget.type) >= 0) {
                    widget.currentConfigGroup = ['General'];
                    widget.writeConfig('icon', '${icon}');
                    widget.reloadConfig();
                    count++;
                }
            });
        });
        print(count);
    "
    local result
    result=$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$script" 2>&1 || true)
    if [[ "$result" =~ ^[0-9]+$ ]] && [ "$result" -gt 0 ]; then
        print_status "Application launcher icon set to $icon ($result launcher(s))"
    elif [ "$result" = "0" ]; then
        print_warning "No application launcher found in any panel, skipping icon"
    else
        print_warning "Failed to set launcher icon: $result"
    fi
}

# Copy a file into BACKUP_DIR under the given relative path
backup_file() {
    local src="$1" rel="$2"
    [ -f "$src" ] || return 0
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp -a "$src" "$BACKUP_DIR/$rel"
    print_status "Backed up $src"
}

# Print "action|shortcut" for every custom shortcut in a KXMLGUI file
read_kxmlgui_shortcuts() {
    awk '
        /<ActionProperties[ >]/ { in_props = 1 }
        /<\/ActionProperties>/ { in_props = 0 }
        in_props && /<Action / && / shortcut="/ {
            name = $0; sub(/.*name="/, "", name); sub(/".*/, "", name)
            sc = $0; sub(/.*shortcut="/, "", sc); sub(/".*/, "", sc)
            print name "|" sc
        }
    ' "$1"
}

# Set one action shortcut in a KXMLGUI file (e.g. konsole/sessionui.rc)
# Without a local file, write a minimal one with version 1: the app merges its
# shortcuts into its newer built-in UI file on next start
apply_kxmlgui_shortcut() {
    local rel="$1" action="$2" shortcut="$3"
    local path="$DATA_DIR/kxmlgui5/$rel"
    local line="  <Action name=\"$action\" shortcut=\"$shortcut\"/>"

    if [ ! -f "$path" ]; then
        mkdir -p "$(dirname "$path")"
        cat > "$path" << EOF
<?xml version='1.0'?>
<!DOCTYPE gui SYSTEM 'kpartgui.dtd'>
<gui name="$(basename "$rel" ui.rc)" version="1">
 <ActionProperties scheme="Default">
$line
 </ActionProperties>
</gui>
EOF
        return
    fi

    local tmp
    tmp=$(mktemp)
    ACTION="$action" LINE="$line" awk '
        BEGIN { want = "<Action name=\"" ENVIRON["ACTION"] "\"" }
        /<ActionProperties[ >]/ { in_props = 1; has_props = 1 }
        in_props && index($0, want) { if (!done) print ENVIRON["LINE"]; done = 1; next }
        in_props && /<\/ActionProperties>/ { if (!done) print ENVIRON["LINE"]; done = 1; in_props = 0 }
        /<\/gui>/ && !has_props {
            print " <ActionProperties scheme=\"Default\">"
            print ENVIRON["LINE"]
            print " </ActionProperties>"
        }
        { print }
    ' "$path" > "$tmp"
    cat "$tmp" > "$path"
    rm -f "$tmp"
}

# Arch packages for a VS Code build
vscode_packages() {
    case "$1" in
        "Code") echo "visual-studio-code-bin" ;;
        "Code - OSS") echo "code" ;;
        "VSCodium") echo "vscodium-bin vscodium" ;;
    esac
}

# Copy saved keybindings to every VS Code build that is installed or has a config dir
apply_vscode_keybindings() {
    local src="$1" variant pkg dest applied=0
    if [ ! -f "$src" ]; then
        print_warning "VS Code keybindings not found: $src, skipping"
        return
    fi

    for variant in "${VSCODE_VARIANTS[@]}"; do
        local present=false
        [ -d "$CONFIG_DIR/$variant" ] && present=true
        for pkg in $(vscode_packages "$variant"); do
            pacman -Q "$pkg" &>/dev/null && present=true
        done
        [ "$present" = true ] || continue

        dest="$CONFIG_DIR/$variant/User/keybindings.json"
        applied=$((applied + 1))
        if cmp -s "$src" "$dest"; then
            print_status "$variant keybindings already up to date"
            continue
        fi
        backup_file "$dest" "$variant/User/keybindings.json"
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
        print_status "$variant keybindings applied"
    done

    if [ "$applied" -eq 0 ]; then
        print_warning "VS Code is not installed, skipping keybindings (re-run apply after developer-install)"
    fi
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
        echo "# Application launcher icon (applied through plasmashell, not a config file)"
        local launcher_icon
        launcher_icon=$(awk -v plugins="${LAUNCHER_PLUGINS[*]}" '
            BEGIN { n = split(plugins, p, " "); for (i = 1; i <= n; i++) want[p[i]] = 1 }
            /^\[/ { group = $0; next }
            /^plugin=/ && (substr($0, 8) in want) { launcher[group] = 1; next }
            /^icon=/ {
                base = group
                sub(/\[Configuration\]\[General\]$/, "", base)
                if (base != group && (base in launcher)) { print substr($0, 6); exit }
            }
        ' "$CONFIG_DIR/$APPLETS_FILE" 2>/dev/null || true)
        echo "@launcher|General|icon|${launcher_icon:-$DEFAULT_LAUNCHER_ICON}"
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
        echo ""
        echo "# Konsole shortcuts (also used by Yakuake): @kxmlgui|file in kxmlgui5|action|shortcut"
        local rel
        for rel in "${KXMLGUI_FILES[@]}"; do
            if [ -f "$DATA_DIR/kxmlgui5/$rel" ]; then
                read_kxmlgui_shortcuts "$DATA_DIR/kxmlgui5/$rel" | sed "s#^#@kxmlgui|$rel|#"
            fi
        done
        local variant
        for variant in "${VSCODE_VARIANTS[@]}"; do
            if [ -f "$CONFIG_DIR/$variant/User/keybindings.json" ]; then
                cp "$CONFIG_DIR/$variant/User/keybindings.json" "$SCRIPT_DIR/$VSCODE_KEYBINDINGS_NAME"
                echo ""
                echo "# VS Code keybindings (exported from $variant, applied to every installed VS Code build)"
                echo "@vscode|User|keybindings.json|$VSCODE_KEYBINDINGS_NAME"
                break
            fi
        done
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
    for file in "${KXMLGUI_FILES[@]}"; do
        backup_file "$DATA_DIR/kxmlgui5/$file" "kxmlgui5/$file"
    done

    local file group key value count=0 launcher_icon="" vscode_file=""
    while IFS='|' read -r file group key value; do
        [[ -z "$file" || "$file" == \#* ]] && continue
        case "$file" in
            @launcher)
                launcher_icon="$value"
                continue
                ;;
            @vscode)
                vscode_file="$SCRIPT_DIR/$value"
                continue
                ;;
            @kxmlgui)
                apply_kxmlgui_shortcut "$group" "$key" "$value"
                ;;
            *)
                kwriteconfig6 --file "$file" --group "$group" --key "$key" -- "$(unescape_kconfig "$value")"
                ;;
        esac
        count=$((count + 1))
    done < "$SETTINGS_FILE"
    print_status "Applied $count settings"

    # Reload keyboard layouts in the running session
    if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        dbus-send --session --type=signal /Layouts org.kde.keyboard.reloadConfig 2>/dev/null || true
        print_status "Keyboard layouts reloaded"
    fi

    if [ -n "$launcher_icon" ]; then
        apply_launcher_icon "$launcher_icon"
    fi

    if [ -n "$vscode_file" ]; then
        apply_vscode_keybindings "$vscode_file"
    fi

    echo ""
    print_header "Settings applied!"
    echo ""
    print_warning "IMPORTANT: Log out and log back in for shortcuts and audio feedback to take effect!"
    echo "Konsole, Yakuake and VS Code pick up their shortcuts when restarted."
    echo ""
    echo "Backup of previous config: $BACKUP_DIR"
    echo "To undo, copy the files from the backup back to $CONFIG_DIR"
    echo "(the kxmlgui5 folder goes to $DATA_DIR) and log out."
    echo ""
}

show_usage() {
    cat << EOF
Personal KDE Plasma settings (custom shortcuts, keyboard layouts, launcher icon, audio feedback,
Konsole/Yakuake and VS Code shortcuts)

Usage: $0 [command]

Commands:
  apply     Apply settings.conf (and $VSCODE_KEYBINDINGS_NAME) to this machine (default)
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
