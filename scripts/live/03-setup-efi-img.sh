#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/../00-config.sh"

function cleanup {
	losetup --associated "${LIVE_IMG_FILE}" | cut -d ':' -f1 | while read LODEV
	do
		sudo losetup --detach "$LODEV"
	done
}
trap cleanup EXIT

info "Creating ubuntu.live.img"
# Allocate a 3GiB image file (4/29/22 - image was 2.7G, setting it to 3GiB to leave space for future expansions)
fallocate -l 3G "${LIVE_IMG_FILE}"

# Create a 4GiB partition
parted -s "${LIVE_IMG_FILE}" mklabel gpt
parted -s "${LIVE_IMG_FILE}" mkpart primary fat32 1MiB 100%
parted -s "${LIVE_IMG_FILE}" set 1 esp on

# Create a loop device for the image file
LOOP_DEV=$(losetup --find --show --partscan "${LIVE_IMG_FILE}")

# Create a filesystem on the loop device
mkfs.vfat -F32 "${LOOP_DEV}p1"
