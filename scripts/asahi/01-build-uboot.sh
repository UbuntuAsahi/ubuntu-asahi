#!/bin/bash
set -e

source $(dirname "$(readlink -f "$0")")/../00-arm64-cross-compile.sh
source $(dirname "$(readlink -f "$0")")/../00-config.sh

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
trap "cd \"$STARTING_DIR\"" EXIT

# Pull in Asahi's u-boot
info "Cloning u-boot"
test -d u-boot || git clone --depth 1 https://github.com/AsahiLinux/u-boot 2>&1| capture_and_log "clone u-boot"
cd u-boot

# Ensure u-boot is up to date.
info "Ensuring u-boot is up to date"
git fetch 2>&12>&1| capture_and_log "fetch u-boot"
git reset --hard origin/asahi 2>&1| capture_and_log "reset u-boot"
git clean -f -x -d &> /dev/null 2>&1| capture_and_log "clean u-boot"

# Set up config
info "Setting up u-boot config"
make apple_m1_defconfig 2>&1| capture_and_log "setup u-boot config"

# Build u-boot
info "Building u-boot"
make -j `nproc` 2>&1| capture_and_log "build u-boot"
info "u-boot built"