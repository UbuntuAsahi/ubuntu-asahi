#!/bin/bash
set -xe

source 00-arm64-cross-compile.sh

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
trap "cd \"$STARTING_DIR\"" EXIT

# Pull in Asahi's u-boot
test -d u-boot || git clone --depth 1 https://github.com/AsahiLinux/u-boot
cd u-boot

# Ensure u-boot is up to date.
git fetch
git reset --hard origin/asahi
git clean -f -x -d &> /dev/null

# Set up config
make apple_m1_defconfig

# Build u-boot
make -j `nproc`

# Copy output files
cat build/m1n1.bin   `find linux/arch/arm64/boot/dts/apple/ -name \*.dtb` <(gzip -c u-boot/u-boot-nodtb.bin) > ../u-boot.bin
cat build/m1n1.macho `find linux/arch/arm64/boot/dts/apple/ -name \*.dtb` <(gzip -c u-boot/u-boot-nodtb.bin) > ../u-boot.macho