#!/usr/bin/env bash
set -euo pipefail

# Sunshine installer with GPU-specific optional dependencies

if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is required to install packages." >&2
  exit 1
fi

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m" # No Color

TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(sudo -u "${TARGET_USER}" sh -c 'printf %s "$HOME"')"
AUTOSSH_START="/usr/local/bin/autossh-sunshine-start"
AUTOSSH_SERVICE="/etc/systemd/system/autossh-sunshine.service"
TARGET_UID="$(id -u "${TARGET_USER}")"

is_installed() {
  pacman -Qi "$1" >/dev/null 2>&1
}

ensure_package() {
  local pkg="$1"
  local desc="$2"
  if is_installed "${pkg}"; then
    printf "%b%s already installed.%b\n" "${GREEN}" "${desc}" "${NC}"
  else
    echo "Installing ${desc}..."
    sudo pacman -S --needed --noconfirm "${pkg}"
    printf "%bInstalled %s.%b\n" "${GREEN}" "${desc}" "${NC}"
  fi
}

service_enabled() {
  if systemctl is-enabled --quiet sunshine.service 2>/dev/null; then
    return 0
  fi
  sudo -u "${TARGET_USER}" systemctl --user is-enabled --quiet sunshine.service 2>/dev/null
}

has_system_unit() {
  systemctl list-unit-files sunshine.service >/dev/null 2>&1
}

has_user_unit() {
  sudo -u "${TARGET_USER}" XDG_RUNTIME_DIR="/run/user/${TARGET_UID}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${TARGET_UID}/bus" \
    systemctl --user list-unit-files sunshine.service >/dev/null 2>&1
}

ensure_user_unit_exists() {
  if has_user_unit; then
    return
  fi

  local unit_dir="${TARGET_HOME}/.config/systemd/user"
  local unit_path="${unit_dir}/sunshine.service"
  echo "Creating user systemd unit for Sunshine at ${unit_path}" >&2
  sudo -u "${TARGET_USER}" mkdir -p "${unit_dir}"
  sudo -u "${TARGET_USER}" tee "${unit_path}" >/dev/null <<'EOF'
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

has_sshd_unit() {
  systemctl list-unit-files sshd.service >/dev/null 2>&1
}

run_user_systemctl_enable() {
  sudo -u "${TARGET_USER}" XDG_RUNTIME_DIR="/run/user/${TARGET_UID}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${TARGET_UID}/bus" \
    systemctl --user enable --now sunshine.service
}

write_autossh_start_script() {
  echo "Creating ${AUTOSSH_START}" >&2
  sudo tee "${AUTOSSH_START}" >/dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail
ssh -i "${TARGET_HOME}/.ssh/id_rsa" "${TARGET_USER}@localhost" "${TARGET_HOME}/scripts/sunshine.sh"
EOF
  sudo chmod +x "${AUTOSSH_START}"
}

write_autossh_service_unit() {
  echo "Creating ${AUTOSSH_SERVICE}" >&2
  sudo tee "${AUTOSSH_SERVICE}" >/dev/null <<EOF
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
    printf "%bSkipping autossh service creation: sshd.service not present.%b\n" "${RED}" "${NC}" >&2
    return 1
  fi
  write_autossh_start_script
  write_autossh_service_unit
  sudo systemctl daemon-reload
  if sudo systemctl enable --now autossh-sunshine.service; then
    printf "%bCreated and enabled autossh-sunshine.service.%b\n" "${GREEN}" "${NC}"
    return 0
  fi
  printf "%bFailed to enable autossh-sunshine.service.%b\n" "${RED}" "${NC}" >&2
  return 1
}

prompt_gpu_choice() {
  echo "Select your GPU vendor for encoder dependencies:" >&2
  echo "  [1] Nvidia" >&2
  echo "  [2] AMD" >&2
  echo "  [3] Skip optional GPU deps" >&2
  read -r -p "Choice (1/2/3): " choice
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
      echo "Skipping optional GPU dependencies."
      ;;
    *)
      echo "Invalid choice. Aborting." >&2
      exit 1
      ;;
  esac
}

prompt_startup_enable() {
  echo "Enable Sunshine to start on boot?" >&2
  echo "  [y] Yes" >&2
  echo "  [n] No" >&2
  read -r -p "Choice (y/n): " choice
  case "${choice}" in
    y|Y) echo "yes" ;;
    n|N) echo "no" ;;
    *) echo "invalid" ;;
  esac
}

enable_startup() {
  echo "Enabling Sunshine systemd service..."

  if has_system_unit; then
    if sudo systemctl enable --now sunshine.service; then
      printf "%bSunshine system service enabled and started.%b\n" "${GREEN}" "${NC}"
      return
    fi
  fi

  if has_user_unit; then
    sudo loginctl enable-linger "${TARGET_USER}" >/dev/null 2>&1 || true
    if run_user_systemctl_enable; then
      printf "%bSunshine user service enabled and started for %s.%b\n" "${GREEN}" "${TARGET_USER}" "${NC}"
      return
    fi
  fi

  ensure_user_unit_exists
  sudo loginctl enable-linger "${TARGET_USER}" >/dev/null 2>&1 || true
  if run_user_systemctl_enable; then
    printf "%bSunshine user service enabled and started for %s.%b\n" "${GREEN}" "${TARGET_USER}" "${NC}"
    return
  fi

  if setup_autossh_service; then
    return
  fi

  printf "%bFailed to enable Sunshine service (unit not found).%b\n" "${RED}" "${NC}" >&2
  echo "Please check whether Sunshine installed a system or user service named sunshine.service, or adjust ${AUTOSSH_START}." >&2
  exit 1
}

main() {
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
      printf "%bSunshine service already enabled.%b\n" "${GREEN}" "${NC}"
    else
      enable_startup
    fi
  else
    echo "Skipping startup enable."
  fi
  echo "Done."
}

main "$@"
