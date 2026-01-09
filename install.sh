#!/bin/bash

# Arch Linux Gaming Setup Script
# Run with: bash install.sh

# Note: Script will continue even if individual packages fail to install

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
sudo pacman -Syu --noconfirm || print_warning "System update failed, continuing..."

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
sudo pacman -S --needed --noconfirm base-devel git || print_warning "Failed to install base-devel, continuing..."

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
    lib32-alsa-plugins || print_warning "Some Wine packages failed to install, continuing..."

# Verify Wine Staging installation
if command -v wine &> /dev/null; then
    wine_version=$(wine --version 2>&1)
    if echo "$wine_version" | grep -qi "staging"; then
        print_status "Wine Staging verified: $wine_version"
    else
        print_warning "Wine installed but not staging version: $wine_version"
    fi
fi

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
    obs-studio || print_warning "Some gaming packages failed to install, continuing..."

# Verify gaming packages installation
if command -v steam &> /dev/null; then
    print_status "Steam verified: $(pacman -Q steam 2>/dev/null || echo 'version unknown')"
fi
if command -v lutris &> /dev/null; then
    lutris_version=$(lutris --version 2>&1 | head -n1)
    print_status "Lutris verified: $lutris_version"
fi
if command -v gamescope &> /dev/null; then
    print_status "Gamescope verified: $(pacman -Q gamescope 2>/dev/null || echo 'version unknown')"
fi
if command -v mangohud &> /dev/null; then
    print_status "MangoHud verified: $(pacman -Q mangohud 2>/dev/null || echo 'version unknown')"
fi

# Discord client selection
echo ""
echo "Choose Discord client:"
echo "  1) Discord (official client) [default]"
echo "  2) Vesktop (modern Discord client with better features)"
echo "  3) Both"
echo "  4) Skip"
read -p "Enter your choice (1-4) [1]: " discord_choice
discord_choice=${discord_choice:-1}

case $discord_choice in
    1)
        print_status "Installing Discord (official)..."
        sudo pacman -S --needed --noconfirm discord || print_warning "Discord installation failed, continuing..."
        if command -v discord &> /dev/null; then
            print_status "Discord verified: $(pacman -Q discord 2>/dev/null || echo 'version unknown')"
        fi
        ;;
    2)
        print_status "Installing Vesktop..."
        yay -S --needed --noconfirm vesktop-bin || print_warning "Vesktop installation failed, continuing..."
        if command -v vesktop &> /dev/null; then
            print_status "Vesktop verified: $(pacman -Q vesktop-bin 2>/dev/null || echo 'installed')"
        fi
        ;;
    3)
        print_status "Installing both Discord and Vesktop..."
        sudo pacman -S --needed --noconfirm discord || print_warning "Discord installation failed, continuing..."
        yay -S --needed --noconfirm vesktop-bin || print_warning "Vesktop installation failed, continuing..."
        if command -v discord &> /dev/null; then
            print_status "Discord verified: $(pacman -Q discord 2>/dev/null || echo 'version unknown')"
        fi
        if command -v vesktop &> /dev/null; then
            print_status "Vesktop verified: $(pacman -Q vesktop-bin 2>/dev/null || echo 'installed')"
        fi
        ;;
    4)
        print_status "Skipping Discord installation"
        ;;
    *)
        print_warning "Invalid choice, installing Discord (default)"
        sudo pacman -S --needed --noconfirm discord || print_warning "Discord installation failed, continuing..."
        if command -v discord &> /dev/null; then
            print_status "Discord verified: $(pacman -Q discord 2>/dev/null || echo 'version unknown')"
        fi
        ;;
esac

# Install Waterfox
print_status "Installing Waterfox..."
yay -S --needed --noconfirm waterfox-bin || print_warning "Waterfox installation failed, continuing..."
if command -v waterfox &> /dev/null; then
    print_status "Waterfox verified: $(pacman -Q waterfox-bin 2>/dev/null || echo 'installed')"
fi

# Install ProtonUp-Qt
print_status "Installing ProtonUp-Qt..."
yay -S --needed --noconfirm protonup-qt || print_warning "ProtonUp-Qt installation failed, continuing..."
if command -v protonup-qt &> /dev/null; then
    print_status "ProtonUp-Qt verified: $(pacman -Q protonup-qt 2>/dev/null || echo 'installed')"
fi

