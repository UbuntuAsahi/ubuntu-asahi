#!/bin/bash

set -e

source "$(dirname "$(readlink -f "$0")")/../00-config.sh"

# Go back to starting dir on script exit
function cleanup {
	sync
	umount -Rf "${MNT_DIR}/var/cache/apt/archives" || true
	umount -Rf "${MNT_DIR}/boot"
	umount -Rf "${MNT_DIR}"
	losetup --associated "${BOOT_IMG_FILE}" | cut -d ':' -f1 | while read LODEV
	do
		sudo losetup --detach "$LODEV"
	done
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

info "Creating ${BOOT_IMG_FILE}"
rm -rf "${BOOT_IMG_FILE}"
fallocate -l "2G" ${BOOT_IMG_FILE}
mkfs.ext4 -O '^metadata_csum,^orphan_file' -U "${BOOT_UUID}" -L "ubuntu-boot" "${BOOT_IMG_FILE}"

# Create a loop device for the image file
BOOT_LOOP_DEV=$(losetup --find --show --partscan "${BOOT_IMG_FILE}")
DISK_LOOP_DEV=$(losetup --find --show --partscan "${DISK_IMG_FILE}")

info "Mounting image"
rm -rf "${MNT_DIR}"
mkdir -p "${MNT_DIR}"
mount "${DISK_LOOP_DEV}" "${MNT_DIR}"
mkdir -p "${MNT_DIR}/boot"
mount "${BOOT_LOOP_DEV}" "${MNT_DIR}"/boot
chown -R root:root "${MNT_DIR}"

# Figure out livecd-rootfs project
if find "${ARTIFACT_DIR}"/livecd.ubuntu-asahi.*.squashfs -quit; then
	# Ubuntu > 23.04 images come with a different squashfs format
	unsquashfs -f -d "${MNT_DIR}" "${ARTIFACT_DIR}"/livecd.ubuntu-asahi.install.squashfs
	unsquashfs -f -d "${MNT_DIR}" "${ARTIFACT_DIR}"/livecd.ubuntu-asahi.minimal.squashfs
	unsquashfs -f -d "${MNT_DIR}" "${ARTIFACT_DIR}"/livecd.ubuntu-asahi.minimal.standard.squashfs
	# unsquashfs -f -d "${MNT_DIR}" "${ARTIFACT_DIR}"/livecd.ubuntu-asahi.minimal.standard.en.squashfs
elif find "${ARTIFACT_DIR}"/livecd.ubuntu-asahi.squashfs -quit; then
	# Flavors and older Ubuntu releases use stacked squashfs and ship kernel + initrd in extra files
	info "Copying to disk"
	for filename in "${ARTIFACT_DIR}"/*.squashfs; do
		unsquashfs -d "${MNT_DIR}" "${filename}"
	done

	info "Installing kernel and initrd"
	initrd=("${ARTIFACT_DIR}/"*.initrd-apple-arm)
	kern=("${ARTIFACT_DIR}/"*.kernel-apple-arm)
	cp "${initrd[0]}" "$(readlink -f "${MNT_DIR}/boot/initrd.img")"
	cp "${kern[0]}" "$(readlink -f "${MNT_DIR}/boot/vmlinuz")"

	mkdir -p "${MNT_DIR}/boot/efi"
	cp "${ARTIFACT_DIR}"/livecd.*.manifest-remove "${MNT_DIR}"
elif find "${ARTIFACT_DIR}"/livecd.ubuntu-asahi.rootfs.tar.gz -quit; then
	# Format == plain
	info "Copying to disk"
	tar -xzf "${ARTIFACT_DIR}"/livecd.ubuntu-asahi.rootfs.tar.gz -C "${MNT_DIR}"
	mkdir -p "${MNT_DIR}/boot/efi"
	cp "${ARTIFACT_DIR}"/livecd.*.manifest-remove "${MNT_DIR}"
fi

info "Syncing disk files to rootfs.disk"
rsync -arAHX --chown root:root "${FS_DISK_DIR}/" "${MNT_DIR}/"

info "Fixing fstab"
sed -i "s|ROOT_UUID|${ROOT_UUID}|g;s|EFI_UUID|${EFI_UUID}|g;s|BOOT_UUID|${BOOT_UUID}|g" \
    "${MNT_DIR}/etc/fstab"

cp -f "${SCRIPTS_DIR}/00-config.sh" "${MNT_DIR}"
cp -f "${SCRIPTS_DIR}/lp-disk/chroot-disk.sh" "${MNT_DIR}"

mkdir -p "${CACHE_DIR}"
mkdir -p "${MNT_DIR}/var/cache/apt/archives"
mount --bind "${CACHE_DIR}" "${MNT_DIR}/var/cache/apt/archives"

info "Updating grub config"
mkdir -p "${MNT_DIR}/boot/grub"
cat << END > "${MNT_DIR}/boot/grub/grub.cfg"
search.fs_uuid ${BOOT_UUID} boot
set prefix=(\$boot)'/boot/grub'
END

systemd-nspawn --resolv-conf=delete -D "${MNT_DIR}" bash /chroot-disk.sh

rm -f "${MNT_DIR}/chroot-disk.sh"
rm -f "${MNT_DIR}"/livecd.*.manifest-remove

mkdir -p "${TMP_DIR}"

# Copy bootloaders
m1n1="${MNT_DIR}/usr/lib/m1n1/m1n1.bin"
uboot="${MNT_DIR}/usr/lib/u-boot-asahi/u-boot-nodtb.bin"
dtbs="${MNT_DIR}/lib/firmware/*/device-tree/apple/*.dtb"
target="${TMP_DIR}/boot.bin"
cat ${m1n1} ${dtbs} \
    <(gzip -c ${uboot}) \
    >"${target}"
cp "${MNT_DIR}/boot/grub/arm64-efi/core.efi" "${TMP_DIR}/BOOTAA64.EFI"

sync
umount -Rf "${MNT_DIR}"

info "Packing disk"
cp "${DISK_IMG_FILE}" "${MNT_DIR}/root.img"
cp "${BOOT_IMG_FILE}" "${MNT_DIR}/boot.img"

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
