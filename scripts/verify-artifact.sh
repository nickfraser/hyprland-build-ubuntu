#!/usr/bin/env bash

set -euo pipefail

ARTIFACT_ROOT=
PREFIX=
PROFILE_FILE=

usage() {
  cat <<EOF
Usage: scripts/verify-artifact.sh --artifact-root <dir> --prefix <prefix> [--profile-file <file>]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-root)
      ARTIFACT_ROOT=$2
      shift 2
      ;;
    --prefix)
      PREFIX=$2
      shift 2
      ;;
    --profile-file)
      PROFILE_FILE=$2
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

[[ -d "${ARTIFACT_ROOT}" ]] || { printf 'artifact root not found: %s\n' "${ARTIFACT_ROOT}" >&2; exit 1; }
[[ -n "${PREFIX}" ]] || { usage >&2; exit 1; }

case "${PREFIX}" in
  /*) ;;
  *) printf 'prefix must be absolute: %s\n' "${PREFIX}" >&2; exit 1 ;;
esac

PREFIX_ROOT="${ARTIFACT_ROOT}/${PREFIX#/}"

if [[ -z "${PROFILE_FILE}" ]] && [[ -f "${ARTIFACT_ROOT}/build-metadata/selected-profile.list" ]]; then
  PROFILE_FILE="${ARTIFACT_ROOT}/build-metadata/selected-profile.list"
fi

required_files=(
  "${PREFIX_ROOT}/bin/Hyprland"
  "${PREFIX_ROOT}/bin/hyprland-session"
  "${PREFIX_ROOT}/bin/hypridle"
  "${PREFIX_ROOT}/bin/hyprpaper"
  "${PREFIX_ROOT}/bin/hyprlock"
  "${PREFIX_ROOT}/libexec/xdg-desktop-portal-hyprland"
  "${PREFIX_ROOT}/share/wayland-sessions/hyprland.desktop"
  "${PREFIX_ROOT}/share/dbus-1/services/org.freedesktop.impl.portal.desktop.hyprland.service"
  "${PREFIX_ROOT}/share/xdg-desktop-portal/portals/hyprland.portal"
  "${PREFIX_ROOT}/etc/pam.d/hyprlock"
  "${ARTIFACT_ROOT}/build-metadata/build-info.txt"
)

if [[ -n "${PROFILE_FILE}" ]] && [[ -f "${PROFILE_FILE}" ]] && grep -qx 'waybar' "${PROFILE_FILE}"; then
  required_files+=("${PREFIX_ROOT}/bin/waybar")
fi

missing=0
for path in "${required_files[@]}"; do
  if [[ ! -e "${path}" ]]; then
    printf 'missing: %s\n' "${path}" >&2
    missing=1
  fi
done

exit "${missing}"
