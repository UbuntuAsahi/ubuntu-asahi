#!/bin/bash

set -x
set -e

EFI_UUID=2ABF-9F91
ROOT_UUID=87c6b0ce-3bb6-4dc2-9298-3a799bbb5994
BOOT_UUID=7cd3f710-4e54-4ded-834d-3dff58521005

SCRIPTS_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
BUILD_DIR="$(realpath "${SCRIPTS_DIR}/../build")"
CACHE_DIR="${BUILD_DIR}/cache"
FS_DIR="$(realpath "${SCRIPTS_DIR}/../fs")"
FS_DISK_DIR="${FS_DIR}/disk"
MNT_DIR="${BUILD_DIR}/mnt"
TMP_DIR="/tmp/ubuntu-asahi.build/"

BOOT_IMG_FILE="${BUILD_DIR}/ubuntu.boot.img"
ROOT_IMG_FILE="${BUILD_DIR}/ubuntu.disk.img"
LIVE_IMG_FILE="${BUILD_DIR}/ubuntu.live.img"
ESP_FILE=${BUILD_DIR}/ubuntu.efi.img

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
	losetup --associated "${ESP_FILE}" | cut -d ':' -f1 | while read LODEV
	do
		sudo losetup --detach "$LODEV"
	done
	losetup --associated "${BOOT_IMG_FILE}" | cut -d ':' -f1 | while read LODEV
	do
		sudo losetup --detach "$LODEV"
	done
	losetup --associated "${ROOT_IMG_FILE}" | cut -d ':' -f1 | while read LODEV
	do
		sudo losetup --detach "$LODEV"
	done
}
trap cleanup EXIT

log "Creating ${ESP_FILE}"
rm -rf "${ESP_FILE}"
fallocate -l "512MB" "${ESP_FILE}"
mkfs.msdos "${ESP_FILE}"

log "Creating ${ROOT_IMG_FILE}"
rm -rf "${ROOT_IMG_FILE}"
fallocate -l "8G" ${ROOT_IMG_FILE}
mkfs.ext4 -O '^metadata_csum,^orphan_file' -U "${ROOT_UUID}" -L "ubuntu-root" "${ROOT_IMG_FILE}"

log "Creating ${BOOT_IMG_FILE}"
rm -rf "${BOOT_IMG_FILE}"
fallocate -l "2G" ${BOOT_IMG_FILE}
mkfs.ext4 -O '^metadata_csum,^orphan_file' -U "${BOOT_UUID}" -L "ubuntu-boot" "${BOOT_IMG_FILE}"

# Create a loop device for the image file
ESP_LOOP_DEV=$(losetup --find --show --partscan "${ESP_FILE}")
BOOT_LOOP_DEV=$(losetup --find --show --partscan "${BOOT_IMG_FILE}")
DISK_LOOP_DEV=$(losetup --find --show --partscan "${ROOT_IMG_FILE}")

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
	tar -xzf "${ARTIFACT_DIR}"/livecd.*.rootfs.tar.gz -C "${MNT_DIR}"
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

# Copy bootloaders
m1n1="${MNT_DIR}/usr/lib/m1n1/m1n1.bin"
uboot="${MNT_DIR}/usr/lib/u-boot-asahi/u-boot-nodtb.bin"
dtbs="${MNT_DIR}/lib/firmware/*/device-tree/apple/*.dtb"

mkdir -p "${MNT_DIR}"/boot/efi/esp/m1n1
target="${MNT_DIR}/boot/efi/esp/m1n1/boot.bin"
cat ${m1n1} ${dtbs} \
    <(gzip -c ${uboot}) \
    >"${target}"

# Save ESP contents
mkdir -p "${TMP_DIR}"/esp
rsync -arAHX --chown root:root "${MNT_DIR}"/boot/efi/ "${TMP_DIR}"

log "Unmounting"
umount -Rf "${MNT_DIR}"

log "Packing disk"
cp "${ROOT_IMG_FILE}" "${TMP_DIR}/root.img"
cp "${BOOT_IMG_FILE}" "${TMP_DIR}/boot.img"

log "Compressing"
rm -f "${ROOT_IMG_FILE}.zip"
( cd "${TMP_DIR}"; zip -1 -r "${ROOT_IMG_FILE}.zip" * )

log "Cleaning up"
rm -rf "${MNT_DIR}"
rm -f "${ESP_FILE}"
rm -f "${ROOT_IMG_FILE}"
rm -f "${BOOT_IMG_FILE}"
rm -rf "${TMP_DIR}"
