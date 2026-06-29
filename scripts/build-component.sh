#!/usr/bin/env bash

set -euo pipefail

component=${1:?usage: build-component.sh <component>}

source "$(dirname "$(readlink -f "$0")")/common.sh"

prepare_dirs
build_component "${component}"
