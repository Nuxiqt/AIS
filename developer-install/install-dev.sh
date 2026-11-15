#!/usr/bin/env bash

# Developer Tools Installation Script
# Installs VS Code, Go, Python and Rust development environments
# Every system change is confirmed first; shell config is backed up before editing
# Run with: bash install-dev.sh

set -euo pipefail

BACKUP_DIR="$HOME/.local/share/ais-backups/dev-$(date +%Y%m%d-%H%M%S)"
PATH_MARKER="# Developer tools PATH (AIS developer-install)"

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

# Ask a yes/no question, default No
confirm() {
    local answer
    read -r -p "$1 [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

# Install official repo packages that are missing, after confirmation
install_packages() {
    local desc="$1"
    shift
    local missing=()
    for pkg in "$@"; do
        pacman -Q "$pkg" &>/dev/null || missing+=("$pkg")
    done

    if [ ${#missing[@]} -eq 0 ]; then
        print_status "$desc already installed: $*"
        return 0
    fi

    if confirm "Install $desc packages: ${missing[*]}?"; then
        sudo pacman -S --needed --noconfirm "${missing[@]}" || {
            print_warning "$desc installation failed, continuing..."
            return 1
        }
    else
        print_warning "Skipping $desc"
        return 1
    fi
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root"
    exit 1
fi

print_header "Developer Tools Installation"

# Component selection
echo ""
echo "Choose what to install - enter one or more numbers, e.g. '1 3':"
echo "  1) VS Code"
echo "  2) Go (go, gopls, delve)"
echo "  3) Python (pip, pipx, uv)"
echo "  4) Rust (rustup, stable toolchain, rust-analyzer)"
echo "  5) All [default]"
echo "  6) Skip"
read -r -p "Enter your choice(s) [5]: " dev_choice
dev_choice=${dev_choice:-5}
dev_choice=${dev_choice//,/ }
case " $dev_choice " in
    *" 6 "*) dev_choice="" ;;
    *" 5 "*) dev_choice="1 2 3 4" ;;
esac

installed=()
path_dirs=()

install_vscode() {
    echo ""
    echo "Choose VS Code build:"
    echo "  1) Visual Studio Code (Microsoft build, official marketplace, AUR) [default]"
    echo "  2) Code - OSS (Arch official repo, Open VSX marketplace)"
    echo "  3) VSCodium (telemetry-free build, Open VSX marketplace, AUR)"
    local choice pkg name source
    read -r -p "Enter your choice (1-3) [1]: " choice
    case "${choice:-1}" in
        2) pkg="code"; name="Code - OSS"; source="repo" ;;
        3) pkg="vscodium-bin"; name="VSCodium"; source="aur" ;;
        *) pkg="visual-studio-code-bin"; name="Visual Studio Code"; source="aur" ;;
    esac

    if pacman -Q "$pkg" &>/dev/null; then
        print_status "$name already installed: $(pacman -Q "$pkg")"
        installed+=("$name")
        return
    fi

    if [ "$source" = "aur" ]; then
        if ! command -v yay &>/dev/null; then
            print_warning "yay is required for $name from the AUR (run install.sh first), skipping"
            return
        fi
        if confirm "Install $pkg from the AUR?"; then
            yay -S --needed "$pkg" || { print_warning "$name installation failed, continuing..."; return; }
        else
            print_warning "Skipping $name"
            return
        fi
    else
        install_packages "$name" "$pkg" || return 0
    fi
    installed+=("$name")
}

install_go() {
    echo ""
    print_status "Go: compiler, gopls (language server), delve (debugger)"
    install_packages "Go" go gopls delve || return 0
    print_status "Go verified: $(go version 2>/dev/null || echo 'installed')"
    installed+=("Go")
    path_dirs+=("\$HOME/go/bin")
}

install_python() {
    echo ""
    print_status "Python: pip (for virtualenvs), pipx (CLI apps), uv (fast package/project manager)"
    print_status "Note: Arch blocks system-wide 'pip install'; use venvs, pipx or uv instead"
    install_packages "Python" python python-pip python-pipx uv || return 0
    print_status "Python verified: $(python --version 2>/dev/null || echo 'installed')"
    installed+=("Python")
    path_dirs+=("\$HOME/.local/bin")
}

