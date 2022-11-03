#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/../00-config.sh"

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
function cleanup {
	cd "${STARTING_DIR}"
	sync
	umount -Rf "${ROOTFS_DISK_DIR}" || true
	umount -Rf "${ROOTFS_DISK_DIR}/var/cache/apt/archives" || true
}
trap cleanup EXIT

info "Copying rootfs.base to rootfs.disk"
rm -rf "${ROOTFS_DISK_DIR}"
rsync -arAHX "${ROOTFS_BASE_DIR}/" "${ROOTFS_DISK_DIR}/"

info "Syncing disk files to rootfs.disk"
rsync -arAHX --chown root:root "${FS_DISK_DIR}/" "${ROOTFS_DISK_DIR}/"

info "Fixing fstab"
sed -i "s|ROOT_UUID|${ROOT_UUID}|g;s|EFI_UUID|${EFI_UUID}|g" \
    "${ROOTFS_DISK_DIR}/etc/fstab"

cp -f "${SCRIPTS_DIR}/00-config.sh" "${ROOTFS_DISK_DIR}"
cp -f "${SCRIPTS_DIR}/disk/chroot-disk.sh" "${ROOTFS_DISK_DIR}"
cp -rf "${FS_DEBS_DIR}" "${ROOTFS_DISK_DIR}/debs"

info "Bind mounting apt cache"
mount --bind "${ROOTFS_DISK_DIR}" "${ROOTFS_DISK_DIR}"
mkdir -p "${ROOTFS_DISK_DIR}/var/cache/apt/archives"
mount --bind "${CACHE_DIR}" "${ROOTFS_DISK_DIR}/var/cache/apt/archives"

info "Spawning arch-chroot"
arch-chroot "${ROOTFS_DISK_DIR}" \
    bash /chroot-disk.sh

rm -rf "${ROOTFS_DISK_DIR}/chroot-disk.sh"
