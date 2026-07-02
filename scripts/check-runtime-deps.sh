#!/usr/bin/env bash

set -euo pipefail

PREFIX=
MANIFEST=

usage() {
  cat <<EOF
Usage: scripts/check-runtime-deps.sh --prefix <prefix> [--manifest <file>]

Checks that the target machine has all required runtime libraries and
services for the Hyprland prefix-scoped build.

Options:
  --prefix <path>       The install prefix (e.g., /opt/hyprland).
  --manifest <file>     Optional path to a runtime-deps.txt from the build.
                        If not given, ldd is run on the bundled binaries.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      PREFIX=$2
      shift 2
      ;;
    --manifest)
      MANIFEST=$2
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

[[ -n "${PREFIX}" ]] || { usage >&2; exit 1; }

case "${PREFIX}" in
  /*) ;;
  *) printf 'prefix must be absolute: %s\n' "${PREFIX}" >&2; exit 1 ;;
esac

MISSING=0

ok()   { printf '  [OK]      %s\n' "$1"; }
miss() { printf '  [MISSING] %s — %s\n' "$1" "$2"; MISSING=1; }

printf 'Checking runtime dependencies for %s\n\n' "${PREFIX}"

# ---------------------------------------------------------------------------
# Section 1: Check that bundled binaries can find all shared libraries
# ---------------------------------------------------------------------------

printf '1. Shared library resolution (ldd)\n\n'

# Collect all ELF binaries from the prefix
ELF_BINS=()
while IFS= read -r f; do
  if file -b "${f}" 2>/dev/null | grep -q 'ELF'; then
    ELF_BINS+=("${f}")
  fi
done < <(
  find "${PREFIX}/bin" "${PREFIX}/libexec" -type f 2>/dev/null || true
)

if [[ ${#ELF_BINS[@]} -eq 0 ]]; then
  printf '  [WARNING] no ELF binaries found under %s/bin or %s/libexec\n' \
    "${PREFIX}" "${PREFIX}"
else
  # Collect all "not found" entries from ldd
  NOT_FOUND_LIBS=()
  for bin in "${ELF_BINS[@]}"; do
    while IFS= read -r line; do
      # ldd "not found" lines look like: "  libfoo.so.1 => not found"
      case "${line}" in
        *"=> not found")
          lib=$(printf '%s\n' "${line}" | awk '{print $1}')
          [[ -n "${lib}" ]] && NOT_FOUND_LIBS+=("${lib}")
          ;;
      esac
    done < <(ldd "${bin}" 2>/dev/null || true)
  done

  # Deduplicate
  UNIQUE_NOT_FOUND=()
  if [[ ${#NOT_FOUND_LIBS[@]} -gt 0 ]]; then
    while IFS= read -r lib; do
      UNIQUE_NOT_FOUND+=("${lib}")
    done < <(printf '%s\n' "${NOT_FOUND_LIBS[@]}" | sort -u)
  fi

  if [[ ${#UNIQUE_NOT_FOUND[@]} -eq 0 ]]; then
    ok "all shared library dependencies resolved"
  else
    for lib in "${UNIQUE_NOT_FOUND[@]}"; do
      miss "${lib}" "apt install scripts/install-runtime-deps-ubuntu.sh"
    done
  fi
fi

printf '\n'

# ---------------------------------------------------------------------------
# Section 2: Check required system commands/services
# ---------------------------------------------------------------------------

printf '2. System commands and services\n\n'

check_command() {
  if command -v "${1}" >/dev/null 2>&1; then
    ok "command: ${1}"
  else
    miss "command: ${1}" "${2}"
  fi
}

check_command xdg-desktop-portal "apt install xdg-desktop-portal"
check_command dbus-run-session "apt install dbus"
check_command dbus-update-activation-environment "apt install dbus"

printf '\n'

# ---------------------------------------------------------------------------
# Section 3: Check PAM support
# ---------------------------------------------------------------------------

printf '3. PAM support\n\n'

PAM_DIR=/etc/pam.d
if [[ -d "${PAM_DIR}" ]]; then
  ok "PAM directory exists (${PAM_DIR})"
else
  miss "PAM directory" "apt install libpam-runtime"
fi

if [[ -f "${PAM_DIR}/hyprlock" ]]; then
  ok "hyprlock PAM file registered"
else
  miss "hyprlock PAM file" "run scripts/register-session.sh --prefix ${PREFIX}"
fi

printf '\n'

# ---------------------------------------------------------------------------
# Section 4: Check optional manifest comparison
# ---------------------------------------------------------------------------

if [[ -n "${MANIFEST}" ]] && [[ -f "${MANIFEST}" ]]; then
  printf '4. Manifest comparison (%s)\n\n' "${MANIFEST}"

  while IFS= read -r lib; do
    [[ -z "${lib}" ]] && continue
    [[ "${lib}" =~ ^# ]] && continue
    # Try to find the library
    found=0
    for dir in /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu /lib /usr/lib "${PREFIX}/lib"; do
      if [[ -e "${dir}/${lib}" ]] || compgen -G "${dir}/${lib}*" >/dev/null 2>&1; then
        found=1
        ok "manifest: ${lib}"
        break
      fi
    done
    [[ "${found}" == 0 ]] && miss "manifest: ${lib}" "not found in standard search paths"
  done <"${MANIFEST}"

  printf '\n'
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if [[ "${MISSING}" == 0 ]]; then
  printf 'All runtime dependencies satisfied.\n'
  exit 0
else
  printf 'Some runtime dependencies are missing. Run scripts/install-runtime-deps-ubuntu.sh to install them.\n' >&2
  exit 1
fi