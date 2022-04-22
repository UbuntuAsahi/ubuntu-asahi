#!/bin/bash
set -e

source /00-config.sh
rm -f /00-config.sh

# This is needed to allow us to connect to the internet.
# Without this, we cannot resolve any DNS!
# We can't do this beforehand, as the /run directory is
# a mount, rather than a normal folder
if [ ! -f /run/systemd/resolve/stub-resolv.conf ]
then
	info "Fixing DNS"
    mkdir -p /run/systemd/resolve
    echo "nameserver 1.1.1.1" > /run/systemd/resolve/stub-resolv.conf
fi

#info "Filling in /etc/fstab"
#ROOTFS_UUID=$(cat /rootfs.uuid)
#EFI_UUID=$(cat /efi.uuid)
#sed -i "s/POP_UUID/${ROOTFS_UUID}/" /etc/fstab
#sed -i "s/EFI_UUID/${EFI_UUID}/" /etc/fstab
#rm -f /rootfs.uuid /efi.uuid

# We gotta make sure our package database is up-to-date
apt-get --yes update 2>&1| capture_and_log "apt update"

# Then, we're going to mark packages that we don't want to install as "held",
# so, well, they don't get installed!
if [ ${#HOLD_PKGS[@]} -ne 0 ]; then
    apt-mark hold ${HOLD_PKGS[@]} 2>&1| capture_and_log "hold packages"
fi

# We're going to install the primary distro packages - pop-desktop and friends - now.
apt-get --yes install ${DISTRO_PKGS[@]} 2>&1| capture_and_log "install pop-desktop"

# Upgrade all packages.
apt-get --yes dist-upgrade --allow-downgrades 2>&1| capture_and_log "apt upgrade"

# kernelstub's postinst probably left some crap clogging up the EFI partition,
# let's just clean that up.
info "Cleaning up old boot files"
rm -rf /boot/efi/EFI/{Pop_OS,Ubuntu}-

# Clean up any unused dependencies that may now be lying around after the upgrade.
apt-get --yes autoremove --purge 2>&1| capture_and_log "apt autoremove"

# Clean up the apt caches, so we don't leave anything behind.
apt-get --yes autoclean 2>&1| capture_and_log "apt autoclean"
apt-get --yes clean 2>&1| capture_and_log "apt clean"

# We need to install the systemd-boot EFI bootloader.
info "Installing systemd-boot"
bootctl install --no-variables --esp-path=/boot/efi 2>&1| capture_and_log "bootctl install"

# Now, we'll create a systemd-boot entry for our kernel.
info "Creating systemd-boot entry"
cat <<EOF >> /boot/efi/loader/entries/Pop_OS-current.conf
title   Pop!_OS
linux   /vmlinuz
initrd  /initrd.img
options root=UUID=${ROOTFS_UUID} rw quiet splash
EOF

# systemd-boot on arm64 doesn't support compressed kernels,
# so we have to un-gzip vmlinuz, and then copy it back to the ESP.
info "Copying kernel and initrd to EFI"
ACTUAL_VMLINUZ="/boot/$(readlink /boot/vmlinuz)"
ACTUAL_INITRD="/boot/$(readlink /boot/initrd.img)"
cp "$ACTUAL_VMLINUZ" /tmp/vmlinuz.gz
gzip -d /tmp/vmlinuz.gz
sudo cp -f /tmp/vmlinuz /boot/efi/vmlinuz
sudo rm -f /tmp/vmlinuz
cp "$ACTUAL_INITRD" /boot/efi/initrd.img

# This is just stuff we run on the first-boot.
info "Enabling first-boot service"
systemctl enable first-boot 2>&1| capture_and_log "systemctl enable first-boot"

# Dunno what this does, honestly.
info "Creating missing NetworkManager config"
touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf

# Self-explanatory.
info "Updating AppStream cache"
/usr/bin/appstreamcli refresh-cache --force 2>&1 | capture_and_log "update appstream cache"

# Clean up any left-behind crap, such as tempfiles and machine-id.
touch "Cleaning up data..."
rm -rf /tmp/*
rm -f /var/lib/dbus/machine-id