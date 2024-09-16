#!/bin/bash

set -e

function log {
	echo "[$(tput setaf 2)$(tput bold)info$(tput sgr0)] $@"
}

export DEBIAN_FRONTEND=noninteractive

# Drop extra PPA, this is managed by our meta package
rm /etc/apt/sources.list.d/extra-ppas.list

# For flavors we might need to remove some packages
# XXX: Don't remove grub
sed -i '/^grub/d' livecd.*.manifest-remove || true
if find livecd.*.manifest-remove -quit; then
	xargs apt-get --yes purge < livecd.*.manifest-remove
fi

log "Installing grub"
grub-install --target=arm64-efi --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg

# Clean up any left-behind crap, such as tempfiles and machine-id.
log "Cleaning up data..."
rm -rf /tmp/*
rm -f /var/lib/dbus/machine-id
