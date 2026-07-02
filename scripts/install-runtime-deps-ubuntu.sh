#!/usr/bin/env bash

set -euo pipefail

DRY_RUN=0

usage() {
  cat <<EOF
Usage: scripts/install-runtime-deps-ubuntu.sh [--dry-run]

Installs the runtime dependencies needed by the Hyprland prefix-scoped
build on an Ubuntu 24.04 target machine.

Options:
  --dry-run    Preview the apt-get command without installing.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# Verify Ubuntu 24.04
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  if [[ "${ID:-}" != "ubuntu" ]] || [[ "${VERSION_ID:-}" != "24.04" ]]; then
    printf 'error: this script is designed for Ubuntu 24.04, detected %s %s\n' \
      "${ID:-unknown}" "${VERSION_ID:-unknown}" >&2
    exit 1
  fi
else
  printf 'error: /etc/os-release not found — cannot verify OS\n' >&2
  exit 1
fi

# Core runtime libraries derived from the build-time -dev packages
RUNTIME_PACKAGES=(
  libcairo2
  libdbusmenu-gtk3-4
  libdisplay-info1
  libdrm2
  libegl1
  libfmt9
  libgbm1
  libgl1
  libgles2
  libgtk-layer-shell0
  libgtkmm-3.0-1t64
  libheif1
  libiniparser1
  libinput10
  libjpeg-turbo8
  libjsoncpp25
  libjxl0.7
  liblcms2-2
  libmagic1t64
  libmtdev1t64
  libmuparser2v5
  libpango-1.0-0
  libpangocairo-1.0-0
  libpipewire-0.3-0t64
  libpixman-1-0
  libpng16-16t64
  libpugixml1v5
  libre2-10
  librsvg2-2
  librsvg2-common
  libsdbus-c++1
  libseat1
  libsigc++-2.0-0v5
  libspa-0.2-modules
  libspdlog1.12
  libsystemd0
  libtomlplusplus3t64
  libudev1
  libuuid1
  libwayland-client0
  libwayland-server0
  libwebp7
  libwacom9
  libxcb-composite0
  libxcb-icccm4
  libxcb-render0
  libxcb-res0
  libxcb-xfixes0
  libxcb1
  libxcursor1
  libxkbcommon0
  libxkbregistry0
  libzip4t64
)

# Qt6 runtime for hyprland-share-picker
QT6_PACKAGES=(
  libqt6core6t64
  libqt6dbus6t64
  libqt6gui6t64
  libqt6widgets6t64
)

# External services needed for portal functionality
PORTAL_PACKAGES=(
  xdg-desktop-portal
  xdg-desktop-portal-gtk
)

# PAM runtime
PAM_PACKAGES=(
  libpam0g
  libpam-runtime
)

ALL_PACKAGES=(
  "${RUNTIME_PACKAGES[@]}"
  "${QT6_PACKAGES[@]}"
  "${PORTAL_PACKAGES[@]}"
  "${PAM_PACKAGES[@]}"
)

printf 'Installing %d runtime packages for Ubuntu 24.04...\n' "${#ALL_PACKAGES[@]}"

if [[ "${DRY_RUN}" == 1 ]]; then
  printf 'Dry run — would execute:\n'
  printf '  sudo apt-get update\n'
  printf '  sudo apt-get install -y --no-install-recommends %s\n' \
    "${ALL_PACKAGES[*]}"
  exit 0
fi

sudo apt-get update
sudo apt-get install -y --no-install-recommends "${ALL_PACKAGES[@]}"

printf 'Runtime dependencies installed successfully.\n'