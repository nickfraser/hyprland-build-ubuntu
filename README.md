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
- `examples/`: sample Hyprland and Waybar config files

## Requirements

- Docker on the build machine
- enough disk space for the container build and extracted artifact
- sudo on the target machine if you want GDM session registration

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
