#!/usr/bin/env bash

set -euo pipefail

SYSTEM_PREFIX=/usr/local

usage() {
  cat <<EOF
Usage: scripts/unregister-session.sh [--system-prefix <prefix>]
EOF
}

require_arg() {
  local opt=$1
  [[ $# -ge 2 && -n "${2:-}" ]] || { printf '%s requires a value\n' "${opt}" >&2; usage >&2; exit 1; }
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --system-prefix)
      require_arg "$@"
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

case "${SYSTEM_PREFIX}" in
  /*) ;;
  *) printf 'system prefix must be absolute: %s\n' "${SYSTEM_PREFIX}" >&2; exit 1 ;;
esac

MANIFEST="${SYSTEM_PREFIX}/share/hyprland-build-ubuntu/registered-files"

is_registered() {
  local path=$1
  [[ -f "${MANIFEST}" ]] && grep -Fxq -- "${path}" "${MANIFEST}"
}

remove_one() {
  local path=$1
  if [[ -L "${path}" ]]; then
    sudo rm -f -- "${path}"
  elif [[ -e "${path}" ]] && is_registered "${path}"; then
    sudo rm -f -- "${path}"
  elif [[ -e "${path}" ]]; then
    printf 'skipping unowned registration file: %s\n' "${path}" >&2
  fi
}

# Disable user units BEFORE removing service files so systemctl can still find them
sudo systemctl --global disable hypridle.service hyprpaper.service xdg-desktop-portal-hyprland.service || true

remove_one "${SYSTEM_PREFIX}/share/wayland-sessions/hyprland.desktop"
remove_one "${SYSTEM_PREFIX}/share/dbus-1/services/org.freedesktop.impl.portal.desktop.hyprland.service"
remove_one "${SYSTEM_PREFIX}/share/xdg-desktop-portal/portals/hyprland.portal"
remove_one "${SYSTEM_PREFIX}/share/xdg-desktop-portal/hyprland-portals.conf"
remove_one "/etc/pam.d/hyprlock"
remove_one "${SYSTEM_PREFIX}/lib/systemd/user/hypridle.service"
remove_one "${SYSTEM_PREFIX}/lib/systemd/user/hyprpaper.service"
remove_one "${SYSTEM_PREFIX}/lib/systemd/user/xdg-desktop-portal-hyprland.service"

if [[ -f "${MANIFEST}" ]]; then
  sudo rm -f -- "${MANIFEST}"
  sudo rmdir --ignore-fail-on-non-empty "$(dirname "${MANIFEST}")" 2>/dev/null || true
fi

sudo systemctl --global daemon-reload || true
sudo systemctl daemon-reload || true
