#!/usr/bin/env bash

set -euo pipefail

readonly BUILD_IN_CONTAINER_SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

PREFIX=${PREFIX:?PREFIX is required}
PROFILE_FILE=${PROFILE_FILE:?PROFILE_FILE is required}
VERSION_FILE=${VERSION_FILE:?VERSION_FILE is required}
SRC_ROOT=${SRC_ROOT:-/sources}
BUILD_ROOT=${BUILD_ROOT:-/build}
OUT_ROOT=${OUT_ROOT:-/out}

source "${VERSION_FILE}"
source "${BUILD_IN_CONTAINER_SCRIPT_DIR}/common.sh"

install_xcb_errors() {
  local src_dir="${SRC_ROOT}/xcb-util-errors"

  if [[ -f "${PREFIX_DIR}/lib/pkgconfig/xcb-errors.pc" ]]; then
    return
  fi

  log "bootstrapping xcb-errors for Ubuntu 24.04"
  rm -rf "${src_dir}"
  git clone --depth 1 --recursive \
    https://github.com/freedesktop-unofficial-mirror/xcb__util-errors.git \
    "${src_dir}"

  log "configuring xcb-errors"
  (cd "${src_dir}" && ./autogen.sh --prefix="${PREFIX}" --libdir="${PREFIX}/lib")

  log "building xcb-errors"
  make -C "${src_dir}" -j"$(nproc)"

  log "installing xcb-errors"
  make -C "${src_dir}" install
}

