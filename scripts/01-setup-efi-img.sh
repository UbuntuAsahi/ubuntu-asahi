#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/00-config.sh"

# Allocate a 512MiB EFI partition in efi.img
info "Allocating 512MiB efi.img"
fallocate -l 512M "${EFI_IMG}"

info "Creating FAT32 EFI partition in efi.img"
mkfs.vfat -F 32 -n "EFILIVE" "${EFI_IMG}"