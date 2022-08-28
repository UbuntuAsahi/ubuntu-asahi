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

# Then, we're going to mark packages that we don't want to install as "held",
# so, well, they don't get installed!
if [ ${#HOLD_PKGS[@]} -ne 0 ]; then
    apt-mark hold ${HOLD_PKGS[@]} 2>&1| capture_and_log "hold packages"
fi

# We're going to install the primary distro packages - ubuntu-desktop and friends - now.
if [ ${#DISTRO_PKGS[@]} -ne 0 ]; then
    eatmydata apt-get --yes install ${DISTRO_PKGS[@]} 2>&1| capture_and_log "install ubuntu-desktop"
fi

# # Install language packs
# if [ ${#LANGUAGES[@]} -ne 0 ]; then
#     pkgs=""
#     for language in ${LANGUAGES[@]}
#     do
#         info "Adding language '${language}'"
#         pkgs+=" $(XDG_CURRENT_DESKTOP=GNOME check-language-support --show-installed --language="${language}")"
#     done
#     if [ -n "$pkgs" ]; then
#         eatmydata apt-get --yes install --no-install-recommends $pkgs 2>&1| capture_and_log "install language packs"
#     fi
# fi

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

# We need to install the systemd-boot EFI bootloader.
info "Installing systemd-boot"
bootctl install --no-variables --esp-path=/boot/efi 2>&1| capture_and_log "bootctl install"

# systemd-boot on arm64 doesn't support compressed kernels,
# so we have to un-gzip vmlinuz, and then copy it back to the ESP.
info "Copying kernel and initrd to EFI"
ACTUAL_VMLINUZ="/boot/$(readlink /boot/vmlinuz)"
ACTUAL_INITRD="/boot/$(readlink /boot/initrd.img)"
cp "$ACTUAL_VMLINUZ" /tmp/vmlinuz.gz
gzip -d /tmp/vmlinuz.gz
cp -f /tmp/vmlinuz /boot/efi/vmlinuz
rm -f /tmp/vmlinuz
cp -f "$ACTUAL_INITRD" /boot/efi/initrd.gz

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
