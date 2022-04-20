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

apt-get --yes update 2>&1| capture_and_log "apt update"
apt-get --yes install casper distinst \
	expect gparted pop-installer pop-installer-casper \
	pop-shop-casper 2>&1 capture_and_log "install live utilities"