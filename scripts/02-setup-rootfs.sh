#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/00-config.sh"

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
function cleanup {
	cd "${STARTING_DIR}"
	umount -Rf "${ROOTFS_BASE_DIR}/var/cache/apt/archives" || true
	umount -Rf "${ROOTFS_BASE_DIR}" || true
}
trap cleanup EXIT

# We copy the config script and the chroot script into the rootfs,
# as we are getting ready to run them inside our rootfs.
cp -f "${SCRIPTS_DIR}/00-config.sh" "${ROOTFS_BASE_DIR}"
cp -f "${SCRIPTS_DIR}/chroot-base.sh" "${ROOTFS_BASE_DIR}"
cp -rf "${FS_DEBS_DIR}" "${ROOTFS_BASE_DIR}/debs"

info "Bind mounting apt cache"
mount --bind "${ROOTFS_BASE_DIR}" "${ROOTFS_BASE_DIR}"
mkdir -p "${ROOTFS_BASE_DIR}/var/cache/apt/archives"
mount --bind "${CACHE_DIR}" "${ROOTFS_BASE_DIR}/var/cache/apt/archives"

# Alright, here's the fun part!
# arch-chroot is basically chroot, however it'll automatically
# set up all the /dev, /sys, /proc, etc mounts for us, and even
# run a fully functioning systemd within the chroot.
info "Spawning chroot via arch-chroot"
arch-chroot "${ROOTFS_BASE_DIR}" bash /chroot-base.sh

cp -f "${ROOTFS_BASE_DIR}/manifest" "${CHROOT_MANIFEST}"
rm -f "${ROOTFS_BASE_DIR}/chroot-base.sh"
rm -f "${ROOTFS_BASE_DIR}/manifest"

perl -p -i -e 's/root:x:/root::/' "${ROOTFS_BASE_DIR}/etc/passwd"
