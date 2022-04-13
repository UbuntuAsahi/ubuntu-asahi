#!/bin/bash
set -xe

source $(dirname "$(readlink -f "$0")")/00-arm64-cross-compile.sh

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
trap "cd \"$STARTING_DIR\"" EXIT

# Clean up old directories
sudo rm -rf rootfs

# Bootstrap debian rootfs
mkdir -p cache
sudo update-binfmts --enable
sudo eatmydata qemu-debootstrap \
		--arch=arm64 \
		--cache-dir=`pwd`/cache \
		--include initramfs-tools,apt,grub-efi-arm64 \
		jammy \
		rootfs \
		http://ports.ubuntu.com/ubuntu-ports

cd rootfs

sudo -- perl -p -i -e 's/root:x:/root::/' etc/passwd

# Link systemd to init.
sudo -- ln -s lib/systemd/systemd init