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
rm -rf "${DISK_IMG_FILE}"
size="$(du -B M -s "${ROOTFS_DISK_DIR}" | cut -dM -f1)"
size=$(($size + ($size / 8) + 64))
fallocate -l "${size}M" ${DISK_IMG_FILE}
mkfs.ext4 -O '^metadata_csum' -U "${ROOT_UUID}" -L "ubuntu-root" "${DISK_IMG_FILE}"

# Create a loop device for the image file
LOOP_DEV=$(losetup --find --show --partscan "${DISK_IMG_FILE}")

info "Mounting image"
rm -rf "${MNT_DIR}"
mkdir -p "${MNT_DIR}"
mount "${LOOP_DEV}" "${MNT_DIR}"

info "Copying to disk"
rsync -aHAX \
    --exclude /files \
    --exclude '/tmp/*' \
    "${ROOTFS_DISK_DIR}/" "${MNT_DIR}/"

info "Updating grub config"
cat << END > "${MNT_DIR}/boot/grub/grub.cfg"
search.fs_uuid ${ROOT_UUID} root
set prefix=(\$root)'/boot/grub'
linux /boot/vmlinuz
initrd /boot/initrd.img
boot
END

# Enable service to update-grub after boot
systemctl enable first-boot

sync
umount -Rf "${MNT_DIR}"

info "Packing disk"
cp "${DISK_IMG_FILE}" "${MNT_DIR}/disk.img"
mkdir -p "${MNT_DIR}/esp/EFI/BOOT"
cp "${ROOTFS_DISK_DIR}/boot/grub/arm64-efi/core.efi" "${MNT_DIR}/esp/EFI/BOOT/BOOTAA64.EFI"
mkdir -p "${MNT_DIR}/esp/m1n1/"
cp "${FS_DIR}/boot.bin" "${MNT_DIR}/esp/m1n1/boot.bin"

info "Compressing"
rm -f "${DISK_IMG_FILE}.zip"
( cd "${MNT_DIR}"; zip -1 -r "${DISK_IMG_FILE}.zip" * )
