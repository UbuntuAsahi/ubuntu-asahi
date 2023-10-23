#!/bin/bash

set -e

_GREEN=$(tput setaf 2 || "")
_RESET=$(tput sgr0 || "")
_BOLD=$(tput bold || "")

function log {
	echo "[${_GREEN}${_BOLD}info${_RESET}] $@"
}

export DEBIAN_FRONTEND=noninteractive

# For flavors we might need to remove some packages
# XXX: Don't remove grub
sed -i '/^grub/d' livecd.*.manifest-remove
if find livecd.*.manifest-remove -quit; then
	xargs apt-get --yes purge < livecd.*.manifest-remove
fi

log "Installing grub"
mkdir -p /boot/efi/esp
grub-install --target=arm64-efi --efi-directory=/boot/efi/esp
grub-mkconfig -o /boot/grub/grub.cfg

log "Adding user ubuntu"
useradd ubuntu -s /bin/bash -m -G adm,dialout,cdrom,sudo,dip,plugdev
chpasswd << 'END'
ubuntu:ubuntu
END
usermod -L root

# Clean up any left-behind crap, such as tempfiles and machine-id.
log "Cleaning up data..."
rm -rf /tmp/*
rm -f /var/lib/dbus/machine-id
