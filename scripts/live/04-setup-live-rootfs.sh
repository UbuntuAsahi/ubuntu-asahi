#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/../00-config.sh"

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
function cleanup {
	cd "${STARTING_DIR}"
	sync
	umount -Rf "${ROOTFS_LIVE_DIR}/iso"
	losetup --associated "${IMG_FILE}" | cut -d ':' -f1 | while read LODEV
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

# Mount the EFI system partition
info "Mounting EFI partition to /iso"
LOOP_DEV=$(losetup --find --show --partscan "${IMG_FILE}")
mkdir -p "${ROOTFS_LIVE_DIR}/iso"
mount "${LOOP_DEV}p1" "${ROOTFS_LIVE_DIR}/iso"

info "Syncing live EFI files to ESP"
rsync -rv "${FS_LIVE_EFI_DIR}/" "${ROOTFS_LIVE_DIR}/iso/"

cp -f "${SCRIPTS_DIR}/00-config.sh" "${ROOTFS_LIVE_DIR}"
cp -f "${SCRIPTS_DIR}/live/chroot-live.sh" "${ROOTFS_LIVE_DIR}"
cp -rf "${FS_LIVE_DEBS_DIR}" "${ROOTFS_LIVE_DIR}/debs"

info "Spawning chroot via systemd-nspawn"
systemd-nspawn \
	--machine=pop-os \
	--resolv-conf=off \
	--directory="${ROOTFS_LIVE_DIR}" \
	bash /chroot-live.sh

cp -f "${ROOTFS_LIVE_DIR}/manifest" "${LIVE_MANIFEST}"
rm -rf "${ROOTFS_LIVE_DIR}/chroot-live.sh"
rm -f "${ROOTFS_LIVE_DIR}/manifest"