#!/bin/bash
set -xe

source 00-arm64-cross-compile.sh

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
trap "cd \"$STARTING_DIR\"" EXIT

# Bring in the Asahi Linux kernel, if it doesn't already exist
test -d linux || git clone --depth 1 https://github.com/AsahiLinux/linux -b asahi
cd linux

# Ensure Asahi is the latest commit.
git fetch
git reset --hard origin/asahi
git clean -f -x -d &> /dev/null

# Apply patches
curl -s https://tg.st/u/40c9642c7569c52189f84621316fc9149979ee65.patch | git am -
curl -s https://tg.st/u/0001-4k-iommu-patch-2022-03-11.patch | git am -

# Set up configuration
curl -s https://tg.st/u/config-2022-03-17-distro-sven-jannau.txt > .config
make olddefconfig

# Compile the kernel
make -j `nproc` V=0 bindeb-pkg