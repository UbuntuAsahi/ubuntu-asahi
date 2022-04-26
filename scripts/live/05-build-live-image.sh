#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/../00-config.sh"

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
function cleanup {
	cd "${STARTING_DIR}"
	umount -Rf "${IMG_MNT_DIR}"
	losetup --associated "${IMG_FILE}" | cut -d ':' -f1 | while read LODEV
	do
		sudo losetup --detach "$LODEV"
	done
}
trap cleanup EXIT

rm -rf "${IMG_MNT_DIR}"
mkdir -p "${IMG_MNT_DIR}"

info "Mounting image"
LOOP_DEV=$(losetup --find --show --partscan "${IMG_FILE}")
mount "${LOOP_DEV}p1" "${IMG_MNT_DIR}"
mkdir -p "${IMG_CASPER_DIR}"

info "Calculating filesystem size"
du -sx --block-size=1 "${ROOTFS_LIVE_DIR}" | cut -f1 > "${IMG_FILESYSTEM_SIZE_TAG}"

info "Squashing rootfs"
mksquashfs "${ROOTFS_LIVE_DIR}" "${IMG_ROOTFS_SQUASHED}" -noappend -fstime "$(date +%s)"

sed -i "s|CASPER_PATH|${CASPER_NAME}|g; s|DISTRO_CODE|${DISTRO_NAME}|g" "${IMG_MNT_DIR}/loader/entries/Pop_OS.conf"