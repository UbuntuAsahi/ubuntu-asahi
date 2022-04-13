#!/bin/bash
set -xe

source $(dirname "$(readlink -f "$0")")/00-config.sh

# Go back to starting dir and clean up mounts on script exit
STARTING_DIR="$PWD"
trap "cd \"$STARTING_DIR\"" EXIT

# Allocate space for boot image
fallocate -l "$BOOT_IMG_SIZE" efi.img

# Create FAT32 partition
mkfs.vfat -F 32 -n efi efi.img

