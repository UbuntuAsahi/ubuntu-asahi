#!/bin/bash
set -e

source $(dirname "$(readlink -f "$0")")/00-config.sh

# Go back to starting dir and clean up mounts on script exit
STARTING_DIR="$PWD"
trap "cd \"$STARTING_DIR\"" EXIT

# Allocate space for boot image
info "Allocating efi.img ($BOOT_IMG_SIZE MiB)"
dd if=/dev/zero of=efi.img bs=1M count="$BOOT_IMG_SIZE" status=progress 2>&1| capture_and_log "allocate efi.img"

# Create FAT32 partition
mkfs.vfat -F 32 -n EFI efi.img 2>&1| capture_and_log "make efi.img fs"

