#!/bin/bash

function cleanup() {
	sync
	sudo umount -Rf mnt
	sudo losetup --detach-all
}
trap cleanup ERR

set -xe
LODEV="$(sudo losetup --find --show --partscan pop-os.img)"

mkdir -p mnt
sudo mount -o rw "${LODEV}p2" mnt
sudo mount -o rw "${LODEV}p1" mnt/boot/efi
sudo mount --rbind --make-rslave /tmp mnt/tmp
sudo mount --rbind --make-rslave /dev mnt/dev
sudo mount --rbind --make-rslave /proc mnt/proc
sudo mount --rbind --make-rslave /sys mnt/sys
