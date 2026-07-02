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

require_arg() {
  local opt=$1
  [[ $# -ge 2 && -n "${2:-}" ]] || { printf '%s requires a value\n' "${opt}" >&2; usage >&2; exit 1; }
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      require_arg "$@"
      PREFIX=$2
      shift 2
      ;;
    --manifest)
      require_arg "$@"
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

check_command_or_path() {
  local command_name=$1
  local path=$2
  local hint=$3

  if command -v "${command_name}" >/dev/null 2>&1 || [[ -x "${path}" ]]; then
    ok "command: ${command_name}"
  else
    miss "command: ${command_name}" "${hint}"
  fi
}

check_command_or_path xdg-desktop-portal /usr/libexec/xdg-desktop-portal "apt install xdg-desktop-portal"
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

  SEARCH_DIRS=(/lib /usr/lib "${PREFIX}/lib")
  if command -v dpkg-architecture >/dev/null 2>&1; then
    multiarch=$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || true)
    if [[ -n "${multiarch}" ]]; then
      SEARCH_DIRS=(/lib/"${multiarch}" /usr/lib/"${multiarch}" "${SEARCH_DIRS[@]}")
    fi
  fi

  manifest_lib_found() {
    local lib=$1
    local dir

    if [[ "${lib}" = /* ]]; then
      [[ -e "${lib}" ]] && return 0
      return 1
    fi

    for dir in "${SEARCH_DIRS[@]}"; do
      [[ -e "${dir}/${lib}" ]] && return 0
    done

    if command -v ldconfig >/dev/null 2>&1 && ldconfig -p 2>/dev/null | grep -Fq "${lib} ("; then
      return 0
    fi

    return 1
  }

  while IFS= read -r lib; do
    [[ -z "${lib}" ]] && continue
    [[ "${lib}" =~ ^# ]] && continue
    [[ "${lib}" == linux-vdso* ]] && continue

    if manifest_lib_found "${lib}"; then
      ok "manifest: ${lib}"
    else
      miss "manifest: ${lib}" "not found in standard search paths"
    fi
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
