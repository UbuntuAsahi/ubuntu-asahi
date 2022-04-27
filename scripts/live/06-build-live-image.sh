#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/../00-config.sh"

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
function cleanup {
	cd "${STARTING_DIR}"
	sync
	umount -Rf "${MNT_DIR}"
	losetup --associated "${IMG_FILE}" | cut -d ':' -f1 | while read LODEV
	do
		sudo losetup --detach "$LODEV"
	done
}
trap cleanup EXIT

rm -rf "${MNT_DIR}"
mkdir -p "${MNT_DIR}"

info "Mounting image"
LOOP_DEV=$(losetup --find --show --partscan "${IMG_FILE}")
mount "${LOOP_DEV}p1" "${MNT_DIR}"
mkdir -p "${CASPER_DIR}"

info "Creating filesystem manifests"
cp "${CHROOT_MANIFEST}" "${CASPER_DIR}/filesystem.manifest"
grep -F -x -v -f "${CHROOT_MANIFEST}" "${LIVE_MANIFEST}" | cut -f1 > "${CASPER_DIR}/filesystem.manifest-remove"

info "Calculating filesystem size"
du -sx --block-size=1 "${ROOTFS_LIVE_DIR}" | cut -f1 > "${FILESYSTEM_SIZE_TAG}"

info "Squashing rootfs"
mksquashfs "${ROOTFS_LIVE_DIR}" "${ROOTFS_SQUASHED}" -noappend -fstime "$(date +%s)"

sed -i "${SED_PATTERN}" "${MNT_DIR}/loader/entries/Pop_OS.conf"