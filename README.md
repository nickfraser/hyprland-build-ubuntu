# Hyprland Build For Ubuntu 24.04

This repository builds a prefix-scoped Hyprland desktop stack in Docker and extracts an install tree that can be copied into a fixed target prefix such as `/opt/hyprland`.

The default `desktop` profile builds:

- `Hyprland`
- `xdg-desktop-portal-hyprland`
- `hyprlock`
- `hypridle`
- `hyprpaper`
- `waybar`
- their Hypr ecosystem library dependencies

The build is intentionally `one prefix per artifact`. If you want both `/opt/hyprland` and `~/.local/hyprland`, build two artifacts.

Use an absolute path for the prefix. For a user-scoped install, build for something like `/home/your-user/.local/hyprland`, not a literal `~/.local/hyprland` string.

## Layout

- `Dockerfile`: Ubuntu 24.04 build environment
- `profiles/*.list`: component sets
- `versions/latest.env`: pinned upstream refs
- `scripts/build-artifact.sh`: Docker build and extraction wrapper
- `scripts/register-session.sh`: system-level session and service registration
- `scripts/unregister-session.sh`: remove registration files
- `scripts/verify-artifact.sh`: artifact sanity check
- `scripts/check-runtime-deps.sh`: verify target-side runtime libraries and services
- `scripts/install-runtime-deps-ubuntu.sh`: install runtime packages on Ubuntu 24.04
- `examples/`: sample Hyprland and Waybar config files

## Requirements

Build machine:
- Docker
- enough disk space for the container build and extracted artifact

Target machine:
- Ubuntu 24.04
- `sudo` if you want GDM session registration
- Runtime packages — see "Target Machine Runtime Dependencies" below

## Build

Build a desktop artifact for `/opt/hyprland` into `dist/desktop-opt`:

```bash
mkdir -p dist
scripts/build-artifact.sh \
  --prefix /opt/hyprland \
  --profile profiles/desktop.list \
  --versions versions/latest.env \
  --output-dir dist/desktop-opt
```

Build the smaller core profile instead:

```bash
scripts/build-artifact.sh \
  --prefix /opt/hyprland \
  --profile profiles/core.list \
  --versions versions/latest.env \
  --output-dir dist/core-opt
```

Package an extracted artifact tree:

```bash
scripts/package-artifact.sh \
  --artifact-root dist/desktop-opt \
  --output dist/hyprland-desktop-opt.tar.gz
```

## Artifact Contents

After extraction, the output directory contains:

- the prefix tree itself, for example `dist/desktop-opt/opt/hyprland/...`
- `build-metadata/build-info.txt`
- `build-metadata/selected-versions.env`
- `build-metadata/selected-profile.list`

The build also adds wrapper entrypoints under `${PREFIX}/bin/` so session-scoped binaries see the custom `lib` and `share` directories:

- `hyprland-session`
- `hypridle-session`
- `hyprpaper-session`
- `xdg-desktop-portal-hyprland-session`

The main session wrapper launches `${PREFIX}/bin/Hyprland` directly.

## Install On Target Machine

Extract or copy the built prefix tree onto the target machine so that the files land at the same prefix used during the build.

Example for `/opt/hyprland`:

```bash
sudo mkdir -p /opt/hyprland
sudo rsync -a dist/desktop-opt/opt/hyprland/ /opt/hyprland/
```

Register the display-manager session and helper service files:

```bash
scripts/register-session.sh --prefix /opt/hyprland
```

`register-session.sh` now fails if required files are missing from the artifact, including the Hyprland session entry, portal registration files, and the `hyprlock` PAM file.

If you want the shipped user services enabled globally:

```bash
scripts/register-session.sh --prefix /opt/hyprland --enable-user-units
```

To remove those registration files later:

```bash
scripts/unregister-session.sh
```

## Target Machine Runtime Dependencies

The `register-session.sh` script does **not** install runtime packages. The build bundles its own ecosystem libraries (e.g., `libaquamarine.so`, `libhyprutils.so`, `libinput.so`) under `${PREFIX}/lib/`, but the shipped binaries also dynamically link against system libraries that must already exist on the target machine.

Check whether the target machine has all required runtime dependencies:

