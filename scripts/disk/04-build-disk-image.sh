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
mkfs.ext4 -O '^metadata_csum,^orphan_file' -U "${ROOT_UUID}" -L "ubuntu-root" "${DISK_IMG_FILE}"

# Create a loop device for the image file
LOOP_DEV=$(losetup --find --show --partscan "${DISK_IMG_FILE}")

info "Mounting image"
rm -rf "${MNT_DIR}"
mkdir -p "${MNT_DIR}"
mount "${LOOP_DEV}" "${MNT_DIR}"
chown root:root "${MNT_DIR}"

info "Copying to disk"
rsync -aHAX \
    --exclude /files \
    --exclude '/tmp/*' \
    --exclude '/etc/machine-id' \
    "${ROOTFS_DISK_DIR}/" "${MNT_DIR}/"

info "Updating grub config"
cat << END > "${MNT_DIR}/boot/grub/grub.cfg"
search.fs_uuid ${ROOT_UUID} root
set prefix=(\$root)'/boot/grub'
linux /boot/vmlinuz rw quiet splash
initrd /boot/initrd.img
boot
END

sync
umount -Rf "${MNT_DIR}"

info "Packing disk"
cp "${DISK_IMG_FILE}" "${MNT_DIR}/disk.img"
mkdir -p "${MNT_DIR}/esp/EFI/BOOT"
cp "${ROOTFS_DISK_DIR}/boot/grub/arm64-efi/core.efi" "${MNT_DIR}/esp/EFI/BOOT/BOOTAA64.EFI"

# Install m1n1
m1n1="${ROOTFS_DISK_DIR}/usr/share/m1n1/m1n1.bin"
uboot="${ROOTFS_DISK_DIR}/usr/share/u-boot-asahi/u-boot-nodtb.bin"
dtbs="${ROOTFS_DISK_DIR}/lib/firmware/*-asahi/device-tree/apple/*.dtb"
target="${MNT_DIR}/esp/m1n1/boot.bin"
mkdir -p "${MNT_DIR}/esp/m1n1/"
cat ${m1n1} ${dtbs} \
    <(gzip -c ${uboot}) \
    >"${target}.new"
mv -f "${target}.new" "$target"

info "Compressing"
rm -f "${DISK_IMG_FILE}.zip"
( cd "${MNT_DIR}"; zip -1 -r "${DISK_IMG_FILE}.zip" * )
rm -rf "${MNT_DIR}"
