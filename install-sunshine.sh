#!/usr/bin/env bash

# Sunshine Installation Script
# Installs Sunshine with GPU-specific optional dependencies
# Run with: bash install-sunshine.sh

set -euo pipefail

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

# Check if sudo is available
if ! command -v sudo &>/dev/null; then
    print_error "sudo is required to install packages"
    exit 1
fi

TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(sudo -u "${TARGET_USER}" sh -c 'printf %s "$HOME"')"
TARGET_UID="$(id -u "${TARGET_USER}")"
AUTOSSH_START="/usr/local/bin/autossh-sunshine-start"
AUTOSSH_SERVICE="/etc/systemd/system/autossh-sunshine.service"

is_installed() {
    pacman -Qi "$1" &>/dev/null
}

ensure_package() {
    local pkg="$1"
    local desc="$2"
    if is_installed "${pkg}"; then
        print_status "${desc} already installed"
    else
        print_status "Installing ${desc}..."
        sudo pacman -S --needed --noconfirm "${pkg}"
        print_status "Installed ${desc}"
    fi
}

run_user_systemctl() {
    sudo -u "${TARGET_USER}" \
        XDG_RUNTIME_DIR="/run/user/${TARGET_UID}" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${TARGET_UID}/bus" \
        systemctl --user "$@"
}

service_enabled() {
    if systemctl is-enabled --quiet sunshine.service 2>/dev/null; then
        return 0
    fi
    sudo -u "${TARGET_USER}" systemctl --user is-enabled --quiet sunshine.service 2>/dev/null
}

has_system_unit() {
    systemctl list-unit-files sunshine.service &>/dev/null
}

has_user_unit() {
    run_user_systemctl list-unit-files sunshine.service &>/dev/null
}

has_sshd_unit() {
    systemctl list-unit-files sshd.service &>/dev/null
}

ensure_user_unit_exists() {
    if has_user_unit; then
        return
    fi

    local unit_dir="${TARGET_HOME}/.config/systemd/user"
    local unit_path="${unit_dir}/sunshine.service"
    print_status "Creating user systemd unit for Sunshine at ${unit_path}..."
    sudo -u "${TARGET_USER}" mkdir -p "${unit_dir}"
    sudo -u "${TARGET_USER}" tee "${unit_path}" >/dev/null << 'EOF'
[Unit]
Description=Sunshine Game Streaming (user)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/sunshine
Restart=on-failure
RestartSec=2s

[Install]
WantedBy=default.target
EOF
}

write_autossh_start_script() {
    print_status "Creating ${AUTOSSH_START}..."
    sudo tee "${AUTOSSH_START}" >/dev/null << EOF
#!/usr/bin/env bash
set -euo pipefail
ssh -i "${TARGET_HOME}/.ssh/id_rsa" "${TARGET_USER}@localhost" "${TARGET_HOME}/scripts/sunshine.sh"
EOF
    sudo chmod +x "${AUTOSSH_START}"
}

write_autossh_service_unit() {
    print_status "Creating ${AUTOSSH_SERVICE}..."
    sudo tee "${AUTOSSH_SERVICE}" >/dev/null << EOF
[Unit]
Description=Start sunshine over a localhost SSH connection on boot
Requires=sshd.service
After=sshd.service

[Service]
ExecStartPre=/bin/sleep 5
ExecStart=${AUTOSSH_START}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
}

setup_autossh_service() {
    if ! has_sshd_unit; then
        print_warning "Skipping autossh service creation: sshd.service not present"
        return 1
    fi
    write_autossh_start_script
    write_autossh_service_unit
    sudo systemctl daemon-reload
    if sudo systemctl enable --now autossh-sunshine.service; then
        print_status "Created and enabled autossh-sunshine.service"
        return 0
    fi
    print_error "Failed to enable autossh-sunshine.service"
    return 1
}

# Prompt functions return their answer on stdout, so messages go to stderr
prompt_gpu_choice() {
    echo "" >&2
    echo "Select your GPU vendor for encoder dependencies:" >&2
    echo "  1) Nvidia" >&2
    echo "  2) AMD" >&2
    echo "  3) Skip optional GPU deps" >&2
    read -r -p "Enter your choice (1-3): " choice
    case "${choice}" in
        1) echo "nvidia" ;;
        2) echo "amd" ;;
        3) echo "skip" ;;
        *) echo "invalid" ;;
    esac
}

install_gpu_deps() {
    case "$1" in
        nvidia)
            ensure_package "cuda" "Nvidia CUDA encoder support"
            ;;
        amd)
            ensure_package "libva-mesa-driver" "AMD VA-API encoder support"
            ;;
        skip)
            print_status "Skipping optional GPU dependencies"
            ;;
        *)
            print_error "Invalid choice, aborting"
            exit 1
            ;;
    esac
}

prompt_startup_enable() {
    echo "" >&2
    echo "Enable Sunshine to start on boot?" >&2
    echo "  y) Yes" >&2
    echo "  n) No" >&2
    read -r -p "Enter your choice (y/n): " choice
    case "${choice}" in
        y|Y) echo "yes" ;;
        n|N) echo "no" ;;
        *) echo "invalid" ;;
    esac
}

enable_startup() {
    print_status "Enabling Sunshine systemd service..."

    if has_system_unit; then
        if sudo systemctl enable --now sunshine.service; then
            print_status "Sunshine system service enabled and started"
            return
        fi
    fi

    if has_user_unit; then
        sudo loginctl enable-linger "${TARGET_USER}" &>/dev/null || true
        if run_user_systemctl enable --now sunshine.service; then
            print_status "Sunshine user service enabled and started for ${TARGET_USER}"
            return
        fi
    fi

    ensure_user_unit_exists
    sudo loginctl enable-linger "${TARGET_USER}" &>/dev/null || true
    if run_user_systemctl enable --now sunshine.service; then
        print_status "Sunshine user service enabled and started for ${TARGET_USER}"
        return
    fi

    if setup_autossh_service; then
        return
    fi

    print_error "Failed to enable Sunshine service (unit not found)"
    print_error "Please check whether Sunshine installed a system or user service named sunshine.service, or adjust ${AUTOSSH_START}"
    exit 1
}

main() {
    print_header "Sunshine Installation"

    ensure_package "sunshine" "Sunshine"

    gpu_choice="invalid"
    while [ "${gpu_choice}" = "invalid" ]; do
        gpu_choice="$(prompt_gpu_choice)"
    done

    install_gpu_deps "${gpu_choice}"

    startup_choice="invalid"
    while [ "${startup_choice}" = "invalid" ]; do
        startup_choice="$(prompt_startup_enable)"
    done

    if [ "${startup_choice}" = "yes" ]; then
        if service_enabled; then
            print_status "Sunshine service already enabled"
        else
            enable_startup
        fi
    else
        print_status "Skipping startup enable"
    fi

    echo ""
    print_header "Installation complete!"
    echo ""
}

main "$@"