# Install ProtonPlus
print_status "Installing ProtonPlus..."
yay -S --needed --noconfirm protonplus || print_warning "ProtonPlus installation failed, continuing..."
if pacman -Q protonplus &> /dev/null; then
    print_status "ProtonPlus verified: $(pacman -Q protonplus 2>/dev/null)"
fi

# Install protontricks
print_status "Installing protontricks..."
yay -S --needed --noconfirm protontricks || print_warning "protontricks installation failed, continuing..."
if command -v protontricks &> /dev/null; then
    protontricks_version=$(protontricks --version 2>&1 | head -n1)
    print_status "protontricks verified: $protontricks_version"
fi

# Install additional gaming compatibility libraries
print_status "Installing additional gaming libraries..."
sudo pacman -S --needed --noconfirm \
    lib32-vulkan-icd-loader \
    vulkan-icd-loader \
    vulkan-tools \
    lib32-mesa \
    mesa \
    mesa-utils \
    lib32-vkd3d \
    vkd3d \
    dxvk \
    lib32-opencl-icd-loader \
    opencl-icd-loader \
    opencl-mesa || print_warning "Some gaming libraries failed to install, continuing..."

# Verify graphics libraries
if command -v vulkaninfo &> /dev/null; then
    print_status "Vulkan tools verified: $(pacman -Q vulkan-tools 2>/dev/null || echo 'version unknown')"
fi
if command -v glxinfo &> /dev/null; then
    mesa_version=$(glxinfo 2>/dev/null | grep "OpenGL version" | head -n1 || echo "Mesa utilities installed")
    print_status "Mesa verified: $mesa_version"
fi
if pacman -Q mesa &> /dev/null; then
    print_status "Mesa package: $(pacman -Q mesa 2>/dev/null)"
fi
if pacman -Q dxvk &> /dev/null; then
    print_status "DXVK verified: $(pacman -Q dxvk 2>/dev/null)"
fi

# Optionally install NVIDIA utilities if NVIDIA GPU is detected
if lspci | grep -i nvidia &> /dev/null; then
    print_status "NVIDIA GPU detected, installing NVIDIA utilities..."
    sudo pacman -S --needed --noconfirm lib32-nvidia-utils nvidia-utils || print_warning "NVIDIA utilities installation failed, continuing..."
else
    print_status "No NVIDIA GPU detected, skipping NVIDIA utilities"
fi

# Optionally install AMD Radeon Vulkan drivers if AMD GPU is detected
if lspci | grep -i amd &> /dev/null || lspci | grep -i radeon &> /dev/null; then
    print_status "AMD GPU detected, installing AMD Vulkan drivers..."
    sudo pacman -S --needed --noconfirm vulkan-radeon lib32-vulkan-radeon || print_warning "AMD Vulkan drivers installation failed, continuing..."
else
    print_status "No AMD GPU detected, skipping AMD-specific Vulkan drivers"
fi

# Configure gamemode
print_status "Configuring gamemode..."
sudo usermod -aG gamemode $USER

# Create Wine prefix with staging
print_status "Creating Wine Staging prefix..."
WINEPREFIX=~/.wine-staging WINEARCH=win64 wineboot &> /dev/null || print_warning "Wine prefix creation encountered an issue, you may need to run it manually"

# Enable GameMode for Steam
print_status "Setting up Steam launch options helper..."
mkdir -p ~/.local/share/Steam
cat > ~/.local/share/Steam/steam_launch_options.txt << 'EOF'
# Add to your game launch options in Steam:
# For GameMode: gamemoderun %command%
# For MangoHud: mangohud %command%
# For both: gamemoderun mangohud %command%
# For Gamescope: gamescope -f -w 2560 -h 1440 -- %command%
EOF

print_status "Creating helpful aliases..."
if ! grep -q "# Gaming aliases" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'EOF'

# Gaming aliases
alias wine-staging='WINEPREFIX=~/.wine-staging wine'
alias winetricks-staging='WINEPREFIX=~/.wine-staging winetricks'
EOF
    print_status "Gaming aliases added to ~/.bashrc"
else
    print_status "Gaming aliases already exist in ~/.bashrc"
fi

echo ""
echo "================================================"
print_status "Installation complete!"
echo "================================================"
echo ""
echo "Installed packages:"
echo "  - Wine Staging (instead of regular Wine)"
echo "  - Steam"
echo "  - Discord client (based on your choice)"
echo "  - Waterfox"
echo "  - Lutris"
echo "  - protontricks"
echo "  - OBS Studio"
echo "  - ProtonUp-Qt"
echo "  - ProtonPlus"
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
