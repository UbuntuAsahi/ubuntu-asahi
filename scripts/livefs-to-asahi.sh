#!/bin/bash

set -x
set -e

if [ "$(id -u)" != "0" ]; then
	echo "error: run as root"
	exit 1
fi

if [ ! -e "${ROOTFS_TARBALL}" ]; then
	echo "error: ROOTFS_TARBALL not set or file not found: ${ROOTFS_TARBALL}"
	exit 1
fi

EFI_UUID_RAW=$(uuidgen | tr -d '-' | cut -c1-8 | tr 'a-z' 'A-Z')
EFI_UUID="${EFI_UUID_RAW:0:4}-${EFI_UUID_RAW:4:4}"
ROOT_UUID=$(uuidgen)
BOOT_UUID=$(uuidgen)

SCRIPTS_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
BUILD_DIR="$(realpath "${SCRIPTS_DIR}/../build")"
CACHE_DIR="${BUILD_DIR}/cache"
FS_DIR="$(realpath "${SCRIPTS_DIR}/../fs")"
FS_DISK_DIR="${FS_DIR}/disk"
MNT_DIR="${BUILD_DIR}/mnt"
TMP_DIR="/tmp/ubuntu-asahi.build/"

BOOT_IMG_FILE="${BUILD_DIR}/ubuntu.boot.img"
ROOT_IMG_FILE="${BUILD_DIR}/ubuntu.root.img"
ESP_FILE=${BUILD_DIR}/ubuntu.efi.img

function log {
	echo "[$(tput setaf 2)$(tput bold)info$(tput sgr0)] $@"
}

# Go back to starting dir on script exit
function cleanup {
	sync
	umount -Rf "${MNT_DIR}/var/cache/apt/archives" || true
	umount -Rf "${MNT_DIR}/boot/efi" || true
	umount -Rf "${MNT_DIR}/boot" || true
	umount -Rf "${MNT_DIR}" || true
	losetup --detach "${ESP_LOOP_DEV}" 2>/dev/null || true
	losetup --detach "${BOOT_LOOP_DEV}" 2>/dev/null || true
	losetup --detach "${DISK_LOOP_DEV}" 2>/dev/null || true

	rm -rf "${MNT_DIR}"
	rm -f "${ESP_FILE}"
	rm -f "${ROOT_IMG_FILE}"
	rm -f "${BOOT_IMG_FILE}"
	rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

log "Creating ${ESP_FILE}"
rm -rf "${ESP_FILE}"
fallocate -l "1024MB" "${ESP_FILE}"
mkfs.msdos "${ESP_FILE}"

log "Creating ${ROOT_IMG_FILE}"
rm -rf "${ROOT_IMG_FILE}"
fallocate -l "8G" "${ROOT_IMG_FILE}"
mkfs.ext4 -O '^metadata_csum,^orphan_file' -U "${ROOT_UUID}" -L "ubuntu-root" "${ROOT_IMG_FILE}"

log "Creating ${BOOT_IMG_FILE}"
rm -rf "${BOOT_IMG_FILE}"
fallocate -l "2G" "${BOOT_IMG_FILE}"
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

log "Unpacking rootfs tarball"
tar -xz --numeric-owner --same-owner -p --xattrs --xattrs-include="*" -f \
    "${ROOTFS_TARBALL}" -C "${MNT_DIR}"

if echo "${ROOTFS_TARBALL}" | grep -q "\-server\-"; then
	project="server"
else
	project="desktop"
fi

VERSION=$(basename "${ROOTFS_TARBALL}" | cut -d'-' -f2)
DATE=$(date +%Y%m%d)
OUTPUT="${BUILD_DIR}/ubuntu-${project}-${VERSION}-${DATE}"

log "Syncing disk files to rootfs.disk"
rsync -arAHX --chown root:root "${FS_DISK_DIR}/" "${MNT_DIR}/"

log "Fixing fstab"
sed -i "s|ROOT_UUID|${ROOT_UUID}|g;s|EFI_UUID|${EFI_UUID}|g;s|BOOT_UUID|${BOOT_UUID}|g" \
    "${MNT_DIR}/etc/fstab"

cp -f "${SCRIPTS_DIR}/chroot-disk.sh" "${MNT_DIR}"

mkdir -p "${CACHE_DIR}"
mkdir -p "${MNT_DIR}/var/cache/apt/archives"
mount --bind "${CACHE_DIR}" "${MNT_DIR}/var/cache/apt/archives"

arch-chroot "${MNT_DIR}" /chroot-disk.sh "$project"
rm -f "${MNT_DIR}/chroot-disk.sh"

# Copy bootloaders
m1n1="${MNT_DIR}/usr/lib/m1n1/m1n1.bin"
if [ -e "${MNT_DIR}/usr/lib/u-boot-asahi/u-boot-nodtb.bin" ]; then
	uboot="${MNT_DIR}/usr/lib/u-boot-asahi/u-boot-nodtb.bin"
elif [ -e "${MNT_DIR}/usr/lib/u-boot/apple_m1/u-boot-nodtb.bin" ]; then
	uboot="${MNT_DIR}/usr/lib/u-boot/apple_m1/u-boot-nodtb.bin"
else
	echo "error: u-boot-nodtb.bin not found"
	exit 1
fi
if [ ! -e "${m1n1}" ]; then
	echo "error: m1n1.bin not found at ${m1n1}"
	exit 1
fi
dtbs=( "${MNT_DIR}"/lib/firmware/*/device-tree/apple/*.dtb )
if [ ${#dtbs[@]} -eq 0 ]; then
	echo "error: no DTB files found"
	exit 1
fi

mkdir -p "${MNT_DIR}"/boot/efi/m1n1
target="${MNT_DIR}/boot/efi/m1n1/boot.bin"
cat "${m1n1}" "${dtbs[@]}" \
    <(gzip -c "${uboot}") \
    >"${target}"

# Save ESP contents
mkdir -p "${TMP_DIR}"/esp
rsync -arAHX --chown root:root "${MNT_DIR}"/boot/efi/ "${TMP_DIR}/esp"

log "Unmounting"
umount -Rf "${MNT_DIR}"

log "Packing disk"
cp "${ROOT_IMG_FILE}" "${TMP_DIR}/root.img"
cp "${BOOT_IMG_FILE}" "${TMP_DIR}/boot.img"

log "Adding logo"
png2icns "${TMP_DIR}/logo.icns" "${SCRIPTS_DIR}/../media/logo/logo-256.png"

log "Compressing"
rm -f "${OUTPUT}.zip"
( cd "${TMP_DIR}"; zip -1 -r "${OUTPUT}.zip" * )
echo "${EFI_UUID}" > "${OUTPUT}.uuid"

log "Done."
