#!/usr/bin/env bash

set -euo pipefail

PREFIX=
SYSTEM_PREFIX=/usr/local
MODE=symlink
ENABLE_USER_UNITS=0

usage() {
  cat <<EOF
Usage: scripts/register-session.sh --prefix <prefix> [options]

Options:
  --system-prefix <prefix>     Destination prefix for shared registration files.
  --copy                       Copy files instead of symlinking them.
  --enable-user-units          Run systemctl --global enable for shipped units.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      PREFIX=$2
      shift 2
      ;;
    --system-prefix)
      SYSTEM_PREFIX=$2
      shift 2
      ;;
    --copy)
      MODE=copy
      shift
      ;;
    --enable-user-units)
      ENABLE_USER_UNITS=1
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

[[ -n "${PREFIX}" ]] || { usage >&2; exit 1; }

case "${PREFIX}" in
  /*) ;;
  *) printf 'prefix must be absolute: %s\n' "${PREFIX}" >&2; exit 1 ;;
esac

install_one() {
  local src=$1
  local dst=$2

  [[ -e "${src}" ]] || return 0
  sudo mkdir -p "$(dirname "${dst}")"

  if [[ "${MODE}" == copy ]]; then
    sudo cp -f "${src}" "${dst}"
  else
    sudo ln -sfn "${src}" "${dst}"
  fi
}

install_required() {
  local src=$1
  local dst=$2

  if [[ ! -e "${src}" ]]; then
    printf 'required file not found in prefix: %s\n' "${src}" >&2
    exit 1
  fi

  install_one "${src}" "${dst}"
}

install_optional() {
  local src=$1
  local dst=$2
  install_one "${src}" "${dst}"
}

install_required "${PREFIX}/share/wayland-sessions/hyprland.desktop" "${SYSTEM_PREFIX}/share/wayland-sessions/hyprland.desktop"
install_required "${PREFIX}/share/dbus-1/services/org.freedesktop.impl.portal.desktop.hyprland.service" "${SYSTEM_PREFIX}/share/dbus-1/services/org.freedesktop.impl.portal.desktop.hyprland.service"
install_required "${PREFIX}/share/xdg-desktop-portal/portals/hyprland.portal" "${SYSTEM_PREFIX}/share/xdg-desktop-portal/portals/hyprland.portal"
install_required "${PREFIX}/share/xdg-desktop-portal/hyprland-portals.conf" "${SYSTEM_PREFIX}/share/xdg-desktop-portal/hyprland-portals.conf"
install_required "${PREFIX}/etc/pam.d/hyprlock" "/etc/pam.d/hyprlock"
install_optional "${PREFIX}/lib/systemd/user/hypridle.service" "${SYSTEM_PREFIX}/lib/systemd/user/hypridle.service"
install_optional "${PREFIX}/lib/systemd/user/hyprpaper.service" "${SYSTEM_PREFIX}/lib/systemd/user/hyprpaper.service"
install_optional "${PREFIX}/lib/systemd/user/xdg-desktop-portal-hyprland.service" "${SYSTEM_PREFIX}/lib/systemd/user/xdg-desktop-portal-hyprland.service"

sudo systemctl daemon-reload || true

if [[ "${ENABLE_USER_UNITS}" == 1 ]]; then
  sudo systemctl --global daemon-reload || true
  sudo systemctl --global enable hypridle.service hyprpaper.service xdg-desktop-portal-hyprland.service || true
fi
