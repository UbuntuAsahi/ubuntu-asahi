#!/bin/bash
set -e

source /00-config.sh
rm -f /00-config.sh

(
export DEBIAN_FRONTEND=noninteractive
apt-get --yes update 2>&1| capture_and_log "apt update"

# XXX: Don't remove grub
sed -i '/^grub/d' livecd.*.manifest-remove

# For flavors we might need to remove some packages
if find livecd.*.manifest-remove -quit; then
	xargs apt-get --yes purge < livecd.*.manifest-remove
fi

if [ ${#LP_DISK_PKGS[@]} -ne 0 ]; then
    apt-get --yes install ${LP_DISK_PKGS[@]} 2>&1| capture_and_log "install disk packages"
fi
)

info "Installing grub"
grub-install --target=arm64-efi --efi-directory=/boot/efi
update-grub

# This is not a cloud
rm -rf /etc/cloud
apt-get --yes purge cloud-init
apt-get --yes autoremove

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
