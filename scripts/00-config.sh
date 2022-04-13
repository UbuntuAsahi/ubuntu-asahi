#!/bin/bash
set -a
# How big is the boot partition? (default: 150 MB)
BOOT_IMG_SIZE=${BOOT_IMG_SIZE:-153600}
# How much to round up the base rootfs image size by (default: 512 MB)
ROOTFS_ROUND_UP_BY=${ROOTFS_ROUND_UP_BY:-$((512 * 1024 * 1024))}