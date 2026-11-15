#!/usr/bin/env bash

# Arch Linux Gaming Setup Script
# Run with: bash install.sh

# Note: Script will continue even if individual packages fail to install

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

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root"
    exit 1
fi

print_header "Arch Linux Gaming Environment Setup"

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
if ! command -v yay &>/dev/null; then
    print_status "Installing yay AUR helper..."
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
else
    print_status "yay already installed"
fi

# Wine variant selection
echo ""
echo "Choose Wine variant:"
echo "  1) Wine Staging (latest patches and features) [default]"
echo "  2) Wine (stable upstream release)"
read -p "Enter your choice (1-2) [1]: " wine_choice
wine_choice=${wine_choice:-1}

case $wine_choice in
    2)
        WINE_PKG="wine"
        WINE_CONFLICT_PKG="wine-staging"
        WINE_NAME="Wine"
        WINE_PREFIX_DIR="$HOME/.wine"
        ;;
    *)
        if [ "$wine_choice" != "1" ]; then
            print_warning "Invalid choice, installing Wine Staging (default)"
        fi
        WINE_PKG="wine-staging"
        WINE_CONFLICT_PKG="wine"
        WINE_NAME="Wine Staging"
        WINE_PREFIX_DIR="$HOME/.wine-staging"
        ;;
esac

# wine and wine-staging conflict, so remove the one not chosen
if pacman -Qi "$WINE_CONFLICT_PKG" &>/dev/null; then
    print_status "Removing $WINE_CONFLICT_PKG package..."
    sudo pacman -Rns --noconfirm "$WINE_CONFLICT_PKG" || print_warning "Failed to remove $WINE_CONFLICT_PKG, continuing..."
fi

# Install chosen Wine variant
print_status "Installing $WINE_NAME and dependencies..."
sudo pacman -S --needed --noconfirm \
    "$WINE_PKG" \
    winetricks \
    lib32-gnutls \
    lib32-libldap \
    lib32-libgpg-error \
    lib32-sqlite \
    lib32-libpulse \
    lib32-alsa-plugins || print_warning "Some Wine packages failed to install, continuing..."

# Verify Wine installation
if pacman -Q "$WINE_PKG" &>/dev/null; then
    print_status "$WINE_NAME verified: $(wine --version 2>&1)"
else
    print_warning "$WINE_NAME package not found after installation"
fi

# GPU drivers go first: steam depends on (lib32-)vulkan-driver, and with --noconfirm
# pacman would otherwise pick the first provider (lib32-nvidia-utils) on AMD/Intel
# Only look at display controllers, so AMD/Intel chipsets and CPUs don't count as GPUs
gpu_list=$(lspci | grep -iE 'vga|3d|display' || true)

# Optionally install NVIDIA utilities if NVIDIA GPU is detected
# (OBS hardware encoding on NVIDIA uses NVENC from nvidia-utils)
if echo "$gpu_list" | grep -qi nvidia; then
    print_status "NVIDIA GPU detected, installing NVIDIA utilities..."
    sudo pacman -S --needed --noconfirm lib32-nvidia-utils nvidia-utils || print_warning "NVIDIA utilities installation failed, continuing..."
else
    print_status "No NVIDIA GPU detected, skipping NVIDIA utilities"
fi

# Optionally install AMD Radeon Vulkan drivers if AMD GPU is detected
# (VA-API hardware encoding for OBS is already provided by mesa)
if echo "$gpu_list" | grep -qiE 'amd|radeon'; then
    print_status "AMD GPU detected, installing AMD Vulkan drivers..."
    sudo pacman -S --needed --noconfirm vulkan-radeon lib32-vulkan-radeon || print_warning "AMD Vulkan drivers installation failed, continuing..."
else
    print_status "No AMD GPU detected, skipping AMD-specific Vulkan drivers"
fi

# Optionally install Intel Vulkan and VA-API drivers if Intel GPU is detected
# (intel-media-driver provides VA-API hardware encoding for OBS on recent Intel GPUs)
if echo "$gpu_list" | grep -qi intel; then
    print_status "Intel GPU detected, installing Intel Vulkan and VA-API drivers..."
    sudo pacman -S --needed --noconfirm vulkan-intel lib32-vulkan-intel intel-media-driver || print_warning "Intel drivers installation failed, continuing..."
else
    print_status "No Intel GPU detected, skipping Intel drivers"
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
if command -v steam &>/dev/null; then
    print_status "Steam verified: $(pacman -Q steam 2>/dev/null || echo 'version unknown')"
fi
if command -v lutris &>/dev/null; then
    lutris_version=$(lutris --version 2>&1 | head -n1)
    print_status "Lutris verified: $lutris_version"
fi
if command -v gamescope &>/dev/null; then
    print_status "Gamescope verified: $(pacman -Q gamescope 2>/dev/null || echo 'version unknown')"
