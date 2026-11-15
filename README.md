# AIS - Arch Installation Scripts

A collection of scripts to automate package installation on fresh Arch Linux installations, specifically tailored for gaming setups.

## Scripts

- **install.sh** - Main gaming environment setup script
- **install-flatpak.sh** - Flatpak and Discover store manager setup
- **sunshine/install-sunshine.sh** - Sunshine game streaming host (AUR) with GPU encoder deps; `--disable` to stop its services
- **gaming-mouse/install-gaming-mouse.sh** - Gaming mouse configuration: Piper (libratbag), plus rivalcfg for SteelSeries and Solaar for Logitech when detected
- **developer-install/install-dev.sh** - Developer tools: VS Code, Go, Python, Rust
- **gpu-control/install-gpu-control.sh** - LACT GPU control (fan curves, power, clocks), AMD tools and overclocking unlock
- **kde-settings/apply-kde-settings.sh** - Restore my personal KDE setup: custom keybinds, keyboard layouts, Arch logo on the application launcher, disabled volume audio feedback, and Konsole/Yakuake and VS Code shortcuts

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
- **ProtonUp-Qt** and/or **ProtonPlus** - Proton-GE version managers of your choice (both by default, or skip)
- **protontricks** - Winetricks wrapper for Proton games

### Windows Compatibility
- **Wine Staging** or **Wine** - your choice at install time (Staging is the default)
- **Winetricks** - Wine configuration and dependency installer
- **DXVK** - Vulkan-based DirectX 9/10/11 implementation

### Additional Software
- **OBS Studio** - Streaming and recording software (hardware H.264/HEVC/AV1 encoding via VA-API or NVENC)
- **Waterfox**, **Brave** and/or **Firefox** - web browsers of your choice (or skip)
- **yay** - AUR helper for easy package management

### Graphics & Compatibility Libraries
- Vulkan and VA-API drivers and tools (Mesa, NVIDIA, Intel, `vulkan-tools`, `libva-utils`)
- VKD3D (DirectX 12 to Vulkan)
- OpenCL support
- Mesa tooling (`mesa-utils`) and OpenCL implementation (`opencl-mesa`)
- Additional Wine dependencies and 32-bit libraries

## Installing Arch Linux with archinstall

AIS runs on an installed Arch system. The quickest way to get one is `archinstall`, the official
guided installer that ships on the Arch ISO. It is a text menu (arrow keys + Enter), not a GUI.

### 1. Make the USB stick

