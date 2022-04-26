#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/00-config.sh"

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
function cleanup {
	cd "${STARTING_DIR}"
	umount -Rf "${ROOTFS_BASE_DIR}/boot/efi"
	losetup --associated "${IMG_FILE}" | cut -d ':' -f1 | while read LODEV
	do
		sudo losetup --detach "$LODEV"
	done
}
trap cleanup EXIT

# We copy the config script and the chroot script into the rootfs,
# as we are getting ready to run them inside our rootfs.
cp -f "${SCRIPTS_DIR}/00-config.sh" "${ROOTFS_BASE_DIR}"
cp -f "${SCRIPTS_DIR}/chroot-base.sh" "${ROOTFS_BASE_DIR}"

# Mount the EFI system partition
info "Mounting EFI partition"
LOOP_DEV=$(losetup --find --show --partscan "${IMG_FILE}")
mount "${LOOP_DEV}p1" "${ROOTFS_BASE_DIR}/boot/efi"

# Alright, here's the fun part!
# systemd-nspawn is basically chroot, however it'll automatically
# set up all the /dev, /sys, /proc, etc mounts for us, and even
# run a fully functioning systemd within the chroot.
info "Spawning chroot via systemd-nspawn"
systemd-nspawn \
	--machine=pop-os \
	--resolv-conf=off \
	--directory="${ROOTFS_BASE_DIR}" \
	bash /chroot-base.sh

rm -f "${ROOTFS_BASE_DIR}/chroot-base.sh"