install_rust() {
    echo ""
    print_status "Rust: rustup (toolchain manager), stable toolchain, rust-analyzer"

    if ! pacman -Q rustup &>/dev/null; then
        # rustup conflicts with the distro rust package
        if pacman -Q rust &>/dev/null; then
            print_warning "The 'rust' package is installed and conflicts with rustup"
            echo "rustup manages toolchains per user (stable/nightly, targets, components)."
            if ! confirm "Replace 'rust' with 'rustup'?"; then
                print_warning "Keeping the 'rust' package, skipping rustup"
                installed+=("Rust (distro package)")
                return
            fi
            # Swap in one go; if rustup fails to install, put rust back
            sudo pacman -Rdd --noconfirm rust
            if ! sudo pacman -S --needed --noconfirm rustup; then
                print_warning "rustup installation failed, reinstalling 'rust'"
                sudo pacman -S --needed --noconfirm rust || true
                return 0
            fi
        else
            install_packages "Rust" rustup || return 0
        fi
    else
        print_status "rustup already installed: $(pacman -Q rustup)"
    fi

    if ! rustup toolchain list 2>/dev/null | grep -q '^stable'; then
        if confirm "Install the Rust stable toolchain (downloads to ~/.rustup)?"; then
            rustup default stable
        else
            print_warning "No toolchain installed; run 'rustup default stable' later"
            installed+=("Rust (rustup, no toolchain)")
            return
        fi
    else
        print_status "Rust stable toolchain already installed"
    fi

    if ! rustup component list --installed 2>/dev/null | grep -q '^rust-analyzer'; then
        rustup component add rust-analyzer || print_warning "rust-analyzer installation failed, continuing..."
    fi

    print_status "Rust verified: $(rustc --version 2>/dev/null || echo 'installed')"
    installed+=("Rust")
    path_dirs+=("\$HOME/.cargo/bin")
}

# Add tool bin directories (go install, pipx/uv tools, cargo install) to PATH
configure_path() {
    [ ${#path_dirs[@]} -eq 0 ] && return

    local rc_file
    case "$(basename "${SHELL:-bash}")" in
        zsh) rc_file="$HOME/.zshrc" ;;
        *) rc_file="$HOME/.bashrc" ;;
    esac

    if grep -qF "$PATH_MARKER" "$rc_file" 2>/dev/null; then
        print_status "PATH block already present in $rc_file"
        return
    fi

    echo ""
    echo "Add these to PATH in $rc_file (for 'go install', pipx/uv and 'cargo install' tools)?"
    for dir in "${path_dirs[@]}"; do
        echo "  - $dir"
    done
    if ! confirm "Update $rc_file?"; then
        print_warning "Skipping PATH setup"
        return
    fi

    if [ -f "$rc_file" ]; then
        mkdir -p "$BACKUP_DIR"
        cp -a "$rc_file" "$BACKUP_DIR/"
        print_status "Backed up $rc_file to $BACKUP_DIR"
    fi

    {
        echo ""
        echo "$PATH_MARKER"
        for dir in "${path_dirs[@]}"; do
            echo "[[ \":\$PATH:\" == *\":$dir:\"* ]] || export PATH=\"$dir:\$PATH\""
        done
    } >> "$rc_file"
    print_status "PATH updated in $rc_file"
}

for choice in $dev_choice; do
    case $choice in
        1) install_vscode ;;
        2) install_go ;;
        3) install_python ;;
        4) install_rust ;;
        *) print_warning "Invalid choice '$choice', ignoring" ;;
    esac
done

configure_path

echo ""
print_header "Installation complete!"
echo ""
if [ ${#installed[@]} -gt 0 ]; then
    echo "Installed:"
    for item in "${installed[@]}"; do
        echo "  - $item"
    done
else
    echo "Nothing was installed."
fi
echo ""
if [ ${#path_dirs[@]} -gt 0 ]; then
    print_warning "Open a new terminal (or source your shell config) for PATH changes to apply"
    echo ""
fi
if [ -d "$BACKUP_DIR" ]; then
    echo "Backup of previous shell config: $BACKUP_DIR"
    echo ""
fi