```bash
scripts/check-runtime-deps.sh --prefix /opt/hyprland
```

This runs `ldd` over every bundled ELF binary and reports any missing shared libraries. It also checks for required system commands like `xdg-desktop-portal` and PAM support.

If any dependencies are missing, install them on Ubuntu 24.04:

```bash
scripts/install-runtime-deps-ubuntu.sh
```

Or preview the packages without installing:

```bash
scripts/install-runtime-deps-ubuntu.sh --dry-run
```

Key runtime requirements:

- Graphics/display: `libdrm2`, `libgbm1`, `libegl1`, `libgl1`, `libgles2`
- Wayland: `libwayland-client0`, `libwayland-server0`, `libxkbcommon0`
- Input: `libinput10`, `libseat1`, `libwacom9`, `libmtdev1t64`
- Portal/screencast: `libpipewire-0.3-0t64`, `libspa-0.2-modules`, `xdg-desktop-portal`, `xdg-desktop-portal-gtk`
- Qt6 (for hyprland-share-picker): `libqt6widgets6t64`, `libqt6gui6t64`, `libqt6core6t64`
- D-Bus: `dbus`, `libsdbus-c++1`
- PAM: `libpam0g`, `libpam-runtime`
- GTK (for waybar): `libgtkmm-3.0-1t64`, `libgtk-layer-shell0`, `libdbusmenu-gtk3-4`
- Image: `libcairo2`, `libpango-1.0-0`, `librsvg2-2`, `libjpeg-turbo8`, `libwebp7`, `libpng16-16t64`
- Misc: `libfmt9`, `libspdlog1.12`, `libmagic1t64`, `libsystemd0`, `libudev1`

The build also generates a `build-metadata/runtime-deps.txt` manifest listing all shared library basenames that the bundled binaries depend on. This can be used for offline dependency auditing:

```bash
scripts/check-runtime-deps.sh --prefix /opt/hyprland --manifest dist/desktop-opt/build-metadata/runtime-deps.txt
```

## User Configuration

Example configs are installed inside the artifact at:

```text
${PREFIX}/share/hyprland-build-ubuntu/examples/
```

The example set includes:

- `hypr/hyprland.conf`: default/core-safe example
- `hypr/hyprland-core.conf`
- `hypr/hyprland-desktop.conf`
- `hypr/hypridle.conf`
- `hypr/hyprpaper.conf`
- `waybar/config.jsonc`
- `waybar/style.css`

Use the desktop example only with the `desktop` profile, because it autostarts `waybar`. The `core` profile does not build `waybar`.

## Notes

- This build expects Ubuntu 24.04 runtime libraries for GTK, PipeWire, PAM, Mesa, Wayland, and related desktop components.
- The registration step is still system-level even if the software itself lives in a custom prefix.
- `waybar` is built with a reduced feature set to keep the first implementation smaller and more predictable.
- NVIDIA-specific support is intentionally out of scope.

## Verification

The build wrapper runs `scripts/verify-artifact.sh` after extracting the Docker artifact.

You can also run it yourself:

```bash
scripts/verify-artifact.sh \
  --artifact-root dist/desktop-opt \
  --prefix /opt/hyprland \
  --profile-file profiles/desktop.list
```

## Patches and Compatibility

The Hyprland ecosystem evolves quickly and targets rolling-release distributions. To build on Ubuntu 24.04 LTS, several upstream packages had to be pinned to older versions or patched. This section documents those choices for future maintainers.

### Version Pins

All component versions are pinned in `versions/latest.env`. Key decisions:

