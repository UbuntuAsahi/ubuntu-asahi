#!/bin/bash
set -e

source $(dirname "$(readlink -f "$0")")/00-config.sh

# Go back to starting dir and clean up mounts on script exit
STARTING_DIR="$PWD"
function on_exit() {
	cd "$STARTING_DIR"
	sync
}
trap on_exit EXIT

rm -f pop-os.img

info "Allocating Pop!_OS image files"
fallocate --verbose --length 8GiB "${BUILD}/rootfs.img" 2>&1| capture_and_log "allocate rootfs.img"
fallocate --verbose --length 512MiB "${BUILD}/esp.img" 2>&1| capture_and_log "allocate esp.img"

info "Formatting ESP as FAT32"
mkfs.vfat -F 32 -n EFI "${BUILD}/esp.img" 2>&1| capture_and_log "format esp"

info "Formatting root partition as ext4"
mkfs.ext4 -L "Pop!_OS" "${BUILD}/rootfs.img" 2>&1| capture_and_log "format rootfs"