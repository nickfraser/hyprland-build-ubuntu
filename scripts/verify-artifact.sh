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

require_arg() {
  local opt=$1
  [[ $# -ge 2 && -n "${2:-}" ]] || { printf '%s requires a value\n' "${opt}" >&2; usage >&2; exit 1; }
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-root)
      require_arg "$@"
      ARTIFACT_ROOT=$2
      shift 2
      ;;
    --prefix)
      require_arg "$@"
      PREFIX=$2
      shift 2
      ;;
    --profile-file)
      require_arg "$@"
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
METADATA_PROFILE="${ARTIFACT_ROOT}/build-metadata/selected-profile.list"

if [[ -f "${METADATA_PROFILE}" ]]; then
  if [[ -n "${PROFILE_FILE}" && -f "${PROFILE_FILE}" ]] && ! cmp -s "${PROFILE_FILE}" "${METADATA_PROFILE}"; then
    printf 'profile file does not match artifact metadata: %s\n' "${PROFILE_FILE}" >&2
    exit 1
  fi
  PROFILE_FILE="${METADATA_PROFILE}"
fi

profile_contains() {
  local component=$1
  [[ -n "${PROFILE_FILE}" && -f "${PROFILE_FILE}" ]] && grep -Eq "^[[:space:]]*${component}([[:space:]]*(#.*)?)?$" "${PROFILE_FILE}"
}

required_files=(
  "${PREFIX_ROOT}/share/wayland-sessions/hyprland.desktop"
  "${PREFIX_ROOT}/share/dbus-1/services/org.freedesktop.impl.portal.desktop.hyprland.service"
  "${PREFIX_ROOT}/share/xdg-desktop-portal/portals/hyprland.portal"
  "${PREFIX_ROOT}/share/xdg-desktop-portal/hyprland-portals.conf"
  "${PREFIX_ROOT}/etc/pam.d/hyprlock"
  "${ARTIFACT_ROOT}/build-metadata/build-info.txt"
  "${ARTIFACT_ROOT}/build-metadata/runtime-deps.txt"
  "${ARTIFACT_ROOT}/build-metadata/selected-profile.list"
  "${ARTIFACT_ROOT}/build-metadata/selected-versions.env"
)

required_executables=(
  "${PREFIX_ROOT}/bin/Hyprland"
  "${PREFIX_ROOT}/bin/hypridle"
  "${PREFIX_ROOT}/bin/hyprpaper"
  "${PREFIX_ROOT}/bin/hyprlock"
  "${PREFIX_ROOT}/bin/hyprland-env"
  "${PREFIX_ROOT}/bin/hyprland-session"
  "${PREFIX_ROOT}/bin/hypridle-session"
  "${PREFIX_ROOT}/bin/hyprpaper-session"
  "${PREFIX_ROOT}/bin/xdg-desktop-portal-hyprland-session"
  "${PREFIX_ROOT}/libexec/xdg-desktop-portal-hyprland"
)

if profile_contains waybar; then
  required_executables+=("${PREFIX_ROOT}/bin/waybar")
fi

missing=0
for path in "${required_files[@]}"; do
  if [[ ! -e "${path}" ]]; then
    printf 'missing: %s\n' "${path}" >&2
    missing=1
  fi
done

for path in "${required_executables[@]}"; do
  if [[ ! -x "${path}" ]]; then
    printf 'missing executable: %s\n' "${path}" >&2
    missing=1
  fi
done

exit "${missing}"
