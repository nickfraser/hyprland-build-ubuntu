#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
readonly REPO_ROOT=$(dirname "${SCRIPT_DIR}")

PREFIX=${PREFIX:?PREFIX is required}
SRC_ROOT=${SRC_ROOT:-/sources}
BUILD_ROOT=${BUILD_ROOT:-/build}
PREFIX_DIR="${PREFIX}"

case "${PREFIX}" in
  /*) ;;
  *) printf 'error: PREFIX must be an absolute path: %s\n' "${PREFIX}" >&2; exit 1 ;;
esac

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

log() {
  printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

component_repo() {
  case "$1" in
    hyprutils) printf '%s\n' 'https://github.com/hyprwm/hyprutils.git' ;;
    hyprlang) printf '%s\n' 'https://github.com/hyprwm/hyprlang.git' ;;
    hyprcursor) printf '%s\n' 'https://github.com/hyprwm/hyprcursor.git' ;;
    hyprgraphics) printf '%s\n' 'https://github.com/hyprwm/hyprgraphics.git' ;;
    hyprwayland-scanner) printf '%s\n' 'https://github.com/hyprwm/hyprwayland-scanner.git' ;;
    hyprland-protocols) printf '%s\n' 'https://github.com/hyprwm/hyprland-protocols.git' ;;
    aquamarine) printf '%s\n' 'https://github.com/hyprwm/aquamarine.git' ;;
    hyprwire) printf '%s\n' 'https://github.com/hyprwm/hyprwire.git' ;;
    hyprtoolkit) printf '%s\n' 'https://github.com/hyprwm/hyprtoolkit.git' ;;
    hyprland) printf '%s\n' 'https://github.com/hyprwm/Hyprland.git' ;;
    xdg-desktop-portal-hyprland) printf '%s\n' 'https://github.com/hyprwm/xdg-desktop-portal-hyprland.git' ;;
    hyprlock) printf '%s\n' 'https://github.com/hyprwm/hyprlock.git' ;;
    hypridle) printf '%s\n' 'https://github.com/hyprwm/hypridle.git' ;;
    hyprpaper) printf '%s\n' 'https://github.com/hyprwm/hyprpaper.git' ;;
    waybar) printf '%s\n' 'https://github.com/Alexays/Waybar.git' ;;
    *) die "unknown component '$1'" ;;
  esac
}

component_ref() {
  case "$1" in
    hyprutils) printf '%s\n' "${HYPRUTILS_REF}" ;;
    hyprlang) printf '%s\n' "${HYPRLANG_REF}" ;;
    hyprcursor) printf '%s\n' "${HYPRCURSOR_REF}" ;;
    hyprgraphics) printf '%s\n' "${HYPRGRAPHICS_REF}" ;;
    hyprwayland-scanner) printf '%s\n' "${HYPRWAYLAND_SCANNER_REF}" ;;
    hyprland-protocols) printf '%s\n' "${HYPRLAND_PROTOCOLS_REF}" ;;
    aquamarine) printf '%s\n' "${AQUAMARINE_REF}" ;;
    hyprwire) printf '%s\n' "${HYPRWIRE_REF}" ;;
    hyprtoolkit) printf '%s\n' "${HYPRTOOLKIT_REF}" ;;
    hyprland) printf '%s\n' "${HYPRLAND_REF}" ;;
    xdg-desktop-portal-hyprland) printf '%s\n' "${XDG_DESKTOP_PORTAL_HYPRLAND_REF}" ;;
    hyprlock) printf '%s\n' "${HYPRLOCK_REF}" ;;
    hypridle) printf '%s\n' "${HYPRIDLE_REF}" ;;
    hyprpaper) printf '%s\n' "${HYPRPAPER_REF}" ;;
    waybar) printf '%s\n' "${WAYBAR_REF}" ;;
    *) die "unknown component '$1'" ;;
  esac
}

component_build_system() {
  case "$1" in
    waybar) printf '%s\n' 'meson' ;;
    *) printf '%s\n' 'cmake' ;;
  esac
}

refresh_build_env() {
  PREFIX_DIR="${PREFIX}"
  export PATH="${PREFIX_DIR}/bin:${PATH}"
  export LD_LIBRARY_PATH="${PREFIX_DIR}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  export PKG_CONFIG_PATH="${PREFIX_DIR}/lib/pkgconfig:${PREFIX_DIR}/share/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
  export CMAKE_PREFIX_PATH="${PREFIX_DIR}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
  export XDG_DATA_DIRS="${PREFIX_DIR}/share${XDG_DATA_DIRS:+:${XDG_DATA_DIRS}}"
}

prepare_dirs() {
  mkdir -p "${SRC_ROOT}" "${BUILD_ROOT}" "${PREFIX_DIR}"
}

fetch_component() {
  local component=$1
  local dest="${SRC_ROOT}/${component}"
  local repo ref

  repo=$(component_repo "${component}")
  ref=$(component_ref "${component}")

  if [[ -d "${dest}/.git" ]]; then
    log "reusing source checkout for ${component}"
    return
  fi

  log "fetching ${component} at ${ref}"
  rm -rf "${dest}"
  git init "${dest}" >/dev/null
  git -C "${dest}" remote add origin "${repo}"

  if ! git -C "${dest}" fetch --depth 1 origin "${ref}" >/dev/null 2>&1; then
    git -C "${dest}" fetch origin "${ref}" >/dev/null
  fi

  git -C "${dest}" checkout --detach FETCH_HEAD >/dev/null
  git -C "${dest}" submodule update --init --recursive >/dev/null 2>&1 || true
}

apply_component_patches() {
  local component=$1
  local source_dir="${SRC_ROOT}/${component}"
  local patch_dir="${REPO_ROOT}/patches/${component}"
  local -a patch_files=()
  local patch_file

  [[ -d "${patch_dir}" ]] || return 0

  shopt -s nullglob
  patch_files=("${patch_dir}"/*.patch)
  shopt -u nullglob

  [[ ${#patch_files[@]} -gt 0 ]] || return 0

  for patch_file in "${patch_files[@]}"; do
    log "applying patch $(basename "${patch_file}") to ${component}"
    git -C "${source_dir}" apply --check "${patch_file}"
    git -C "${source_dir}" apply "${patch_file}"
  done
}

cmake_args_common() {
  printf '%s\n' \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    "-DCMAKE_INSTALL_PREFIX=${PREFIX}" \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_INSTALL_LIBEXECDIR=libexec \
    -DCMAKE_INSTALL_INCLUDEDIR=include \
    -DCMAKE_INSTALL_DATAROOTDIR=share \
    -DCMAKE_INSTALL_SYSCONFDIR=etc
}

cmake_component_args() {
  case "$1" in
    hyprland)
      printf '%s\n' -DNO_HYPRPM=ON -DNO_UWSM=ON
      ;;
    xdg-desktop-portal-hyprland)
      printf '%s\n' -DSYSTEMD_SERVICES=ON
      ;;
    *)
      ;;
  esac
}

build_cmake_component() {
  local component=$1
  local source_dir="${SRC_ROOT}/${component}"
  local build_dir="${BUILD_ROOT}/${component}"
  local -a args=()

  rm -rf "${build_dir}"
  mkdir -p "${build_dir}"

  mapfile -t args < <(cmake_args_common)
  mapfile -t component_args < <(cmake_component_args "${component}")
  args+=("${component_args[@]}")

  log "configuring ${component}"
  cmake -S "${source_dir}" -B "${build_dir}" "${args[@]}"

  log "building ${component}"
  cmake --build "${build_dir}" --parallel

  log "installing ${component}"
  cmake --install "${build_dir}"
}

build_meson_component() {
  local component=$1
  local source_dir="${SRC_ROOT}/${component}"
  local build_dir="${BUILD_ROOT}/${component}"

  rm -rf "${build_dir}"

  log "configuring ${component}"
  meson setup "${build_dir}" "${source_dir}" \
    --prefix="${PREFIX}" \
    --buildtype=release \
    --libdir=lib \
    --libexecdir=libexec \
    --includedir=include \
    --datadir=share \
    --sysconfdir=etc \
    -Ddbusmenu-gtk=enabled \
    -Dlibevdev=disabled \
    -Dlibinput=disabled \
    -Dlibnl=disabled \
    -Dlibudev=disabled \
    -Dgps=disabled \
    -Djack=disabled \
    -Dlogind=disabled \
    -Dman-pages=disabled \
    -Dmpd=disabled \
    -Dmpris=disabled \
    -Dniri=false \
    -Dpipewire=disabled \
    -Dpulseaudio=disabled \
    -Drfkill=disabled \
    -Dsndio=disabled \
    -Dtests=disabled \
    -Dupower_glib=disabled \
    -Dwireplumber=disabled

  log "building ${component}"
  meson compile -C "${build_dir}"

  log "installing ${component}"
  meson install -C "${build_dir}" --no-rebuild
}

build_component() {
  local component=$1

  refresh_build_env
  fetch_component "${component}"
  apply_component_patches "${component}"

  case "$(component_build_system "${component}")" in
    cmake) build_cmake_component "${component}" ;;
    meson) build_meson_component "${component}" ;;
    *) die "unsupported build system for ${component}" ;;
  esac

  refresh_build_env
}
