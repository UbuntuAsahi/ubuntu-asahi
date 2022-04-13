#!/bin/bash
set -e

source $(dirname "$(readlink -f "$0")")/00-config.sh

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
trap "cd \"$STARTING_DIR\"" EXIT

info "Building dummy package"
equivs-build ../pkg/linux-pop-arm64-dummy 2>&1| capture_and_log "build dummy"