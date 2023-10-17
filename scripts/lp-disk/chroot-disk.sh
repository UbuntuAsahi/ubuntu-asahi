#!/bin/bash
set -e

# For info
source /00-config.sh
rm -f /00-config.sh

export DEBIAN_FRONTEND=noninteractive

# For flavors we might need to remove some packages
# XXX: Don't remove grub
sed -i '/^grub/d' livecd.*.manifest-remove
if find livecd.*.manifest-remove -quit; then
	xargs apt-get --yes purge < livecd.*.manifest-remove
fi

info "Installing grub"
mkdir -p /boot/efi/esp
grub-install --target=arm64-efi --efi-directory=/boot/efi/esp
grub-mkconfig -o /boot/grub/grub.cfg

info "Adding user ubuntu"
useradd ubuntu -s /bin/bash -m -G adm,dialout,cdrom,sudo,dip,plugdev
chpasswd << 'END'
ubuntu:ubuntu
END
usermod -L root

# Clean up any left-behind crap, such as tempfiles and machine-id.
info "Cleaning up data..."
rm -rf /tmp/*
rm -f /var/lib/dbus/machine-id
