#!/bin/bash
set -e

source /00-config.sh
rm -f /00-config.sh

echo "nameserver 8.8.8.8" > /etc/resolv.conf

(
export DEBIAN_FRONTEND=noninteractive
apt-get --yes update 2>&1| capture_and_log "apt update"

# For flavors we might need to remove some packages
if find livecd.*.manifest-remove -quit; then
	xargs apt-get --yes purge < livecd.*.manifest-remove
fi

if [ ${#LP_DISK_PKGS[@]} -ne 0 ]; then
    apt-get --yes install ${LP_DISK_PKGS[@]} 2>&1| capture_and_log "install disk packages"
fi
)

info "Synchronizing changes to disk"
sync

info "Installing grub"
# From asahi-alarm-builder
cat > /tmp/grub-core.cfg <<EOF
search.fs_uuid ${ROOT_UUID} root
set prefix=(\$root)'/boot/grub'
EOF

mkdir -p /boot/grub
touch /boot/grub/device.map
# dd if=/dev/zero of=/boot/grub/grubenv bs=1024 count=1
cp -r /usr/lib/grub/arm64-efi /boot/grub/
rm -f /boot/grub/arm64-efi/*.module
mkdir -p /boot/grub/{fonts,locale}
cp /usr/share/grub/unicode.pf2 /boot/grub/fonts
echo "GRUB_DISABLE_OS_PROBER=true" >> "/etc/default/grub"

info "Generating grub image"
grub-mkimage \
    --directory '/usr/lib/grub/arm64-efi' \
    -c /tmp/grub-core.cfg \
    --prefix "/boot/grub" \
    --output /boot/grub/arm64-efi/core.efi \
    --format arm64-efi \
    --compression auto \
    ext2 part_gpt search
rm -rf /etc/grub.d/30_uefi-firmware

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
rm /etc/resolv.conf
ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
