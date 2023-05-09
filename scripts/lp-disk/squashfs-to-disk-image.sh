#!/bin/bash

set -e

source "$(dirname "$(readlink -f "$0")")/../00-config.sh"

# Go back to starting dir on script exit
function cleanup {
	sync
	umount -Rf "${MNT_DIR}/var/cache/apt/archives" || true
	umount -Rf "${MNT_DIR}"
	losetup --associated "${DISK_IMG_FILE}" | cut -d ':' -f1 | while read LODEV
	do
		sudo losetup --detach "$LODEV"
	done
}
trap cleanup EXIT

info "Creating ${DISK_IMG_FILE}"
rm -rf "${DISK_IMG_FILE}"
fallocate -l "8G" ${DISK_IMG_FILE}
mkfs.ext4 -O '^metadata_csum,^orphan_file' -U "${ROOT_UUID}" -L "ubuntu-root" "${DISK_IMG_FILE}"

# Create a loop device for the image file
LOOP_DEV=$(losetup --find --show --partscan "${DISK_IMG_FILE}")

info "Mounting image"
rm -rf "${MNT_DIR}"
mkdir -p "${MNT_DIR}"
mount "${LOOP_DEV}" "${MNT_DIR}"
chown root:root "${MNT_DIR}"

info "Copying to disk"
unsquashfs -d "${MNT_DIR}" "${SQUASHFS_FILE}" 
mkdir -p "${MNT_DIR}/boot/grub/efi"

info "Syncing disk files to rootfs.disk"
rsync -arAHX --chown root:root "${FS_DISK_DIR}/" "${MNT_DIR}/"

info "Fixing fstab"
sed -i "s|ROOT_UUID|${ROOT_UUID}|g;s|EFI_UUID|${EFI_UUID}|g" \
    "${MNT_DIR}/etc/fstab"

cp -f "${SCRIPTS_DIR}/00-config.sh" "${MNT_DIR}"
cp -f "${SCRIPTS_DIR}/lp-disk/chroot-disk.sh" "${MNT_DIR}"

mkdir -p "${CACHE_DIR}"
mkdir -p "${MNT_DIR}/var/cache/apt/archives"
mount --bind "${CACHE_DIR}" "${MNT_DIR}/var/cache/apt/archives"

systemd-nspawn --resolv-conf=delete -D "${MNT_DIR}" bash /chroot-disk.sh

rm -f "${MNT_DIR}/chroot-disk.sh"

info "Updating grub config"
mkdir -p "${MNT_DIR}/boot/grub"
cat << END > "${MNT_DIR}/boot/grub/grub.cfg"
search.fs_uuid ${ROOT_UUID} root
set prefix=(\$root)'/boot/grub'
linux /boot/vmlinuz root=/dev/disk/by-uuid/${ROOT_UUID} quiet splash
initrd /boot/initrd.img
boot
END

mkdir -p "${TMP_DIR}"

# Copy bootloaders
m1n1="${MNT_DIR}/usr/share/m1n1/m1n1.bin"
uboot="${MNT_DIR}/usr/share/u-boot-asahi/u-boot-nodtb.bin"
dtbs="${MNT_DIR}/lib/firmware/*-asahi/device-tree/apple/*.dtb"
target="${TMP_DIR}/boot.bin"
cat ${m1n1} ${dtbs} \
    <(gzip -c ${uboot}) \
    >"${target}"
cp "${MNT_DIR}/boot/grub/arm64-efi/core.efi" "${TMP_DIR}/BOOTAA64.EFI"

sync
umount -Rf "${MNT_DIR}"

info "Packing disk"
cp "${DISK_IMG_FILE}" "${MNT_DIR}/disk.img"

# install grub
mkdir -p "${MNT_DIR}/esp/EFI/BOOT"
cp "${TMP_DIR}/BOOTAA64.EFI" "${MNT_DIR}/esp/EFI/BOOT/BOOTAA64.EFI"

# install m1n1
mkdir -p "${MNT_DIR}/esp/m1n1/"
cp "${TMP_DIR}/boot.bin" "${MNT_DIR}/esp/m1n1/boot.bin"

info "Compressing"
rm -f "${DISK_IMG_FILE}.zip"
( cd "${MNT_DIR}"; zip -1 -r "${DISK_IMG_FILE}.zip" * )
rm -rf "${MNT_DIR}"
