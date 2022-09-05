#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/../00-config.sh"

# Go back to starting dir on script exit
function cleanup {
	sync
	umount -Rf "${MNT_DIR}"
	losetup --associated "${DISK_IMG_FILE}" | cut -d ':' -f1 | while read LODEV
	do
		sudo losetup --detach "$LODEV"
	done
}
trap cleanup EXIT

info "Creating ${DISK_IMG_FILE}"
size="$(du -B M -s "${ROOTFS_DISK_DIR}" | cut -dM -f1)"
size=$(($size + ($size / 8) + 64))
fallocate -l "${size}M" ${DISK_IMG_FILE}
mkfs.ext4 -O '^metadata_csum' -U "${DISK_ROOT_UUID}" -L "ubuntu-root" "${DISK_IMG_FILE}"

# Create a loop device for the image file
LOOP_DEV=$(losetup --find --show --partscan "${DISK_IMG_FILE}")

info "Mounting image"
LOOP_DEV=$(losetup --find --show --partscan "${LIVE_IMG_FILE}")
mount "${LOOP_DEV}p1" "${MNT_DIR}"

info "Copying to disk"
rsync -aHAX \
    --exclude /files \
    --exclude '/tmp/*' \
    --exclude /etc/machine-id \
    "${ROOTFS_DISK_DIR}/" "${MNT_DIR}/"

info "Compressing"
rm -f "ubuntu.disk.zip"
( cd "${MNT_DIR}"; zip -1 -r "../ubuntu.disk.zip" * )
