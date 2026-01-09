# AIS - Arch Installation Scripts

A collection of scripts to automate package installation on fresh Arch Linux installations, specifically tailored for gaming setups.

## Scripts

- **install.sh** - Main gaming environment setup script
- **install-flatpak.sh** - Flatpak and Discover store manager setup
- **install-gaming-mouse.sh** - Gaming mouse configuration (ratbagd & Piper)

## Features

This repository contains an installation script that automatically sets up your Arch Linux system with essential gaming packages:

### Gaming Platforms
- **Steam** - Gaming platform
- **Lutris** - Open source gaming platform for Linux
- **Vesktop** or **Discord** - Discord client (user choice during installation)

### Gaming Tools
- **MangoHud** - Gaming overlay for monitoring FPS and system resources (with 32-bit support)
- **Gamescope** - Gaming compositor from Valve
- **GameMode** - System optimization for gaming (with 32-bit support)
- **ProtonUp-Qt** - Easy Proton-GE version management
- **Proton Plus** - Additional Proton compatibility tool
- **protontricks** - Winetricks wrapper for Proton games

### Windows Compatibility
- **Wine Staging** - Latest Wine with experimental features (replaces regular Wine)
- **Winetricks** - Wine configuration and dependency installer
- **DXVK** - Vulkan-based DirectX 9/10/11 implementation

### Additional Software
- **OBS Studio** - Streaming and recording software
- **Waterfox** - Privacy-focused web browser
- **yay** - AUR helper for easy package management

### Graphics & Compatibility Libraries
- Vulkan drivers and tools (Mesa, NVIDIA, `vulkan-tools`)
- VKD3D (DirectX 12 to Vulkan)
- OpenCL support
- Mesa tooling (`mesa-utils`) and OpenCL implementation (`opencl-mesa`)
- Additional Wine dependencies and 32-bit libraries

## Usage

### Quick Install - Gaming Setup

Clone the repository and run the installation script:

```bash
git clone https://github.com/Nuxiqt/AIS.git
cd AIS
chmod +x install.sh
./install.sh
```

### Flatpak and Discover Setup

To install Flatpak with Discover store manager:

```bash
chmod +x install-flatpak.sh
./install-flatpak.sh
```

### What the Script Does

1. Enables the multilib repository (required for 32-bit support)
2. Updates your system with `pacman -Syu`
3. Installs base-devel and git
4. Installs and configures yay (AUR helper)
5. Removes regular Wine and installs Wine Staging
6. Installs all gaming packages from official repos
7. Installs additional packages from AUR (Vesktop, Waterfox, ProtonUp-Qt)
8. Configures GameMode user group
9. Creates a Wine Staging prefix at ~/.wine-staging
10. Sets up helpful aliases and Steam launch options reference

### Post-Installation Steps

After the script completes:

1. **Log out and log back in** (required for GameMode group changes)
2. Run `steam` to set up Steam for the first time
3. Use ProtonUp-Qt to install Proton-GE for better game compatibility
4. Check `~/.local/share/Steam/steam_launch_options.txt` for Steam launch options examples

### Steam Launch Options

The script creates a helper file with examples. Common launch options:

- GameMode: `gamemoderun %command%`
- MangoHud: `mangohud %command%`
- Both: `gamemoderun mangohud %command%`
- Gamescope: `gamescope -f -w 1920 -h 1080 -- %command%`

### Wine Staging Usage

The script creates aliases for easy Wine Staging usage:

```bash
wine-staging <program.exe>         # Run with Wine Staging
winetricks-staging <package>       # Install dependencies
```

Or use the prefix directly:
```bash
WINEPREFIX=~/.wine-staging wine <program.exe>
```

### Requirements

- Fresh Arch Linux installation
- Internet connection
- Sudo privileges

### Notes

- The script will prompt for your sudo password when needed
- Do NOT run the script as root
- The script automatically removes regular Wine if installed (to avoid conflicts)
- Multilib repository is automatically enabled if not already set up
- The script installs packages from both official repos and AUR

## Customization

Feel free to edit `install.sh` to add or remove packages according to your needs. The script is designed to be easily modifiable.

## Installed Package List

- **Official Repos**: Steam, Lutris, Wine Staging, Winetricks, GameMode, MangoHud, Gamescope, OBS Studio, protontricks, DXVK, Vulkan drivers, Mesa, VKD3D
- **AUR**: yay, Vesktop, Waterfox, ProtonUp-Qt, Proton Plus
- **Mesa tools**: `mesa-utils`, `vulkan-tools`, `opencl-mesa`

## License

This is free and unencumbered software released into the public domain.
