#!/bin/bash
set -e

source $(dirname "$(readlink -f "$0")")/00-arm64-cross-compile.sh

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
trap "cd \"$STARTING_DIR\"" EXIT

# Bring in the Asahi Linux kernel, if it doesn't already exist
test -d linux || git clone --depth 1 https://github.com/AsahiLinux/linux -b asahi 2>&1| capture_and_log "clone linux"
cd linux

# Ensure Asahi is the latest commit.
git fetch 2>&1| capture_and_log "fetch linux"
git reset --hard origin/asahi 2>&1| capture_and_log "reset linux"
git clean -f -x -d &> /dev/null 2>&1| capture_and_log "clean linux"

# Apply patches
curl -s https://tg.st/u/40c9642c7569c52189f84621316fc9149979ee65.patch | git am - 2>&1| capture_and_log "apply patch #1"
curl -s https://tg.st/u/0001-4k-iommu-patch-2022-03-11.patch | git am - 2>&1| capture_and_log "apply patch #2"

# Set up configuration
curl -s https://tg.st/u/config-2022-03-17-distro-sven-jannau.txt > .config 2>&1| capture_and_log "download defconfig"
make olddefconfig 2>&1| capture_and_log "setup linux defconfig"

# Compile the kernel
make -j `nproc` V=0 bindeb-pkg 2>&1| capture_and_log "build asahi linux"