render_runtime_wrappers() {
  local bin_dir="${PREFIX_DIR}/bin"
  local service_dir="${PREFIX_DIR}/lib/systemd/user"
  local session_dir="${PREFIX_DIR}/share/wayland-sessions"
  local dbus_dir="${PREFIX_DIR}/share/dbus-1/services"

  mkdir -p "${bin_dir}" "${service_dir}" "${session_dir}" "${dbus_dir}"

  cat >"${bin_dir}/hyprland-env" <<EOF
#!/usr/bin/env bash
set -euo pipefail
prefix="${PREFIX}"
export PATH="\${prefix}/bin:\${PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"
export LD_LIBRARY_PATH="\${prefix}/lib\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}"
export PKG_CONFIG_PATH="\${prefix}/lib/pkgconfig:\${prefix}/share/pkgconfig\${PKG_CONFIG_PATH:+:\${PKG_CONFIG_PATH}}"
export XDG_DATA_DIRS="\${prefix}/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export XDG_CONFIG_DIRS="\${prefix}/etc/xdg:\${XDG_CONFIG_DIRS:-/etc/xdg}"
export XDG_CURRENT_DESKTOP="Hyprland"
export XDG_SESSION_DESKTOP="Hyprland"
export XDG_SESSION_TYPE="wayland"
exec "\$@"
EOF

  cat >"${bin_dir}/hyprland-session" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "${PREFIX}/bin/hyprland-env" "${PREFIX}/bin/Hyprland" "\$@"
EOF

  cat >"${bin_dir}/hypridle-session" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "${PREFIX}/bin/hyprland-env" "${PREFIX}/bin/hypridle" "\$@"
EOF

  cat >"${bin_dir}/hyprpaper-session" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "${PREFIX}/bin/hyprland-env" "${PREFIX}/bin/hyprpaper" "\$@"
EOF

  cat >"${bin_dir}/xdg-desktop-portal-hyprland-session" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "${PREFIX}/bin/hyprland-env" "${PREFIX}/libexec/xdg-desktop-portal-hyprland" "\$@"
EOF

  chmod 0755 \
    "${bin_dir}/hyprland-env" \
    "${bin_dir}/hyprland-session" \
    "${bin_dir}/hypridle-session" \
    "${bin_dir}/hyprpaper-session" \
    "${bin_dir}/xdg-desktop-portal-hyprland-session"

  cat >"${session_dir}/hyprland.desktop" <<EOF
[Desktop Entry]
Name=Hyprland
Comment=Hyprland from ${PREFIX}
Exec=${PREFIX}/bin/hyprland-session
Type=Application
DesktopNames=Hyprland
Keywords=tiling;wayland;compositor;
EOF

  if [[ -f "${service_dir}/hypridle.service" ]]; then
    cat >"${service_dir}/hypridle.service" <<EOF
[Unit]
Description=Hyprland's idle daemon
Documentation=https://wiki.hypr.land/Hypr-Ecosystem/hypridle/
PartOf=graphical-session.target
After=graphical-session.target
ConditionEnvironment=WAYLAND_DISPLAY

[Service]
Type=simple
ExecStart=${PREFIX}/bin/hypridle-session
Restart=on-failure

[Install]
WantedBy=graphical-session.target
EOF
  fi

  if [[ -f "${service_dir}/hyprpaper.service" ]]; then
    cat >"${service_dir}/hyprpaper.service" <<EOF
[Unit]
Description=Fast, IPC-controlled wallpaper utility for Hyprland.
Documentation=https://wiki.hypr.land/Hypr-Ecosystem/hyprpaper/
PartOf=graphical-session.target
Requires=graphical-session.target
After=graphical-session.target
ConditionEnvironment=WAYLAND_DISPLAY

[Service]
Type=simple
ExecStart=${PREFIX}/bin/hyprpaper-session
Slice=session.slice
Restart=on-failure

[Install]
WantedBy=graphical-session.target
EOF
  fi

  if [[ -f "${service_dir}/xdg-desktop-portal-hyprland.service" ]]; then
    cat >"${service_dir}/xdg-desktop-portal-hyprland.service" <<EOF
[Unit]
Description=Portal service (Hyprland implementation)
PartOf=graphical-session.target
After=graphical-session.target
ConditionEnvironment=WAYLAND_DISPLAY

[Service]
Type=dbus
BusName=org.freedesktop.impl.portal.desktop.hyprland
ExecStart=${PREFIX}/bin/xdg-desktop-portal-hyprland-session
Restart=on-failure
Slice=session.slice
EOF
  fi

  if [[ -f "${dbus_dir}/org.freedesktop.impl.portal.desktop.hyprland.service" ]]; then
    cat >"${dbus_dir}/org.freedesktop.impl.portal.desktop.hyprland.service" <<EOF
[D-BUS Service]
Name=org.freedesktop.impl.portal.desktop.hyprland
Exec=${PREFIX}/bin/xdg-desktop-portal-hyprland-session
SystemdService=xdg-desktop-portal-hyprland.service
EOF
  fi
}

install_examples() {
  local examples_dir="${PREFIX_DIR}/share/hyprland-build-ubuntu/examples"
  mkdir -p "${examples_dir}"
  cp -a "${REPO_ROOT}/examples/." "${examples_dir}/"
}

write_build_metadata() {
  local metadata_dir="${OUT_ROOT}/build-metadata"
  mkdir -p "${metadata_dir}"

  cp "${VERSION_FILE}" "${metadata_dir}/selected-versions.env"
  cp "${PROFILE_FILE}" "${metadata_dir}/selected-profile.list"

  {
    printf 'prefix=%s\n' "${PREFIX}"
    printf 'profile=%s\n' "${PROFILE_FILE}"
    printf 'cc=%s\n' "${CC:-unset}"
    printf 'cxx=%s\n' "${CXX:-unset}"
    printf 'built_at_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } >"${metadata_dir}/build-info.txt"
}

prepare_dirs
refresh_build_env
install_xcb_errors
refresh_build_env

while IFS= read -r component; do
  [[ -z "${component}" ]] && continue
  build_component "${component}"
done <"${PROFILE_FILE}"

render_runtime_wrappers
install_examples

rm -rf "${OUT_ROOT}"
mkdir -p "${OUT_ROOT}${PREFIX}"
cp -a "${PREFIX}/." "${OUT_ROOT}${PREFIX}/"
write_build_metadata
