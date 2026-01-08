# AIS - Arch Installation Scripts

A collection of scripts to automate package installation on fresh Arch Linux installations, specifically tailored for gaming setups.

## Features

This repository contains an installation script that automatically sets up your Arch Linux system with essential gaming packages:

- **Steam** - Gaming platform
- **Discord** - Communication platform
- **MangoHud** - Gaming overlay for monitoring FPS and system resources
- **Gamescope** - Gaming compositor
- **Wine Staging** - Windows compatibility layer (with Winetricks)
- **GameMode** - System optimization for gaming
- **ProtonUp-Qt** - Easy Proton version management
- **Vulkan Drivers** - Graphics API support (Intel, AMD, NVIDIA)
- **Audio Libraries** - PipeWire and PulseAudio support

## Usage

### Quick Install

Clone the repository and run the installation script:

```bash
git clone https://github.com/Nuxiqt/AIS.git
cd AIS
chmod +x install.sh
./install.sh
```

### What the Script Does

1. Enables the multilib repository (required for 32-bit support)
2. Updates your system with `pacman -Syu`
3. Installs all gaming-related packages
4. Installs required dependencies (Vulkan drivers, audio libraries, etc.)
5. Provides a summary of installed packages

### Requirements

- Fresh Arch Linux installation
- Internet connection
- Sudo privileges

### Notes

- The script will prompt for your sudo password when needed
- Do NOT run the script as root
- After installation, you may need to restart your system
- The script automatically enables multilib repository if not already enabled

## Customization

Feel free to edit `install.sh` to add or remove packages according to your needs. The script is designed to be easily modifiable.

## License

This is free and unencumbered software released into the public domain.
