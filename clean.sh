#!/bin/bash
if [[ "${EUID:-$(id -u)}" != 0 ]]; then
	echo "This script must be run as root."
	exit 1
fi

set -xe

rm -rf build/rootfs.base
rm -rf build/rootfs.live
rm -rf build/pop-os.img
rm -rf build/mnt