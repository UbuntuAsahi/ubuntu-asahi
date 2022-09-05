#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/../00-config.sh"

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
function cleanup {
	cd "${STARTING_DIR}"
	sync
	umount -Rf "${ROOTFS_DISK_DIR}/boot/efi" || true
	umount -Rf "${ROOTFS_DISK_DIR}/var/cache/apt/archives" || true
	losetup --associated "${LIVE_IMG_FILE}" | cut -d ':' -f1 | while read LODEV
	do
		losetup --detach "$LODEV"
	done
}
trap cleanup EXIT

info "Copying rootfs.base to rootfs.disk"
rm -rf "${ROOTFS_DISK_DIR}"
cp -a "${ROOTFS_BASE_DIR}" "${ROOTFS_DISK_DIR}"

info "Syncing disk files to rootfs.disk"
rsync -arv "${FS_DISK_DIR}/" "${ROOTFS_DISK_DIR}/"

mkdir -p "${ROOTFS_DISK}/boot/efi"
# # Mount the root partition
# info "Mounting root partition to /boot/efi"
# LOOP_DEV=$(losetup --find --show --partscan "${DISK_IMG_FILE}")
# mount "${LOOP_DEV}p1" "${ROOTFS_DISK_DIR}/boot/efi"

info "Syncing disk EFI files to ESP"
rm -rf "${ROOTFS_DISK_DIR}/boot/efi/*"
rsync -rv "${FS_DISK_EFI_DIR}/" "${ROOTFS_DISK_DIR}/boot/efi/"

cp -f "${SCRIPTS_DIR}/00-config.sh" "${ROOTFS_DISK_DIR}"
cp -f "${SCRIPTS_DIR}/disk/chroot-disk.sh" "${ROOTFS_DISK_DIR}"
cp -rf "${FS_DEBS_DIR}" "${ROOTFS_DISK_DIR}/debs"

info "Bind mounting apt cache"
mkdir -p "${ROOTFS_DISK_DIR}/var/cache/apt/archives"
mount --bind "${CACHE_DIR}" "${ROOTFS_DISK_DIR}/var/cache/apt/archives"

info "Spawning arch-chroot"
arch-chroot "${ROOTFS_DISK_DIR}" \
    bash /chroot-disk.sh

rm -rf "${ROOTFS_DISK_DIR}/chroot-disk.sh"
