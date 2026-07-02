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
  libwayland-cursor0
  libwayland-egl1
  libwayland-server0
  libwebp7
  libwacom9
  libxcb-composite0
  libxcb-icccm4
  libxcb-render0
  libxcb-res0
  libxcb-shm0
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

# GL dispatch libraries (separate from libegl1/libgl1 already listed)
GL_DISPATCH_PACKAGES=(
  libglx0
  libgldispatch0
  libopengl0
)

# X11 libraries (pulled transitively via Qt6 and GTK)
X11_PACKAGES=(
  libx11-6
  libxau6
  libxcomposite1
  libxdamage1
  libxdmcp6
  libxext6
  libxfixes3
  libxi6
  libxinerama1
  libxrandr2
  libxrender1
)

# GTK/Glib transitive dependencies (present on desktop installs, may be
# missing on minimal/server images)
GTK_TRANSITIVE_PACKAGES=(
  libatk1.0-0t64
  libatk-bridge2.0-0t64
  libatkmm-1.6-1v5
  libatspi2.0-0t64
  libblkid1
  libbrotli1
  libcairomm-1.0-1v5
  libdatrie1
  libdbus-1-3
  libdbusmenu-glib4
  libdouble-conversion3
  libepoxy0
  libevdev2
  libexpat1
  libffi8
  libfontconfig1
  libfreetype6
  libfribidi0
  libgdk-pixbuf-2.0-0
  libgdkmm-3.0-1t64
  libglib2.0-0t64
  libglibmm-2.4-1t64
  libgraphite2-3
  libgtk-3-0t64
  libgudev-1.0-0
  libharfbuzz0b
  libicu74
  libmount1t64
  libpangomm-1.4-1v5
  libpcre2-16-0
  libpcre2-8-0
  libthai0
  libxml2
)

# Core C/C++ runtime (almost always present, but listed for completeness)
CORE_RUNTIME_PACKAGES=(
  libc6
  libgcc-s1
  libgomp1
  libstdc++6
  libssl3t64
  zlib1g
  libzstd1
  liblz4-1
  liblzma5
  libbz2-1.0
  libselinux1
  libmd0
  libmd4c0
  libcap2
  libcap-ng0
  libaudit1
  libbsd0
  libgpg-error0
  libgcrypt20
  libsharpyuv0
  libb2-1
)

ALL_PACKAGES=(
  "${RUNTIME_PACKAGES[@]}"
  "${QT6_PACKAGES[@]}"
  "${PORTAL_PACKAGES[@]}"
  "${PAM_PACKAGES[@]}"
  "${GL_DISPATCH_PACKAGES[@]}"
  "${X11_PACKAGES[@]}"
  "${GTK_TRANSITIVE_PACKAGES[@]}"
  "${CORE_RUNTIME_PACKAGES[@]}"
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