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

# Calculate size of rootfs image
ROOTFS_SIZE_BYTES=$(du -sb rootfs | awk '{ printf $1 }')
# Round up the size 512 MB
ROOTFS_SIZE_ROUNDED_UP=$((($ROOTFS_SIZE_BYTES + $ROOTFS_ROUND_UP_BY) / $ROOTFS_ROUND_UP_BY * $ROOTFS_ROUND_UP_BY))
echo "Rootfs size: $ROOTFS_SIZE_BYTES (rounding up to $ROOTFS_SIZE_ROUNDED_UP)"

# Allocate space for rootfs image
fallocate -l "$ROOTFS_SIZE_ROUNDED_UP" rootfs.img

# Create ext4 in rootfs.img
mkfs.ext4 rootfs.img
tune2fs -O extents,uninit_bg,dir_index -m 0 -c 0 -i 0 rootfs.img

# Mount!
mkdir mnt
sudo mount -o loop rootfs.img mnt

# Rsync rootfs to mnt
rsync -ar rootfs/ mnt/