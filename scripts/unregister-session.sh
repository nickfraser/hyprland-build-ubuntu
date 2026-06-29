#!/usr/bin/env bash

set -euo pipefail

SYSTEM_PREFIX=/usr/local

usage() {
  cat <<EOF
Usage: scripts/unregister-session.sh [--system-prefix <prefix>]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --system-prefix)
      SYSTEM_PREFIX=$2
      shift 2
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

remove_one() {
  local path=$1
  if [[ -e "${path}" || -L "${path}" ]]; then
    sudo rm -f "${path}"
  fi
}

remove_one "${SYSTEM_PREFIX}/share/wayland-sessions/hyprland.desktop"
remove_one "${SYSTEM_PREFIX}/share/dbus-1/services/org.freedesktop.impl.portal.desktop.hyprland.service"
remove_one "${SYSTEM_PREFIX}/share/xdg-desktop-portal/portals/hyprland.portal"
remove_one "${SYSTEM_PREFIX}/share/xdg-desktop-portal/hyprland-portals.conf"
remove_one "/etc/pam.d/hyprlock"
remove_one "${SYSTEM_PREFIX}/lib/systemd/user/hypridle.service"
remove_one "${SYSTEM_PREFIX}/lib/systemd/user/hyprpaper.service"
remove_one "${SYSTEM_PREFIX}/lib/systemd/user/xdg-desktop-portal-hyprland.service"

sudo systemctl --global disable hypridle.service hyprpaper.service xdg-desktop-portal-hyprland.service || true
sudo systemctl daemon-reload || true
