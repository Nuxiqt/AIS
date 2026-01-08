#!/bin/bash

# Arch Linux Post-Installation Script
# This script installs gaming-related packages including Steam, Discord, MangoHud, Gamescope, and Wine Staging

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if script is run as root
if [ "$EUID" -eq 0 ]; then 
    print_error "Please do not run this script as root. It will ask for sudo when needed."
    exit 1
fi

print_info "Starting Arch Linux gaming setup..."

# Enable multilib repository for 32-bit support
print_info "Enabling multilib repository..."
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    print_warn "Multilib repository not enabled. Enabling now..."
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    print_info "Multilib repository enabled"
else
    print_info "Multilib repository already enabled"
fi

# Update system
print_info "Updating system..."
sudo pacman -Syu --noconfirm

# Install base-devel if not already installed (needed for AUR helpers)
print_info "Checking for base-devel..."
if ! pacman -Qq base-devel &>/dev/null; then
    print_info "Installing base-devel..."
    sudo pacman -S --needed --noconfirm base-devel
else
    print_info "base-devel already installed"
fi

# Install git if not already installed
print_info "Checking for git..."
if ! pacman -Qq git &>/dev/null; then
    print_info "Installing git..."
    sudo pacman -S --needed --noconfirm git
else
    print_info "git already installed"
fi

# Install Steam
print_info "Installing Steam..."
sudo pacman -S --needed --noconfirm steam

# Install Discord
print_info "Installing Discord..."
sudo pacman -S --needed --noconfirm discord

# Install MangoHud
print_info "Installing MangoHud..."
sudo pacman -S --needed --noconfirm mangohud lib32-mangohud

# Install Gamescope
print_info "Installing Gamescope..."
sudo pacman -S --needed --noconfirm gamescope

# Install Wine Staging
print_info "Installing Wine Staging..."
sudo pacman -S --needed --noconfirm wine-staging winetricks

# Install additional gaming dependencies
print_info "Installing additional gaming dependencies..."
sudo pacman -S --needed --noconfirm \
    lib32-mesa \
    lib32-vulkan-icd-loader \
    lib32-vulkan-intel \
    lib32-vulkan-radeon \
    vulkan-icd-loader \
    vulkan-intel \
    vulkan-radeon \
    lib32-nvidia-utils \
    nvidia-utils \
    lib32-pipewire \
    pipewire \
    lib32-libpulse \
    libpulse

# Install gamemode for game performance optimization
print_info "Installing GameMode..."
sudo pacman -S --needed --noconfirm gamemode lib32-gamemode

# Install ProtonUp-Qt for easy Proton management
print_info "Installing ProtonUp-Qt..."
sudo pacman -S --needed --noconfirm protonup-qt

print_info "Installation complete!"
print_info ""
print_info "Installed packages:"
print_info "  - Steam"
print_info "  - Discord"
print_info "  - MangoHud (with 32-bit support)"
print_info "  - Gamescope"
print_info "  - Wine Staging (with Winetricks)"
print_info "  - GameMode (with 32-bit support)"
print_info "  - ProtonUp-Qt"
print_info "  - Vulkan drivers (Intel, AMD, NVIDIA)"
print_info "  - Audio libraries (PipeWire/PulseAudio)"
print_info ""
print_info "You may need to restart your system for all changes to take effect."
print_info "Enjoy gaming on Arch Linux!"
