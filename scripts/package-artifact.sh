#!/usr/bin/env bash

set -euo pipefail

ARTIFACT_ROOT=
OUTPUT=

usage() {
  cat <<EOF
Usage: scripts/package-artifact.sh --artifact-root <dir> --output <tar.gz>
EOF
}

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }

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
    --output)
      require_arg "$@"
      OUTPUT=$2
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
[[ -n "${OUTPUT}" ]] || { usage >&2; exit 1; }

shopt -s dotglob nullglob
artifact_entries=("${ARTIFACT_ROOT}"/*)
shopt -u dotglob nullglob

[[ ${#artifact_entries[@]} -gt 0 ]] || { printf 'artifact root is empty: %s\n' "${ARTIFACT_ROOT}" >&2; exit 1; }

entry_names=()
for entry in "${artifact_entries[@]}"; do
  entry_names+=("$(basename "${entry}")")
done

mkdir -p "$(dirname "${OUTPUT}")"
tar -C "${ARTIFACT_ROOT}" -czf "${OUTPUT}" "${entry_names[@]}"

# Generate a checksum alongside the tarball so the target machine can verify integrity
(
  cd "$(dirname "${OUTPUT}")"
  sha256sum "$(basename "${OUTPUT}")" > "$(basename "${OUTPUT}").sha256"
)
log "wrote ${OUTPUT}"
log "wrote ${OUTPUT}.sha256"
