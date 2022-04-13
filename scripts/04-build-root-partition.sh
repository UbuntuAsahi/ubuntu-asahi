#!/bin/bash
set -e

source $(dirname "$(readlink -f "$0")")/00-config.sh

# Go back to starting dir and clean up mounts on script exit
STARTING_DIR="$PWD"
function on_exit() {
	sudo umount -Rf mnt || true
	sudo rm -rf mnt
	cd "$STARTING_DIR"
}
trap on_exit EXIT

# Calculate size of rootfs image
ROOTFS_SIZE_BYTES=$(sudo du -sb rootfs | awk '{ printf $1 }')
ROOTFS_SIZE_ROUNDED_UP=$(((($ROOTFS_SIZE_BYTES / 1024 / 1024) + $ROOTFS_ROUND_UP_BY) / $ROOTFS_ROUND_UP_BY * $ROOTFS_ROUND_UP_BY))
info "Base rootfs size: $(bold $(($ROOTFS_SIZE_BYTES / 1024))) MiB (rounding up to $(bold $ROOTFS_SIZE_ROUNDED_UP) MiB)"

# Allocate space for rootfs image
info "Allocating rootfs.img"
dd if=/dev/zero of=rootfs.img bs=1M count="$ROOTFS_SIZE_ROUNDED_UP" status=progress 2>&1| capture_and_log "allocate rootfs.img"

# Create ext4 in rootfs.img
info "Creating ext4 partition in rootfs.img"
mkfs.ext4 -L "Pop!_OS" rootfs.img 2>&1| capture_and_log "make rootfs.img fs"
#tune2fs -O extents,uninit_bg,dir_index -m 0 -c 0 -i 0 rootfs.img

# Mount!
info "Mounting rootfs.img"
mkdir mnt
sudo mount -o loop,rw rootfs.img mnt 2>&1| capture_and_log "mount rootfs.img"

# Rsync rootfs to mnt
info "Copying rootfs to mounted rootfs.img"
sudo rsync -arv rootfs/ mnt/ 2>&1| capture_and_log "copy rootfs"