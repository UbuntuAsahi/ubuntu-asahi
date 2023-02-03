#!/bin/bash

if [[ "${EUID:-$(id -u)}" != 0 ]]; then
	echo "This script must be run as root."
	exit 1
fi

set -xe

mkdir -p build
cd build

../scripts/01-build-base-rootfs.sh
../scripts/02-setup-rootfs.sh

../scripts/live/03-setup-efi-img.sh
../scripts/live/04-setup-live-rootfs.sh
../scripts/live/05-setup-pool.sh
../scripts/live/06-build-live-image.sh

echo "Done"
 
# ../scripts/disk/03-setup-disk-rootfs.sh
# ../scripts/disk/04-build-disk-image.sh