Download the ISO and its checksum from [archlinux.org/download](https://archlinux.org/download/), then verify it:

```bash
sha256sum archlinux-x86_64.iso   # must match the line for archlinux-x86_64.iso in sha256sums.txt
```

Find the USB stick (check SIZE, TRAN=usb and MODEL, everything on it will be erased):

```bash
lsblk -o NAME,SIZE,TRAN,MODEL,LABEL
```

Write the ISO to the whole device (e.g. `/dev/sdX`, not a partition like `/dev/sdX1`):

```bash
sudo umount /dev/sdX?* 2>/dev/null
sudo dd if=archlinux-x86_64.iso of=/dev/sdX bs=4M oflag=direct conv=fsync status=progress
```

### 2. Boot the USB

- Boot from the stick (boot menu key is usually F12, F11, F8 or Del) and pick *Arch Linux install medium*
- If it doesn't boot, disable Secure Boot in the BIOS
- Ethernet works automatically. For Wi-Fi:

```bash
iwctl
station list                        # find your device, e.g. wlan0
station wlan0 connect "Your SSID"   # asks for the password
exit
ping -c 3 archlinux.org
```

### 3. Run archinstall

```bash
archinstall
```

Go through the menu entries (names as in archinstall 4.5) and pick:

| Menu entry | Recommended choice |
| --- | --- |
| Locales | Keyboard layout, language (e.g. `en_US.UTF-8`) |
| Mirrors and repositories | Your region as mirror region, and enable the **multilib** repository (needed for Steam/Wine) |
| Disk configuration | *Use a best-effort default partition layout*, pick the target disk (**double-check it**), filesystem `ext4` (or `btrfs` if you want snapshots) |
| Swap | Enabled (zram) |
| Bootloader | `systemd-boot` (UEFI) or `grub` (legacy BIOS) |
| Kernels | `linux` (add `linux-lts` as a fallback if you like) |
| Hostname | Name of your choice |
| Authentication | Set a root password and add your user as **superuser** (sudo) |
| Profile | *Desktop* → *KDE Plasma*, graphics driver for your GPU (*AMD / ATI (open-source)*, *Intel (open-source)* or *Nvidia (open kernel module…)* for RTX 20 series and newer), greeter as suggested |
| Applications | Audio: `pipewire`, Bluetooth: enable if you have it |
| Network configuration | *Use NetworkManager* |
| Additional packages | `git` (to clone AIS) |
| Timezone | Your timezone |

Then choose **Install**, wait for it to finish, and reboot (remove the USB stick).

> Tip: *Save configuration* writes your choices to a JSON file, which you can reuse on the next
> install with `archinstall --config user_configuration.json`.

### 4. Run AIS

Log in to Plasma, open Konsole and run the scripts you need:

```bash
git clone https://github.com/Nuxiqt/AIS.git
cd AIS
bash install.sh                                  # gaming setup (also installs yay and the 32-bit GPU drivers Steam needs)
bash install-flatpak.sh                          # optional: Flatpak + Discover
bash developer-install/install-dev.sh            # optional: VS Code, Go, Python, Rust
bash kde-settings/apply-kde-settings.sh apply    # optional: my KDE, Konsole and VS Code shortcuts (run after install-dev.sh)
```

Log out and back in afterwards. The other scripts (GPU control, Sunshine, gaming mouse, Steam Remote Play,
`gaming-comp.sh`) can be run any time later.

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

### KDE Settings (personal keybinds, keyboard layouts, launcher icon, audio feedback)

> **Note:** `kde-settings/settings.conf` contains my **personal/custom keybinds** and preferences,
> not KDE defaults. Review it before applying, or run `export` on your own machine to replace it with yours.

Saved settings live in `kde-settings/settings.conf`. On a new Plasma install, apply them
(current config is backed up to `~/.local/share/ais-backups/` first), then log out and back in. The launcher icon is set through the running Plasma session, so run
`apply` from inside Plasma (if run before the first login, re-run it after logging in):

```bash
bash kde-settings/apply-kde-settings.sh apply
```

It also restores app shortcuts:

- **Konsole** (and Yakuake, which uses Konsole) - custom shortcuts such as copy/paste, saved as `@kxmlgui` lines in `settings.conf`
- **VS Code** - `kde-settings/vscode-keybindings.json`, copied to every installed build (VS Code, Code - OSS, VSCodium).
  If VS Code isn't installed yet, run `developer-install/install-dev.sh` first and re-run `apply`

After changing shortcuts or layouts, refresh the saved settings from your current machine:

```bash
bash kde-settings/apply-kde-settings.sh export
```

### Developer Tools (VS Code, Go, Python, Rust)

```bash
bash developer-install/install-dev.sh
```

Pick any combination (default: all). Every install is confirmed first:

- **VS Code** - Microsoft build (AUR, default), Code - OSS (official repo) or VSCodium (AUR)
- **Go** - `go`, `gopls` language server, `delve` debugger
- **Python** - `python-pip` (for virtualenvs), `python-pipx`, `uv`
- **Rust** - `rustup` with the stable toolchain and `rust-analyzer` (offers to replace the `rust` package, which conflicts)

Optionally adds `~/go/bin`, `~/.local/bin` and `~/.cargo/bin` to PATH in your shell config
(`~/.zshrc` or `~/.bashrc`), backing it up to `~/.local/share/ais-backups/` first.

### GPU Control (LACT, AMD overclocking)

```bash
bash gpu-control/install-gpu-control.sh            # install
bash gpu-control/install-gpu-control.sh --revert   # disable lactd, remove overclocking unlock
```

- **LACT** - GUI for fan curves, power limits, clocks and undervolting (AMD, NVIDIA, Intel);
  enables the `lactd` service, which applies your settings at boot
- **AMD only:** `amdgpu_top` monitor, and optional overclocking unlock
  (`options amdgpu ppfeaturemask=0xffffffff` in `/etc/modprobe.d/99-amdgpu-overdrive.conf`,
  then rebuilds the initramfs; reboot required). Skipped if overdrive is already enabled,
  e.g. via the kernel command line

Every change is confirmed first. Overclocking and undervolting are at your own risk.

### What the Script Does

1. Enables the multilib repository (required for 32-bit support)
2. Updates your system with `pacman -Syu`
3. Installs base-devel and git
4. Installs and configures yay (AUR helper)
5. Asks whether to install Wine Staging (default) or stable Wine, removing the other if present
6. Detects your GPU and installs its Vulkan drivers, including the 32-bit ones (before Steam, so pacman doesn't pick another GPU's driver)
7. Installs all gaming packages from official repos
8. Installs additional packages from AUR (Vesktop, Waterfox/Brave, ProtonUp-Qt/ProtonPlus)
9. Configures GameMode user group
10. Creates a Wine prefix (`~/.wine-staging` for Staging, `~/.wine` for stable Wine)
11. Sets up helpful aliases and Steam launch options reference

### Post-Installation Steps

After the script completes:

1. **Log out and log back in** (required for GameMode group changes)
2. Run `steam` to set up Steam for the first time
3. Use ProtonUp-Qt or ProtonPlus to install Proton-GE for better game compatibility
4. Check `~/.local/share/Steam/steam_launch_options.txt` for Steam launch options examples

### Steam Launch Options

The script creates a helper file with examples. Common launch options:

- GameMode: `gamemoderun %command%`
- MangoHud: `mangohud %command%`
- Both: `gamemoderun mangohud %command%`
- Gamescope: `gamescope -f -w 1920 -h 1080 -- %command%`

### Wine Usage

If you chose stable Wine, use `wine` as usual (default prefix `~/.wine`).

If you chose Wine Staging, the script creates aliases for it:

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

- **Official Repos**: Steam, Firefox (optional), Lutris, Wine Staging or Wine, Winetricks, GameMode, MangoHud, Gamescope, OBS Studio, protontricks, DXVK, Vulkan drivers, Mesa, VKD3D
- **AUR**: yay, Vesktop, Waterfox, Brave, ProtonUp-Qt, ProtonPlus
- **Mesa tools**: `mesa-utils`, `vulkan-tools`, `opencl-mesa`, `libva-utils`

## License

This is free and unencumbered software released into the public domain.
