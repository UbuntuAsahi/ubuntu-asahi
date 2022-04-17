#!/bin/bash

function cleanup() {
	sync
	umount -Rf mnt
	losetup --detach-all
}
trap cleanup ERR

set -xe
LODEV="$(losetup --find --show --partscan pop-os.img)"

mkdir -p mnt
mount -o rw "${LODEV}p2" mnt
mount -o rw "${LODEV}p1" mnt/boot/efi
mount --rbind --make-rslave /tmp mnt/tmp
mount --rbind --make-rslave /dev mnt/dev
mount --rbind --make-rslave /proc mnt/proc
mount --rbind --make-rslave /sys mnt/sys
