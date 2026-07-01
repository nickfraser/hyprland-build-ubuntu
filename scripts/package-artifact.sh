#!/usr/bin/env bash

set -euo pipefail

ARTIFACT_ROOT=
OUTPUT=

usage() {
  cat <<EOF
Usage: scripts/package-artifact.sh --artifact-root <dir> --output <tar.gz>
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-root)
      ARTIFACT_ROOT=$2
      shift 2
      ;;
    --output)
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

mkdir -p "$(dirname "${OUTPUT}")"
tar -C "${ARTIFACT_ROOT}" -czf "${OUTPUT}" .

# Generate a checksum alongside the tarball so the target machine can verify integrity
sha256sum "${OUTPUT}" > "${OUTPUT}.sha256"
log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
log "wrote ${OUTPUT}"
log "wrote ${OUTPUT}.sha256"
