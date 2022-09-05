#!/bin/bash
set -e

source /00-config.sh
rm -f /00-config.sh

info "Fixing DNS"
rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf

apt-get --yes update 2>&1| capture_and_log "apt update"
if [ ${#LIVE_PKGS[@]} -ne 0 ]; then
    eatmydata apt-get --yes install ${LIVE_PKGS[@]} 2>&1| capture_and_log "install live utilities"
fi

NUM_DEBS_TO_INSTALL=$(find /debs -name "*.deb" -type f | wc -l)
if [ ${NUM_DEBS_TO_INSTALL} -gt 0 ]; then
    info "Found ${NUM_DEBS_TO_INSTALL} extra debs to install"
    eatmydata apt-get --yes install /debs/*.deb 2>&1| capture_and_log "install custom debs"
fi
rm -rf /debs

info "Setting up pool"
mkdir -p /boot/efi/pool/main
if [ ${#MAIN_POOL[@]} -ne 0 ]; then
    pushd "/boot/efi/pool/main"
       apt-get --yes download ${MAIN_POOL[@]} 2>&1| capture_and_log "download main pool"
    popd
fi

info "Synchronizing changes to disk"
sync

info "Setting up casper scripts"
rm -f /usr/share/initramfs-tools/scripts/casper-bottom/01integrity_check
sed -i \
		"s|touch /root/home/\$USERNAME/.config/gnome-initial-setup-done|echo -n \"${GNOME_INITIAL_SETUP_STAMP}\" > /root/home/\$USERNAME/.config/gnome-initial-setup-done|" \
		/usr/share/initramfs-tools/scripts/casper-bottom/52gnome_initial_setup

update-initramfs -c -k all 2>&1| capture_and_log "updating initramfs"

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

info "Copying new initrd to /boot/efi/${CASPER_NAME}"
ACTUAL_INITRD="/boot/$(readlink /boot/initrd.img)"
rm -f "/boot/efi/initrd.gz"
mkdir -p "/boot/efi/${CASPER_NAME}"
cp -f "$ACTUAL_INITRD" "/boot/efi/${CASPER_NAME}/initrd.gz"

info "Moving vmlinuz to /boot/efi/${CASPER_NAME}"
mv -f "/boot/efi/vmlinuz" "/boot/efi/${CASPER_NAME}/vmlinuz.efi"

info "Creating live filesystem manifest"
dpkg-query -W --showformat='${Package}\t${Version}\n' > /manifest

# Clean up any left-behind crap, such as tempfiles and machine-id.
info "Cleaning up data..."
rm -rf /tmp/*
rm -f /var/lib/dbus/machine-id
