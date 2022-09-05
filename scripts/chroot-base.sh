#!/bin/bash
set -e

source /00-config.sh
rm -f /00-config.sh

# This is needed to allow us to connect to the internet.
# Without this, we cannot resolve any DNS!
info "Fixing DNS"
rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf

# We gotta make sure our package database is up-to-date
eatmydata apt-get --yes update 2>&1| capture_and_log "apt update"

# Install local debs (like a custom kernel)
NUM_DEBS_TO_INSTALL=$(find /debs -name "*.deb" -type f | wc -l)
if [ ${NUM_DEBS_TO_INSTALL} -gt 0 ]; then
    info "Found ${NUM_DEBS_TO_INSTALL} extra debs to install"
    eatmydata apt-get --yes install /debs/*.deb 2>&1| capture_and_log "install custom debs"
fi
rm -rf /debs

if [ ${#RM_PKGS[@]} -ne 0 ]; then
    apt-get purge ${RM_PKGS[@]} 2>&1| capture_and_log "remove packages"
fi

# Then, we're going to mark packages that we don't want to install as "held",
# so, well, they don't get installed!
if [ ${#HOLD_PKGS[@]} -ne 0 ]; then
    apt-mark hold ${HOLD_PKGS[@]} 2>&1| capture_and_log "hold packages"
fi

# We're going to install the primary distro packages - ubuntu-desktop and friends - now.
if [ ${#DISTRO_PKGS[@]} -ne 0 ]; then
    eatmydata apt-get --yes install ${DISTRO_PKGS[@]} 2>&1| capture_and_log "install ubuntu-desktop"
fi

# Upgrade all packages.
eatmydata apt-get --yes dist-upgrade --allow-downgrades 2>&1| capture_and_log "apt upgrade"

# kernelstub's postinst probably left some crap clogging up the EFI partition,
# let's just clean that up.
info "Cleaning up old boot files"
rm -rf /boot/efi/EFI/Ubuntu

# Clean up any unused dependencies that may now be lying around after the upgrade.
eatmydata apt-get --yes autoremove --purge 2>&1| capture_and_log "apt autoremove"

info "Unmounting apt cache"
umount /var/cache/apt/archives

# Clean up the apt caches, so we don't leave anything behind.
eatmydata apt-get --yes autoclean 2>&1| capture_and_log "apt autoclean"
eatmydata apt-get --yes clean 2>&1| capture_and_log "apt clean"

info "Synchronizing changes to disk"
sync

# Dunno what this does, honestly.
info "Creating missing NetworkManager config"
mkdir -p /etc/NetworkManager/conf.d/
touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf

info "Creating base filesystem manifest"
dpkg-query -W --showformat='${Package}\t${Version}\n' > /manifest

# Clean up any left-behind crap, such as tempfiles and machine-id.
info "Cleaning up data..."
rm -rf /tmp/*
rm -f /var/lib/dbus/machine-id
