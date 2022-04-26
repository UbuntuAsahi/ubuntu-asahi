#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/00-config.sh"

function cleanup {
	losetup --associated "${IMG_FILE}" | cut -d ':' -f1 | while read LODEV
	do
		sudo losetup --detach "$LODEV"
	done
}
trap cleanup EXIT

# Allocate a 4GiB image file
fallocate -l 4G "${IMG_FILE}"

# Create a 4GiB partition
parted -s "${IMG_FILE}" mklabel gpt
parted -s "${IMG_FILE}" mkpart primary fat32 1MiB 100%
parted -s "${IMG_FILE}" set 1 esp on

# Create a loop device for the image file
LOOP_DEV=$(losetup --find --show --partscan "${IMG_FILE}")

# Create a filesystem on the loop device
mkfs.vfat -F32 "${LOOP_DEV}p1"


