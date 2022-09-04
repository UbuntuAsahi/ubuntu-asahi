#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/../00-config.sh"

rm -rf "${MNT_DIR}"
mkdir -p "${MNT_DIR}"
LOOP_DEV=$(losetup --find --show --partscan "${IMG_FILE}")
mkdir -p "${ROOTFS_LIVE_DIR}/boot/efi"
mount "${LOOP_DEV}p1" "${MNT_DIR}"
