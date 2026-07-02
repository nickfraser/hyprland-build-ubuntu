# AGENTS.md — Hyprland Build for Ubuntu 24.04

## Build entrypoint

```
scripts/build-artifact.sh --prefix /opt/hyprland --output-dir dist/desktop-opt
```

- Two profiles: `profiles/core.list` (13 components) and `profiles/desktop.list` (14, adds waybar).
- All upstream refs pinned in `versions/latest.env` — update there when changing versions.

## Docker build flow

1. `Dockerfile` → `scripts/build-in-container.sh` → `scripts/common.sh`
2. Components are built in profile-list order via `build_component()`.
3. The artifact is extracted from the final `artifact` stage with `docker cp`.
4. Post-extraction verification runs via `verify-artifact.sh` (profile-aware).

## Non-obvious toolchain choices

- **Default compiler**: `gcc-14` / `g++-14`, set via Docker `ARG`.
- **Clang exception**: `xdg-desktop-portal-hyprland` builds with `clang`/`clang++` (PipeWire SPA headers trigger GCC 14 designated-initializer errors in C++ mode).
- **CMake**: downloaded as prebuilt binary tarball v3.31.6 (Ubuntu 24.04 ships 3.28.3; Hyprland requires >= 3.30).
- C++23/26 GCC 14 features used freely; patching is preferred over toolchain changes when GCC 14 lacks a C++23 feature.

## Source-built dependencies

- **libinput 1.27.0**: built via Meson because `aquamarine` requires `libinput>=1.26.0` and Ubuntu 24.04 has 1.25.0.
- **xcb-errors**: bootstrapped from `freedesktop-unofficial-mirror/xcb__util-errors` (autotools, not available in Ubuntu 24.04).
- **libinput.pc/.so**: renamed to `.bak` in the Docker container so pkg-config/CMake only finds the prefix-local version.
- **iniparser.pc**: manually created in `/usr/share/pkgconfig/` (Ubuntu 24.04's `libiniparser-dev` does not ship a `.pc` file).

## Build-time workarounds

- `CMAKE_BUILD_RPATH` and `CMAKE_INSTALL_RPATH` are set to `${PREFIX}/lib` for all CMake components.
- `LDFLAGS` includes `-Wl,-rpath-link,${PREFIX}/lib` for transitive `.so` resolution at link time.
- `LIBRARY_PATH` and `LD_LIBRARY_PATH` set to `${PREFIX}/lib`.
- `PKG_CONFIG_PATH` includes `${PREFIX}/lib/pkgconfig` and `${PREFIX}/share/pkgconfig`.
- Install is **DESTDIR-free** — components install directly into `${PREFIX}` to avoid pkg-config path mismatches.

## Local patches (6)

| Patch | Component | Purpose |
|---|---|---|
| `0001-relax-wayland-server-version.patch` | hyprland | Relaxes `wayland-server>=1.22.90` to `>=1.22.0` |
| `0002-guard-max-buffer-size.patch` | hyprland | Guards `wl_display_set_default_max_buffer_size()` call behind `WAYLAND_VERSION` check |
| `0001-guard-test-executables.patch` | aquamarine | Wraps test executables in `if(BUILD_TESTING)` — avoids link failure against system libinput |
| `0001-add-missing-fstream-include.patch` | hyprcursor | Adds `#include <fstream>` — GCC 14 stricter transitive includes |
| `0001-make-jxl-optional.patch` | hyprgraphics | Makes JXL optional; Ubuntu 24.04's `libjxl-dev` lacks `libjxl_cms.pc` |
| `0001-install-pam-under-prefix.patch` | hyprlock | Installs PAM file under relative `SYSCONFDIR` so it lands inside the prefix tree |

Patches are applied automatically by `apply_component_patches()` after checkout.

## Version pin rationale

All versions are pinned to Hyprland v0.48.0-era compatibility. Key constraints:
- `xkbcommon`, `wayland-protocols`, `libinput` — must be compatible with Ubuntu 24.04 system packages
- `sdbus-c++` — Ubuntu 24.04 has 1.4.0; `hyprlock` v0.4.1 and `hypridle` v0.1.3 work with it
- `libpipewire-0.3` — Ubuntu 24.04 has 1.0.5; `xdg-desktop-portal-hyprland` v1.3.3 works with it

## Client-side setup scripts

- `register-session.sh --prefix /opt/hyprland` — installs/symlinks session `.desktop`, portal files, and PAM file. Required and optional file paths are explicit in the script.
- `unregister-session.sh` — removes registrations. Disables user units before deleting service files.
- `check-runtime-deps.sh --prefix /opt/hyprland` — runs `ldd` over bundled binaries and checks system commands/services.
- `install-runtime-deps-ubuntu.sh` — installs all runtime system packages (132 packages). `--dry-run` previews without installing.
- `package-artifact.sh` — produces `.tar.gz` and `.sha256`.

Generated wrappers in the artifact:
- `hyprland-env` — sets `PATH`, `LD_LIBRARY_PATH`, `XDG_DATA_DIRS`, `XDG_CONFIG_DIRS` for the prefix
- `hyprland-session` — launches `Hyprland` via `hyprland-env`
- `hypridle-session`, `hyprpaper-session`, `xdg-desktop-portal-hyprland-session` — analogous

## Verification

- `verify-artifact.sh` checks for required files. It is profile-aware: with `--profile-file profiles/desktop.list` it requires `waybar`.
- `build-artifact.sh` automatically runs verification after Docker extraction.
- `build-metadata/` in the artifact includes `build-info.txt`, `selected-versions.env`, `selected-profile.list`, and `runtime-deps.txt`.
