#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/../00-config.sh"

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
function cleanup {
	cd "${STARTING_DIR}"
	sync
	umount -Rf "${ROOTFS_LIVE_DIR}/boot/efi" || true
	umount -Rf "${ROOTFS_LIVE_DIR}/var/cache/apt/archives" || true
	losetup --associated "${LIVE_IMG_FILE}" | cut -d ':' -f1 | while read LODEV
	do
		losetup --detach "$LODEV"
	done
}
trap cleanup EXIT

info "Copying rootfs.base to rootfs.live"
rm -rf "${ROOTFS_LIVE_DIR}"
cp -a "${ROOTFS_BASE_DIR}" "${ROOTFS_LIVE_DIR}"

info "Syncing live files to rootfs.live"
rsync -arv "${FS_LIVE_DIR}/" "${ROOTFS_LIVE_DIR}/"

# fstab must be empty for casper
rm -rf "${ROOTFS_LIVE_DIR}/etc/fstab"

# Mount the EFI system partition
info "Mounting EFI partition to /boot/efi"
LOOP_DEV=$(losetup --find --show --partscan "${LIVE_IMG_FILE}")
mkdir -p "${ROOTFS_LIVE_DIR}/boot/efi"
mount "${LOOP_DEV}p1" "${ROOTFS_LIVE_DIR}/boot/efi"

info "Syncing live EFI files to ESP"
rm -rf "${ROOTFS_LIVE_DIR}/boot/efi/*"
rsync -rv "${FS_LIVE_EFI_DIR}/" "${ROOTFS_LIVE_DIR}/boot/efi/"

cp -f "${SCRIPTS_DIR}/00-config.sh" "${ROOTFS_LIVE_DIR}"
cp -f "${SCRIPTS_DIR}/live/chroot-live.sh" "${ROOTFS_LIVE_DIR}"
cp -rf "${FS_DEBS_DIR}" "${ROOTFS_LIVE_DIR}/debs"

info "Bind mounting apt cache"
mkdir -p "${ROOTFS_LIVE_DIR}/var/cache/apt/archives"
mount --bind "${CACHE_DIR}" "${ROOTFS_LIVE_DIR}/var/cache/apt/archives"

info "Spawning chroot via systemd-nspawn"
systemd-nspawn \
	--machine=ubuntu \
	--resolv-conf=off \
	--directory="${ROOTFS_LIVE_DIR}" \
	bash /chroot-live.sh

cp -f "${ROOTFS_LIVE_DIR}/manifest" "${LIVE_MANIFEST}"
rm -rf "${ROOTFS_LIVE_DIR}/chroot-live.sh"
rm -f "${ROOTFS_LIVE_DIR}/manifest"
