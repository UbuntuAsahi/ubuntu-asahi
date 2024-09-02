#!/bin/bash

set -e

EFI_UUID=$(uuidgen | tr -d '-' | cut -c1-8)
ROOT_UUID=$(uuidgen)
BOOT_UUID=$(uuidgen)

SCRIPTS_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
BUILD_DIR="$(realpath "${SCRIPTS_DIR}/../build")"
CACHE_DIR="${BUILD_DIR}/cache"
FS_DIR="$(realpath "${SCRIPTS_DIR}/../fs")"
FS_DISK_DIR="${FS_DIR}/disk"
MNT_DIR="${BUILD_DIR}/mnt"
TMP_DIR="/tmp/ubuntu-asahi.build/"

LIVE_IMG_FILE="${BUILD_DIR}/ubuntu.live.img"

function log {
	echo "[$(tput setaf 2)$(tput bold)info$(tput sgr0)] $@"
}

# Go back to starting dir on script exit
function cleanup {
	sync
	umount -Rf "${MNT_DIR}/var/cache/apt/archives" || true
	umount -Rf "${MNT_DIR}/boot/efi"
	umount -Rf "${MNT_DIR}/boot"
	umount -Rf "${MNT_DIR}"
	losetup --associated "${LIVE_LOOP_DEV}p3" | cut -d ':' -f1 | while read LODEV
	do
		sudo losetup --detach "$LODEV"
	done
	losetup --associated "${LIVE_LOOP_DEV}p2" | cut -d ':' -f1 | while read LODEV
	do
		sudo losetup --detach "$LODEV"
	done
	losetup --associated "${LIVE_LOOP_DEV}p1" | cut -d ':' -f1 | while read LODEV
	do
		sudo losetup --detach "$LODEV"
	done
	losetup --associated "${LIVE_IMG_FILE}" | cut -d ':' -f1 | while read LODEV
	do
		sudo losetup --detach "$LODEV"
	done
}
trap cleanup EXIT

log "Creating live image"
fallocate -l "8GiB" "${LIVE_IMG_FILE}"

log "Creating partitions"
parted -s "${LIVE_IMG_FILE}" mklabel gpt
parted -s "${LIVE_IMG_FILE}" mkpart primary fat32 1MiB 200MiB
parted -s "${LIVE_IMG_FILE}" mkpart ext4 200MiB 1GiB
parted -s "${LIVE_IMG_FILE}" mkpart ext4 1GiB 100%
parted -s "${LIVE_IMG_FILE}" set 1 esp on

LIVE_LOOP_DEV=$(losetup --find --show --partscan "${LIVE_IMG_FILE}")

log "Creating file systems"
mkfs.vfat -F32 -i "${EFI_UUID}" "${LIVE_LOOP_DEV}p1"
mkfs.ext4 -O '^metadata_csum,^orphan_file' -U "${BOOT_UUID}" -L "ubuntu-boot" "${LIVE_LOOP_DEV}p2"
mkfs.ext4 -O '^metadata_csum,^orphan_file' -U "${ROOT_UUID}" -L "ubuntu-root" "${LIVE_LOOP_DEV}p3"

# Create a loop device for the image file
ESP_LOOP_DEV=$(losetup --find --show --partscan "${LIVE_LOOP_DEV}p1")
BOOT_LOOP_DEV=$(losetup --find --show --partscan "${LIVE_LOOP_DEV}p2")
DISK_LOOP_DEV=$(losetup --find --show --partscan "${LIVE_LOOP_DEV}p3")

log "Mounting image"
rm -rf "${MNT_DIR}"
mkdir -p "${MNT_DIR}"
mount "${DISK_LOOP_DEV}" "${MNT_DIR}"
mkdir -p "${MNT_DIR}/boot"
mount "${BOOT_LOOP_DEV}" "${MNT_DIR}"/boot
mkdir -p "${MNT_DIR}/boot/efi"
mount "${ESP_LOOP_DEV}" "${MNT_DIR}"/boot/efi
chown -R root:root "${MNT_DIR}"

# Figure out livecd-rootfs project
if find "${ARTIFACT_DIR}"/livecd.ubuntu-asahi.*.squashfs -quit; then
	# Ubuntu > 23.04 images come with a different squashfs format
	log "Copying to disk"
	unsquashfs -f -d "${MNT_DIR}" "${ARTIFACT_DIR}"/livecd.ubuntu-asahi.install.squashfs
	unsquashfs -f -d "${MNT_DIR}" "${ARTIFACT_DIR}"/livecd.ubuntu-asahi.minimal.squashfs
	unsquashfs -f -d "${MNT_DIR}" "${ARTIFACT_DIR}"/livecd.ubuntu-asahi.minimal.standard.squashfs
	# unsquashfs -f -d "${MNT_DIR}" "${ARTIFACT_DIR}"/livecd.ubuntu-asahi.minimal.standard.en.squashfs
elif find "${ARTIFACT_DIR}"/livecd.ubuntu-asahi.squashfs -quit; then
	# Flavors and older Ubuntu releases use stacked squashfs and ship kernel + initrd in extra files
	log "Copying to disk"
	for filename in "${ARTIFACT_DIR}"/*.squashfs; do
		unsquashfs -d "${MNT_DIR}" "${filename}"
	done

	log "Installing kernel and initrd"
	initrd=("${ARTIFACT_DIR}/"*.initrd-apple-arm)
	kern=("${ARTIFACT_DIR}/"*.kernel-apple-arm)
	cp "${initrd[0]}" "$(readlink -f "${MNT_DIR}/boot/initrd.img")"
	cp "${kern[0]}" "$(readlink -f "${MNT_DIR}/boot/vmlinuz")"

	mkdir -p "${MNT_DIR}/boot/efi"
	cp "${ARTIFACT_DIR}"/livecd.*.manifest-remove "${MNT_DIR}"
elif find "${ARTIFACT_DIR}"/livecd.*.rootfs.tar.gz -quit; then
	# Format == plain
	log "Copying to disk"
	tar -xz --numeric-owner --same-owner -p --xattrs --xattrs-include="*" -f \
	    "${ARTIFACT_DIR}"/livecd.*.rootfs.tar.gz -C "${MNT_DIR}"
	mkdir -p "${MNT_DIR}/boot/efi"
	cp "${ARTIFACT_DIR}"/livecd.*.manifest-remove "${MNT_DIR}"
fi

log "Syncing disk files to rootfs.disk"
rsync -arAHX --chown root:root "${FS_DISK_DIR}/" "${MNT_DIR}/"

log "Fixing fstab"
sed -i "s|ROOT_UUID|${ROOT_UUID}|g;s|EFI_UUID|${EFI_UUID}|g;s|BOOT_UUID|${BOOT_UUID}|g" \
    "${MNT_DIR}/etc/fstab"

cp -f "${SCRIPTS_DIR}/chroot-disk.sh" "${MNT_DIR}"

mkdir -p "${CACHE_DIR}"
mkdir -p "${MNT_DIR}/var/cache/apt/archives"
mount --bind "${CACHE_DIR}" "${MNT_DIR}/var/cache/apt/archives"

arch-chroot ${MNT_DIR} /chroot-disk.sh
rm -f "${MNT_DIR}/chroot-disk.sh"
rm -f "${MNT_DIR}"/livecd.*.manifest-remove

log "Done."
