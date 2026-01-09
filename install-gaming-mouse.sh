#!/bin/bash

# Gaming Mouse Configuration Setup Script
# Installs ratbagd and Piper for gaming mouse configuration (Logitech and others)
# Run with: bash install-gaming-mouse.sh

# Note: Script will continue even if individual packages fail to install

echo "================================================"
echo "Gaming Mouse Configuration Setup"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[*]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    print_error "Please do not run this script as root"
    exit 1
fi

# Install ratbagd and Piper
print_status "Installing ratbagd (daemon for gaming mice configuration)..."
sudo pacman -S --needed --noconfirm libratbag || print_warning "libratbag installation failed, continuing..."

print_status "Installing Piper (GUI for gaming mice configuration)..."
sudo pacman -S --needed --noconfirm piper || print_warning "Piper installation failed, continuing..."

# Enable and start ratbagd service
print_status "Enabling ratbagd service..."
sudo systemctl enable ratbagd || print_warning "Failed to enable ratbagd service, continuing..."
sudo systemctl start ratbagd || print_warning "Failed to start ratbagd service, continuing..."

echo ""
echo "================================================"
print_status "Installation complete!"
echo "================================================"
echo ""
echo "Installed packages:"
echo "  - libratbag (ratbagd daemon)"
echo "  - Piper (GUI configuration tool)"
echo ""
echo "Supported mice include:"
echo "  - Logitech G series (G203, G502, G703, G903, etc.)"
echo "  - SteelSeries Rival series"
echo "  - ROCCAT mice"
echo "  - And many more gaming mice"
echo ""
echo "Usage:"
echo "  1. Launch 'Piper' from your application menu"
echo "  2. Connect your gaming mouse"
echo "  3. Configure buttons, DPI, LEDs, and more"
echo ""
echo "For a full list of supported devices, visit:"
echo "  https://github.com/libratbag/libratbag"
echo ""
