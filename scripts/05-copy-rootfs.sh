#!/bin/bash
set -e

source $(dirname "$(readlink -f "$0")")/00-config.sh

# Go back to starting dir and clean up mounts on script exit
STARTING_DIR="$PWD"
function on_exit() {
	cd "$STARTING_DIR"
	sync
	sudo umount -Rf mnt
	sudo rm -rf mnt
	sudo losetup --associated pop-os.img | cut -d ':' -f1 | while read LODEV
	do
		sudo losetup --detach "$LODEV"
	done
}
trap on_exit EXIT

# Get loopback partitions
LODEV="$(sudo losetup --find --show --partscan pop-os.img)"

# Mount!
info "Mounting rootfs.img"
mkdir -p mnt
sudo mount -o rw "${LODEV}p2" mnt 2>&1| capture_and_log "mount rootfs.img"

# Rsync rootfs to mnt
info "Copying rootfs to mounted rootfs.img"
sudo rsync -arv rootfs/ mnt/ 2>&1| capture_and_log "copy rootfs"