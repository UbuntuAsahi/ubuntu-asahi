#!/bin/bash
set -e

source $(dirname "$(readlink -f "$0")")/00-config.sh

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
trap "cd \"$STARTING_DIR\"" EXIT

# Bring in m1m1
test -d m1n1 || git clone --recursive https://github.com/AsahiLinux/m1n1.git 2>&1| capture_and_log "clone m1n1"
cd m1n1

# Ensure m1n1 commit is latest
git fetch 2>&1| capture_and_log "fetch m1n1"
git reset --hard origin/main 2>&1| capture_and_log "reset m1n1"
git clean -f -x -d &> /dev/null 2>&1| capture_and_log "clean m1n1"

# Build!
make -j `nproc` 2>&1| capture_and_log "build m1n1"

cat build/m1n1.bin   `find ../linux/arch/arm64/boot/dts/apple/ -name \*.dtb` <(gzip -c ../u-boot/u-boot-nodtb.bin) > ../u-boot.bin
cat build/m1n1.macho `find ../linux/arch/arm64/boot/dts/apple/ -name \*.dtb` <(gzip -c ../u-boot/u-boot-nodtb.bin) > ../u-boot.macho