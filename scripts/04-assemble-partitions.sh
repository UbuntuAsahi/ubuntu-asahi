#!/bin/bash
set -e

source $(dirname "$(readlink -f "$0")")/00-config.sh

# Go back to starting dir and clean up mounts on script exit
STARTING_DIR="$PWD"
function on_exit() {
	cd "$STARTING_DIR"
	sync
	if [ -f pop-os.img ]; then
		losetup --associated pop-os.img | cut -d ':' -f1 | while read LODEV
		do
			losetup --detach "$LODEV"
		done
	fi
}
trap on_exit EXIT

rm -f pop-os.img

info "Allocating Pop!_OS image file"
fallocate --verbose --length 7GiB pop-os.img 2>&1| capture_and_log "allocate pop-os.img"

info "Setting up partition table"
parted pop-os.img mktable gpt 2>&1| capture_and_log "create gpt table"
parted pop-os.img mkpart primary fat32 1MiB 512MiB 2>&1| capture_and_log "create esp"
parted pop-os.img set 1 esp on 2>&1| capture_and_log "make esp bootable"
parted pop-os.img mkpart primary ext4 512MiB 100%

# Get loopback partitions
LODEV="$(losetup --find --show --partscan pop-os.img)"

info "Formatting ESP as FAT32"
mkfs.vfat -F 32 -n EFI "${LODEV}p1" 2>&1| capture_and_log "format esp"

info "Formatting root partition as ext4"
mkfs.ext4 -L "Pop!_OS" "${LODEV}p2" 2>&1| capture_and_log "format rootfs"