#!/bin/bash
set -e

source /00-config.sh
rm -f /00-config.sh

info "Fixing DNS"
rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf

apt-get --yes update 2>&1| capture_and_log "apt update"
if [ ${#LIVE_PKGS[@]} -ne 0 ]; then
    eatmydata apt-get --yes install ${DISK_PKGS[@]} 2>&1| capture_and_log "install live utilities"
fi

info "Synchronizing changes to disk"
sync

info "Installing grub"
# From asahi-alarm-builder
cat > /tmp/grub-core.cfg <<EOF
search.fs_uuid ${DISK_ROOT_UUID} root
set prefix=(\$root)'/boot/grub'
EOF
mkdir -p /boot/grub
touch /boot/grub/device.map
dd if=/dev/zero of=/boot/grub/grubenv bs=1024 count=1
cp -r /usr/share/grub/themes /boot/grub
cp -r /usr/lib/grub/arm64-efi /boot/grub/
rm -f /boot/grub/arm64-efi/*.module
mkdir -p /boot/grub/{fonts,locale}
cp /usr/share/grub/unicode.pf2 /boot/grub/fonts
for i in /usr/share/locale/*/LC_MESSAGES/grub.mo; do
    lc="$(echo "$i" | cut -d/ -f5)"
    cp "$i" /boot/grub/locale/"$lc".mo
done

info "Generating grub image"
grub-mkimage \
    --directory '/usr/lib/grub/arm64-efi' \
    -c /tmp/grub-core.cfg \
    --prefix "/boot/grub" \
    --output /boot/grub/arm64-efi/core.efi \
    --format arm64-efi \
    --compression auto \
    "ext2 part_gpt search"
rm -rf /etc/grub.d/30_uefi-firmware

mkdir -p "/esp/EFI/BOOT"
grub-mkconfig -o /boot/grub/grub.cfg
cp "/boot/grub/arm64-efi/core.efi" "/esp/EFI/BOOT/BOOTAA64.EFI"

info "Installing bootloader"
# XXX install m1n1
cp -r "/boot/efi/m1n1" "/esp/"

# Clean up any left-behind crap, such as tempfiles and machine-id.
info "Cleaning up data..."
rm -rf /tmp/*
rm -f /var/lib/dbus/machine-id
