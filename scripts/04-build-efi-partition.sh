#!/bin/bash
set -xe

source 00-config.sh

# Go back to starting dir and clean up mounts on script exit
STARTING_DIR="$PWD"
function on_exit() {
	sudo umount mnt || true
	sudo rm -rf mount
	cd "$STARTING_DIR"
}
trap on_exit EXIT

# Allocate space for boot image
fallocate -l "$BOOT_IMG_SIZE" boot.img

# Create FAT32 partition
mkfs.vfat -F 32 -n boot boot.img

