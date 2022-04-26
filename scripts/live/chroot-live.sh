#!/bin/bash
set -e

source /00-config.sh
rm -f /00-config.sh

if [ ! -f /run/systemd/resolve/stub-resolv.conf ]
then
	info "Fixing DNS"
    mkdir -p /run/systemd/resolve
    echo "nameserver 1.1.1.1" > /run/systemd/resolve/stub-resolv.conf
fi

rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf

apt-get --yes update 2>&1| capture_and_log "apt update"
if [ ${#LIVE_PKGS[@]} -ne 0 ]; then
    apt-get --yes install ${LIVE_PKGS[@]} 2>&1| capture_and_log "install live utilities"
fi

info "Copying new initrd to /boot/efi"
ACTUAL_INITRD="/boot/$(readlink /boot/initrd.img)"
cp -f "$ACTUAL_INITRD" /boot/efi/initrd.img

# Clean up any left-behind crap, such as tempfiles and machine-id.
info "Cleaning up data..."
rm -rf /tmp/*
rm -f /var/lib/dbus/machine-id