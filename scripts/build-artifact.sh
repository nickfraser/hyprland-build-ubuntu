#!/usr/bin/env bash

set -euo pipefail

PREFIX=/opt/hyprland
PROFILE=profiles/desktop.list
VERSION_FILE=versions/latest.env
OUTPUT_DIR=
IMAGE_TAG=

usage() {
  cat <<EOF
Usage: scripts/build-artifact.sh --output-dir <dir> [options]

Options:
  --prefix <prefix>            Install prefix baked into the artifact.
  --profile <file>             Profile list file to build.
  --versions <file>            Version env file to use.
  --output-dir <dir>           Directory where /out will be extracted.
  --image-tag <tag>            Optional Docker image tag.
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
    --profile)
      require_arg "$@"
      PROFILE=$2
      shift 2
      ;;
    --versions)
      require_arg "$@"
      VERSION_FILE=$2
      shift 2
      ;;
    --output-dir)
      require_arg "$@"
      OUTPUT_DIR=$2
      shift 2
      ;;
    --image-tag)
      require_arg "$@"
      IMAGE_TAG=$2
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

if [[ -z "${OUTPUT_DIR}" ]]; then
  usage >&2
  exit 1
fi

case "${PREFIX}" in
  /*) ;;
  *) printf 'prefix must be absolute: %s\n' "${PREFIX}" >&2; exit 1 ;;
esac

if [[ -e "${OUTPUT_DIR}" ]] && [[ -n "$(ls -A "${OUTPUT_DIR}" 2>/dev/null || true)" ]]; then
  printf 'output directory must not be non-empty: %s\n' "${OUTPUT_DIR}" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

IMAGE_TAG=${IMAGE_TAG:-hyprland-build-ubuntu:$(date -u +%Y%m%d%H%M%S)}

docker build \
  --build-arg PREFIX="${PREFIX}" \
  --build-arg PROFILE="${PROFILE}" \
  --build-arg VERSION_FILE="${VERSION_FILE}" \
  --tag "${IMAGE_TAG}" \
  .

container_id=$(docker create "${IMAGE_TAG}")
trap 'docker rm -f "${container_id}" >/dev/null 2>&1 || true' EXIT

docker cp "${container_id}:/out/." "${OUTPUT_DIR}/"

"$(dirname "$(readlink -f "$0")")/verify-artifact.sh" --artifact-root "${OUTPUT_DIR}" --prefix "${PREFIX}" --profile-file "${PROFILE}"
