#!/bin/bash
set -e

source /00-config.sh
rm -f /00-config.sh

info "Fixing DNS"
rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf

apt-get --yes update 2>&1| capture_and_log "apt update"
if [ ${#LIVE_PKGS[@]} -ne 0 ]; then
    apt-get --yes install ${LIVE_PKGS[@]} 2>&1| capture_and_log "install live utilities"
fi

info "Setting up pool"
mkdir -p /iso/pool/main
if [ ${#MAIN_POOL[@]} -ne 0 ]; then
    pushd "/iso/pool/main"
        apt-get --yes download ${MAIN_POOL[@]} 2>&1| capture_and_log "download main pool"
    popd
fi

info "Copying new initrd to /iso"
ACTUAL_INITRD="/boot/$(readlink /boot/initrd.img)"
cp -f "$ACTUAL_INITRD" /iso/initrd.img

# Clean up any left-behind crap, such as tempfiles and machine-id.
info "Cleaning up data..."
rm -rf /tmp/*
rm -f /var/lib/dbus/machine-id