- **Hyprland v0.48.0**: chosen because it was the newest release whose version floors for `xkbcommon`, `wayland-protocols`, and `libinput` are compatible with Ubuntu 24.04 system packages. Newer releases (v0.54.0+) require `xkbcommon>=1.11.0`, `wayland-protocols>=1.47`, and `libinput>=1.28`, none of which are available on Ubuntu 24.04.
- **hyprutils v0.5.2**: satisfies `aquamarine v0.8.0`'s `hyprutils>=0.5.2` requirement while staying on the older C++23 codebase that avoids `std::expected`, `<print>`, and `native_handle` issues.
- **hyprlang v0.6.0**: compatible with `hyprutils v0.5.2` (requires `>=0.1.1`).
- **hyprcursor v0.1.10**: compatible C++23 codebase with no problematic C++23/26 features.
- **hyprgraphics v0.1.1**: uses C++26 but only `std::expected` (supported by GCC 14), avoiding `<print>` and `native_handle` issues present in newer versions.
- **aquamarine v0.8.0**: requires `libinput>=1.26.0`, satisfied by building libinput from source.
- **xdg-desktop-portal-hyprland v1.3.3**: newest release before the `libpipewire-0.3>=1.1.82` floor was introduced in v1.3.4. Ubuntu 24.04 has PipeWire 1.0.5.
- **hyprlock v0.4.1**: newest release that does not require `sdbus-c++>=2.0.0`. Ubuntu 24.04 has `sdbus-c++ 1.4.0`.
- **hypridle v0.1.3**: newest release whose source code uses the older `sdbus-c++ 1.x` API (`createProxy`, `registerMethod`). v0.1.4+ switched to `sdbus::ServiceName`, `addVTable`, `processPendingEvent` which require sdbus-c++ 2.x.
- **hyprwayland-scanner v0.4.4**: satisfies `hyprlock v0.4.1`'s `find_package(hyprwayland-scanner 0.4.4 REQUIRED)` and all other components' lower requirements.

### Source-Built Dependencies

- **libinput 1.27.0**: built from source via Meson because Ubuntu 24.04 ships 1.25.0 and `aquamarine v0.8.0` requires `>=1.26.0`. Provides `libinput_device_get_id_bustype()` needed by aquamarine.
- **xcb-errors**: bootstrapped from the freedesktop unofficial mirror because Ubuntu 24.04 does not package `libxcb-errors-dev`. Built via autotools and installed into the prefix.
- **CMake 3.31.6**: downloaded as a prebuilt binary tarball because Hyprland requires `cmake>=3.30` and Ubuntu 24.04 ships 3.28.3.

### Docker Build Workarounds

- System `libinput.pc` and `libinput.so` are renamed (to `.bak`) during the Docker build so that pkg-config and CMake's `find_library` only see the prefix-local version (1.27.0), preventing linker resolution to the system 1.25.0.
- `iniparser.pc` is manually created in `/usr/share/pkgconfig/` because Ubuntu 24.04's `libiniparser-dev` does not ship a pkg-config file.
- `xdg-desktop-portal-hyprland` is compiled with **Clang** (while the rest of the stack uses GCC 14) because GCC 14 rejects PipeWire/SPA header designated-initializer syntax in C++ mode.
- `CMAKE_BUILD_RPATH` and `CMAKE_INSTALL_RPATH` are set to `${PREFIX}/lib` for all CMake components so the linker finds prefix-local `libinput.so` at both link time and runtime.
- `LDFLAGS` includes `-Wl,-rpath-link,${PREFIX}/lib` for transitive shared library resolution during linking.

### Local Patches

| Patch | Component | Purpose |
|---|---|---|
| `0001-relax-wayland-server-version.patch` | hyprland | Relaxes `wayland-server>=1.22.90` to `>=1.22.0` (Ubuntu 24.04 has 1.22.0) |
| `0002-guard-max-buffer-size.patch` | hyprland | Guards `wl_display_set_default_max_buffer_size()` call behind a wayland version check (API added in 1.22.91, not in 1.22.0) |
| `0001-guard-test-executables.patch` | aquamarine | Wraps test executables in `if(BUILD_TESTING)` so they are not built by default (avoids link failure against system libinput) |
| `0001-add-missing-fstream-include.patch` | hyprcursor | Adds `#include <fstream>` to `hyprcursor-util/src/main.cpp` (missing in upstream, GCC 14 is stricter about transitive includes) |
| `0001-make-jxl-optional.patch` | hyprgraphics | Makes JXL dependencies optional because Ubuntu 24.04's `libjxl-dev` lacks `libjxl_cms.pc` |
| `0001-install-pam-under-prefix.patch` | hyprlock | Installs PAM file under relative `SYSCONFDIR/pam.d` instead of absolute `FULL_SYSCONFDIR/pam.d` so it lands inside the prefix tree |
