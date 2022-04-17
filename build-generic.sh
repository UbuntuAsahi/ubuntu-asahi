#!/bin/bash

# Check to ensure that, if we're in WSL2, we're using systemd,
# as otherwise the rootfs setup will generate an invalid grub
# config due to the lack of /dev/disk.
if [[ -n "$IS_WSL" || -n "$WSL_DISTRO_NAME" ]]; then
	INIT_SYSTEM=$(ps --no-headers -o comm 1)
	if [[ "$INIT_SYSTEM" != "systemd" ]]; then
		echo "WSL detected, but init system is not systemd. Please use subsystemctl to run systemd."
		exit 1
	fi
fi

if [[ "${EUID:-$(id -u)}" != 0 ]]; then
	echo "This script must be run as root."
	exit 1
fi

set -xe

mkdir -p build
cd build
../scripts/02-build-dummy.sh
../scripts/03-build-rootfs.sh
../scripts/04-assemble-partitions.sh
../scripts/05-copy-rootfs.sh
../scripts/06-rootfs-setup.sh --pkg=linux-image-generic --pkg=kernelstub --dpkg=linux-pop-arm64-dummy_5.17.0_all.deb --extra=../fs/common