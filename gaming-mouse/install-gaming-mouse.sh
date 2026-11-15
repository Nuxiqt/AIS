#!/usr/bin/env bash

# Gaming Mouse Configuration Setup Script
# Detects connected mice by USB vendor and offers the matching config tool:
#  - Piper (libratbag) for supported Logitech, Razer, SteelSeries and other gaming mice
#  - rivalcfg (AUR) for SteelSeries mice (Rival, Sensei, Aerox, Prime)
#  - Solaar for Logitech devices (Unifying/Bolt receivers, battery, settings)
# Run with: bash install-gaming-mouse.sh

# Note: Script will continue even if individual packages fail to install

# USB vendor IDs
VENDOR_LOGITECH="046d"
VENDOR_STEELSERIES="1038"

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

# Ask a yes/no question with a default ("y" or "n")
confirm() {
    local prompt="$1" default="${2:-n}" answer
    if [ "$default" = "y" ]; then
        read -r -p "$prompt [Y/n]: " answer
        [[ ! "$answer" =~ ^[Nn]$ ]]
    else
        read -r -p "$prompt [y/N]: " answer
        [[ "$answer" =~ ^[Yy]$ ]]
    fi
}

# Check if a USB device from this vendor is connected (reads sysfs, no usbutils needed)
usb_vendor_connected() {
    grep -qix "$1" /sys/bus/usb/devices/*/idVendor 2>/dev/null
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root"
    exit 1
fi

print_header "Gaming Mouse Configuration Setup"

installed=()

has_logitech=false
has_steelseries=false
usb_vendor_connected "$VENDOR_LOGITECH" && has_logitech=true
usb_vendor_connected "$VENDOR_STEELSERIES" && has_steelseries=true

echo "Detected devices:"
[ "$has_logitech" = true ] && echo "  - Logitech"
[ "$has_steelseries" = true ] && echo "  - SteelSeries"
[ "$has_logitech" = false ] && [ "$has_steelseries" = false ] && echo "  - No Logitech or SteelSeries devices"

# Piper (libratbag): the ratbagd daemon is D-Bus activated, so no service needs enabling
echo ""
print_status "Piper: GUI for gaming mice supported by libratbag (Logitech G, Razer, some SteelSeries)"
if pacman -Q piper &>/dev/null; then
    print_status "Piper already installed: $(pacman -Q piper)"
    installed+=("Piper (libratbag)")
elif confirm "Install Piper?" y; then
    if sudo pacman -S --needed --noconfirm piper; then
        installed+=("Piper (libratbag)")
    else
        print_warning "Piper installation failed, continuing..."
    fi
else
    print_status "Skipping Piper"
fi

# rivalcfg for SteelSeries mice (most newer models aren't supported by libratbag)
if [ "$has_steelseries" = true ]; then
    echo ""
    print_status "rivalcfg: SteelSeries mouse config (DPI, polling rate, RGB, buttons, sleep timer)"
    if pacman -Q rivalcfg &>/dev/null; then
        print_status "rivalcfg already installed: $(pacman -Q rivalcfg)"
        installed+=("rivalcfg")
    elif ! command -v yay &>/dev/null; then
        print_warning "yay is required to install rivalcfg from the AUR (run install.sh first), skipping"
    elif confirm "Install rivalcfg from the AUR?" y; then
        if yay -S --needed --noconfirm rivalcfg; then
            installed+=("rivalcfg")
        else
            print_warning "rivalcfg installation failed, continuing..."
        fi
    else
        print_status "Skipping rivalcfg"
    fi

    # rivalcfg needs udev rules to access the mouse without root
    if command -v rivalcfg &>/dev/null && ! grep -qs "$VENDOR_STEELSERIES" /etc/udev/rules.d/*rival* /usr/lib/udev/rules.d/*rival*; then
        if confirm "Install rivalcfg udev rules (lets rivalcfg run without sudo)?" y; then
            sudo rivalcfg --update-udev || print_warning "Failed to install udev rules, continuing..."
        fi
    fi
fi

# Solaar for Logitech receivers and devices
if [ "$has_logitech" = true ]; then
    echo ""
    print_status "Solaar: Logitech Unifying/Bolt receivers, pairing, battery and device settings"
    if pacman -Q solaar &>/dev/null; then
        print_status "Solaar already installed: $(pacman -Q solaar)"
        installed+=("Solaar")
    elif confirm "Install Solaar?" y; then
        if sudo pacman -S --needed --noconfirm solaar; then
            installed+=("Solaar")
        else
            print_warning "Solaar installation failed, continuing..."
        fi
    else
        print_status "Skipping Solaar"
    fi
fi

echo ""
print_header "Installation complete!"
echo ""
if [ ${#installed[@]} -gt 0 ]; then
    echo "Installed tools:"
    for tool in "${installed[@]}"; do
        echo "  - $tool"
    done
else
    echo "No tools were installed."
fi
echo ""

if command -v ratbagctl &>/dev/null; then
    echo "Mice detected by libratbag (usable in Piper):"
    ratbagctl list 2>/dev/null | sed 's/^/  /' || echo "  (could not query ratbagd)"
    echo ""
fi
if command -v rivalcfg &>/dev/null; then
    echo "SteelSeries usage:"
    echo "  - Show options for your mouse: rivalcfg --help"
    echo "  - Example: rivalcfg --sensitivity 800 --polling-rate 1000"
    echo ""
fi
if [ "$has_logitech" = true ] && command -v solaar &>/dev/null; then
    echo "Logitech usage:"
    echo "  - Launch 'Solaar' from your application menu (or 'solaar show' in a terminal)"
    echo ""
fi
