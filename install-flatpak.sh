#!/bin/bash

# Flatpak and Discover Setup Script
# Run with: bash install-flatpak.sh

set -e

echo "================================================"
echo "Flatpak and Discover Installation"
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

# Install Flatpak
print_status "Installing Flatpak..."
sudo pacman -S --needed --noconfirm flatpak

# Install Flatpak backend for Discover (Discover usually comes with KDE)
print_status "Installing Flatpak backend for Discover..."
sudo pacman -S --needed --noconfirm packagekit-qt6

# Install Discover if not already present (usually comes with KDE Plasma)
if ! command -v plasma-discover &> /dev/null; then
    print_status "Installing Discover store manager..."
    sudo pacman -S --needed --noconfirm discover
else
    print_status "Discover already installed"
fi

# Add Flathub repository
print_status "Adding Flathub repository..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo ""
echo "================================================"
print_status "Installation complete!"
echo "================================================"
echo ""
echo "Installed packages:"
echo "  - Flatpak"
echo "  - PackageKit Qt6 backend (Flatpak support for Discover)"
echo "  - Discover (if not already installed with KDE)"
echo "  - Flathub repository"
echo ""
print_warning "IMPORTANT: You may need to log out and log back in for Flatpak apps to appear in your application menu!"
echo ""
echo "Next steps:"
echo "  1. Log out and log back in (or reboot)"
echo "  2. Launch Discover from your application menu"
echo "  3. Browse and install Flatpak applications from Flathub"
echo ""
echo "Flatpak usage:"
echo "  - Search: flatpak search <app-name>"
echo "  - Install: flatpak install flathub <app-id>"
echo "  - Update: flatpak update"
echo "  - List installed: flatpak list"
echo ""
