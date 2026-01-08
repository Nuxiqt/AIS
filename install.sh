#!/bin/bash

# Arch Linux Gaming Setup Script
# Run with: bash setup_gaming.sh

set -e

echo "================================================"
echo "Arch Linux Gaming Environment Setup"
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

# Update system
print_status "Updating system..."
sudo pacman -Syu --noconfirm

# Enable multilib repository (required for 32-bit support)
print_status "Enabling multilib repository..."
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/s/^#//' /etc/pacman.conf
    sudo sed -i '/^\[multilib\]/{n;s/^#//}' /etc/pacman.conf
    sudo pacman -Sy
    print_status "Multilib repository enabled"
else
    print_status "Multilib already enabled"
fi

# Install base-devel if not present (needed for AUR)
print_status "Installing base-devel..."
sudo pacman -S --needed --noconfirm base-devel git

# Install yay (AUR helper) if not present
if ! command -v yay &> /dev/null; then
    print_status "Installing yay AUR helper..."
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
else
    print_status "yay already installed"
fi

# Remove regular wine if installed
if pacman -Qi wine &> /dev/null; then
    print_status "Removing regular wine package..."
    sudo pacman -Rns --noconfirm wine
fi

# Install Wine Staging
print_status "Installing Wine Staging and dependencies..."
sudo pacman -S --needed --noconfirm \
    wine-staging \
    winetricks \
    lib32-gnutls \
    lib32-libldap \
    lib32-libgpg-error \
    lib32-sqlite \
    lib32-libpulse \
    lib32-alsa-plugins

# Install gaming packages from official repos
print_status "Installing gaming packages from official repositories..."
sudo pacman -S --needed --noconfirm \
    steam \
    lutris \
    gamemode \
    lib32-gamemode \
    mangohud \
    lib32-mangohud \
    gamescope \
    obs-studio

# Install Discord (Vesktop from AUR)
print_status "Installing Vesktop (Discord client)..."
yay -S --needed --noconfirm vesktop-bin

# Install Waterfox
print_status "Installing Waterfox..."
yay -S --needed --noconfirm waterfox-g-bin

# Install ProtonUp-Qt
print_status "Installing ProtonUp-Qt..."
yay -S --needed --noconfirm protonup-qt

# Install protontricks
print_status "Installing protontricks..."
sudo pacman -S --needed --noconfirm protontricks

# Install additional gaming compatibility libraries
print_status "Installing additional gaming libraries..."
sudo pacman -S --needed --noconfirm \
    lib32-vulkan-icd-loader \
    vulkan-icd-loader \
    lib32-mesa \
    mesa \
    lib32-nvidia-utils \
    nvidia-utils \
    lib32-vkd3d \
    vkd3d \
    dxvk \
    lib32-opencl-icd-loader \
    opencl-icd-loader

# Install DXVK
print_status "Installing DXVK..."
sudo pacman -S --needed --noconfirm dxvk-bin || yay -S --needed --noconfirm dxvk-bin

# Configure gamemode
print_status "Configuring gamemode..."
sudo usermod -aG gamemode $USER

# Create Wine prefix with staging
print_status "Creating Wine Staging prefix..."
WINEPREFIX=~/.wine-staging WINEARCH=win64 wineboot

# Enable GameMode for Steam
print_status "Setting up Steam launch options helper..."
mkdir -p ~/.local/share/Steam
cat > ~/.local/share/Steam/steam_launch_options.txt << 'EOF'
# Add to your game launch options in Steam:
# For GameMode: gamemoderun %command%
# For MangoHud: mangohud %command%
# For both: gamemoderun mangohud %command%
# For Gamescope: gamescope -f -w 1920 -h 1080 -- %command%
EOF

print_status "Creating helpful aliases..."
cat >> ~/.bashrc << 'EOF'

# Gaming aliases
alias wine-staging='WINEPREFIX=~/.wine-staging wine'
alias winetricks-staging='WINEPREFIX=~/.wine-staging winetricks'
EOF

echo ""
echo "================================================"
print_status "Installation complete!"
echo "================================================"
echo ""
echo "Installed packages:"
echo "  - Wine Staging (instead of regular Wine)"
echo "  - Steam"
echo "  - Vesktop (Discord)"
echo "  - Waterfox"
echo "  - Lutris"
echo "  - protontricks"
echo "  - OBS Studio"
echo "  - ProtonUp-Qt"
echo "  - GameScope"
echo "  - MangoHud"
echo "  - GameMode"
echo "  - DXVK and compatibility layers"
echo ""
print_warning "IMPORTANT: You need to log out and log back in for group changes to take effect!"
echo ""
echo "Next steps:"
echo "  1. Log out and log back in"
echo "  2. Run 'steam' to set up Steam"
echo "  3. Use ProtonUp-Qt to install Proton-GE"
echo "  4. Check ~/.local/share/Steam/steam_launch_options.txt for launch options"
echo ""
echo "Wine Staging usage:"
echo "  - Use 'wine-staging' command or set WINEPREFIX=~/.wine-staging"
echo "  - Default prefix created at: ~/.wine-staging"
echo ""