fi
if command -v mangohud &>/dev/null; then
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
        if command -v discord &>/dev/null; then
            print_status "Discord verified: $(pacman -Q discord 2>/dev/null || echo 'version unknown')"
        fi
        ;;
    2)
        print_status "Installing Vesktop..."
        yay -S --needed --noconfirm vesktop-bin || print_warning "Vesktop installation failed, continuing..."
        if command -v vesktop &>/dev/null; then
            print_status "Vesktop verified: $(pacman -Q vesktop-bin 2>/dev/null || echo 'installed')"
        fi
        ;;
    3)
        print_status "Installing both Discord and Vesktop..."
        sudo pacman -S --needed --noconfirm discord || print_warning "Discord installation failed, continuing..."
        yay -S --needed --noconfirm vesktop-bin || print_warning "Vesktop installation failed, continuing..."
        if command -v discord &>/dev/null; then
            print_status "Discord verified: $(pacman -Q discord 2>/dev/null || echo 'version unknown')"
        fi
        if command -v vesktop &>/dev/null; then
            print_status "Vesktop verified: $(pacman -Q vesktop-bin 2>/dev/null || echo 'installed')"
        fi
        ;;
    4)
        print_status "Skipping Discord installation"
        ;;
    *)
        print_warning "Invalid choice, installing Discord (default)"
        sudo pacman -S --needed --noconfirm discord || print_warning "Discord installation failed, continuing..."
        if command -v discord &>/dev/null; then
            print_status "Discord verified: $(pacman -Q discord 2>/dev/null || echo 'version unknown')"
        fi
        ;;
esac

# Browser selection
install_waterfox() {
    print_status "Installing Waterfox..."
    yay -S --needed --noconfirm waterfox-bin || print_warning "Waterfox installation failed, continuing..."
    if command -v waterfox &>/dev/null; then
        print_status "Waterfox verified: $(pacman -Q waterfox-bin 2>/dev/null || echo 'installed')"
    fi
}

install_brave() {
    print_status "Installing Brave..."
    yay -S --needed --noconfirm brave-bin || print_warning "Brave installation failed, continuing..."
    if command -v brave &>/dev/null; then
        print_status "Brave verified: $(pacman -Q brave-bin 2>/dev/null || echo 'installed')"
    fi
}

install_firefox() {
    print_status "Installing Firefox..."
    sudo pacman -S --needed --noconfirm firefox || print_warning "Firefox installation failed, continuing..."
    if command -v firefox &>/dev/null; then
        print_status "Firefox verified: $(pacman -Q firefox 2>/dev/null || echo 'installed')"
    fi
}

echo ""
echo "Choose web browser(s) - enter one or more numbers, e.g. '1 3':"
echo "  1) Waterfox (privacy-focused Firefox fork) [default]"
echo "  2) Brave (privacy-focused Chromium-based browser)"
echo "  3) Firefox (official Arch package)"
echo "  4) All"
echo "  5) Skip"
read -p "Enter your choice(s) [1]: " browser_choice
browser_choice=${browser_choice:-1}

# Normalize choices: allow commas, expand "All", drop duplicates
browser_choice=${browser_choice//,/ }
case " $browser_choice " in
    *" 5 "*) browser_choice="" ;;
    *" 4 "*) browser_choice="1 2 3" ;;
esac

browsers_installed=()
for choice in $browser_choice; do
    case $choice in
        1) name="Waterfox" ;;
        2) name="Brave" ;;
        3) name="Firefox" ;;
        *)
            print_warning "Invalid browser choice '$choice', ignoring"
            continue
            ;;
    esac
    if [[ " ${browsers_installed[*]} " == *" $name "* ]]; then
        continue
    fi
    case $choice in
        1) install_waterfox ;;
        2) install_brave ;;
        3) install_firefox ;;
    esac
    browsers_installed+=("$name")
done

if [ ${#browsers_installed[@]} -eq 0 ]; then
    print_status "Skipping browser installation"
fi

# Proton version manager selection
install_protonup_qt() {
    print_status "Installing ProtonUp-Qt..."
    yay -S --needed --noconfirm protonup-qt || print_warning "ProtonUp-Qt installation failed, continuing..."
    if command -v protonup-qt &>/dev/null; then
        print_status "ProtonUp-Qt verified: $(pacman -Q protonup-qt 2>/dev/null || echo 'installed')"
    fi
}

install_protonplus() {
    print_status "Installing ProtonPlus..."
    yay -S --needed --noconfirm protonplus || print_warning "ProtonPlus installation failed, continuing..."
    if pacman -Q protonplus &>/dev/null; then
        print_status "ProtonPlus verified: $(pacman -Q protonplus 2>/dev/null)"
    fi
}

echo ""
echo "Choose Proton version manager (installs Proton-GE and other compatibility tools):"
echo "  1) ProtonUp-Qt (Qt app, supports Steam, Lutris, Heroic and more)"
echo "  2) ProtonPlus (GTK app, modern alternative)"
echo "  3) Both [default]"
echo "  4) Skip"
read -p "Enter your choice (1-4) [3]: " proton_choice
proton_choice=${proton_choice:-3}

proton_managers=()
case $proton_choice in
    1)
        install_protonup_qt
        proton_managers=("ProtonUp-Qt")
        ;;
    2)
        install_protonplus
        proton_managers=("ProtonPlus")
        ;;
    3)
        install_protonup_qt
        install_protonplus
        proton_managers=("ProtonUp-Qt" "ProtonPlus")
        ;;
    4)
        print_status "Skipping Proton version manager installation"
        ;;
    *)
        print_warning "Invalid choice, installing ProtonUp-Qt"
        install_protonup_qt
        proton_managers=("ProtonUp-Qt")
        ;;
esac

# Install protontricks
print_status "Installing protontricks..."
yay -S --needed --noconfirm protontricks || print_warning "protontricks installation failed, continuing..."
if command -v protontricks &>/dev/null; then
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
    opencl-mesa \
    libva-utils || print_warning "Some gaming libraries failed to install, continuing..."

# Verify graphics libraries
if command -v vulkaninfo &>/dev/null; then
    print_status "Vulkan tools verified: $(pacman -Q vulkan-tools 2>/dev/null || echo 'version unknown')"
fi
if command -v glxinfo &>/dev/null; then
    mesa_version=$(glxinfo 2>/dev/null | grep "OpenGL version" | head -n1 || echo "Mesa utilities installed")
    print_status "Mesa verified: $mesa_version"
fi
if pacman -Q mesa &>/dev/null; then
    print_status "Mesa package: $(pacman -Q mesa 2>/dev/null)"
fi
if pacman -Q dxvk &>/dev/null; then
    print_status "DXVK verified: $(pacman -Q dxvk 2>/dev/null)"
fi

# Check hardware video encoding for OBS (VA-API: AMD and Intel)
if command -v vainfo &>/dev/null; then
    vainfo_output=$(vainfo 2>/dev/null || true)
    if echo "$vainfo_output" | grep -q "VAEntrypointEncSlice"; then
        encoders=""
        echo "$vainfo_output" | grep -q "VAProfileH264.*VAEntrypointEncSlice" && encoders="$encoders H.264"
        echo "$vainfo_output" | grep -q "VAProfileHEVC.*VAEntrypointEncSlice" && encoders="$encoders HEVC"
        echo "$vainfo_output" | grep -q "VAProfileAV1.*VAEntrypointEncSlice" && encoders="$encoders AV1"
        print_status "VA-API hardware encoding available:$encoders"
        if ! echo "$vainfo_output" | grep -q "VAProfileAV1.*VAEntrypointEncSlice"; then
            print_warning "No AV1 hardware encoding (needs AMD RX 7000+, Intel Arc/Core Ultra or NVIDIA RTX 40+ with NVENC)"
        fi
    elif echo "$gpu_list" | grep -qi nvidia; then
        print_status "NVIDIA GPU: use NVENC encoders in OBS (AV1 needs RTX 40 series or newer)"
    else
        print_warning "No VA-API hardware encoding found, OBS will use software encoding"
    fi
fi

# Configure gamemode
print_status "Configuring gamemode..."
sudo usermod -aG gamemode $USER

# Create Wine prefix
print_status "Creating $WINE_NAME prefix at $WINE_PREFIX_DIR..."
WINEPREFIX="$WINE_PREFIX_DIR" WINEARCH=win64 wineboot &>/dev/null || print_warning "Wine prefix creation encountered an issue, you may need to run it manually"

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

# Staging uses its own prefix, so add aliases for it (plain wine uses ~/.wine by default)
if [ "$WINE_PKG" = "wine-staging" ]; then
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
fi

echo ""
print_header "Installation complete!"
echo ""
echo "Installed packages:"
echo "  - $WINE_NAME"
echo "  - Steam"
echo "  - Discord client (based on your choice)"
for browser in "${browsers_installed[@]}"; do
    echo "  - $browser"
done
echo "  - Lutris"
echo "  - protontricks"
echo "  - OBS Studio"
for manager in "${proton_managers[@]}"; do
    echo "  - $manager"
done
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
if [ ${#proton_managers[@]} -gt 0 ]; then
    echo "  3. Use ${proton_managers[0]} to install Proton-GE"
else
    echo "  3. Install Proton-GE manually or with a Proton version manager if needed"
fi
echo "  4. Check ~/.local/share/Steam/steam_launch_options.txt for launch options"
echo ""
echo "$WINE_NAME usage:"
if [ "$WINE_PKG" = "wine-staging" ]; then
    echo "  - Use 'wine-staging' command or set WINEPREFIX=~/.wine-staging"
else
    echo "  - Use 'wine' command (uses the default prefix)"
fi
echo "  - Prefix created at: $WINE_PREFIX_DIR"
echo ""
