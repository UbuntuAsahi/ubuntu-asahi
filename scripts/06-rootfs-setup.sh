#!/bin/bash
set -e

source $(dirname "$(readlink -f "$0")")/00-config.sh

# Go back to starting dir and clean up mounts on script exit
STARTING_DIR="$PWD"
function on_exit() {
	cd "$STARTING_DIR"
	sync
	sudo umount -Rf mnt
	sudo rm -rf mnt
	sudo losetup --associated pop-os.img | cut -d ':' -f1 | while read LODEV
	do
		sudo losetup --detach "$LODEV"
	done
}
trap on_exit EXIT

# Set up arguments
EXTRA_DPKGS=()
EXTRA_PKGS=()
EXTRAS=()
SHORT="d::,p::,e::"
LONG=dpkg::,pkg::,extra::
OPTS=$(getopt -a -n rootfs-setup --options $SHORT --longoptions $LONG -- "$@")
eval set -- "$OPTS"
while true;
do
	case "$1" in
		-d|--dpkg)
			EXTRA_DPKGS+=("$2")
			shift 2
			;;
		-p|--pkg)
			EXTRA_PKGS+=("$2")
			shift 2
			;;
		-e|--extra)
			EXTRAS+=("$2")
			shift 2
			;;
		--) shift ; break ;;
		*)
			echo "Unexpected option: $1"
			help
			;;
	esac
done

# Get loopback partitions
LODEV="$(sudo losetup --find --show --partscan pop-os.img)"

# Mount rootfs+efi partition
mkdir -p mnt
sudo mount -o rw "${LODEV}p2" mnt 2>&1| capture_and_log "mount rootfs"
sudo mkdir -p mnt/boot/efi
sudo mount -o rw "${LODEV}p1" mnt/boot/efi 2>&1| capture_and_log "mount efi"
sudo mount --rbind --make-rslave /tmp mnt/tmp 2>&1| capture_and_log "mount /tmp"
sudo mount --rbind --make-rslave /dev mnt/dev 2>&1| capture_and_log "mount /dev"
sudo mount --rbind --make-rslave /proc mnt/proc 2>&1| capture_and_log "mount /proc"
sudo mount --rbind --make-rslave /sys mnt/sys 2>&1| capture_and_log "mount /sys"

# Sync extra files, if any, into rootfs
if [ ! ${#EXTRAS[@]} -eq 0 ];
then
	for EXTRA in "${EXTRAS[@]}"; do
		info "Copying '$EXTRA' into rootfs"
		sudo rsync -arv "$EXTRA/" mnt/ 2>&1| capture_and_log "copy extra into rootfs"
	done
fi

# Enter the rootfs
cd mnt

# Run `apt update` in rootfs
sudo bash -c "chroot . apt-get -y update" 2>&1| capture_and_log "apt update"

# Ensure actual Pi packages (and snapd) are never installed
sudo bash -c "chroot . apt-mark hold snapd pop-desktop-raspi linux-raspi rpi-eeprom u-boot-rpi" 2>&1| capture_and_log "hold packages"

# Install any extra packages
if [ ! ${#EXTRA_PKGS[@]} -eq 0 ];
then
	sudo bash -c "chroot . apt-get -y install ${EXTRA_PKGS[@]}" 2>&1| capture_and_log "install extra pkgs"
fi

# Update the packages in rootfs
sudo bash -c "chroot . apt-get -y dist-upgrade --allow-downgrades" 2>&1| capture_and_log "upgrade packages"

# Install pop-desktop
sudo bash -c "chroot . apt-get -y install pop-desktop" 2>&1| capture_and_log "install pop-desktop"

# Install any extra packages
if [ ! ${#EXTRA_DPKGS[@]} -eq 0 ];
then
	for dpkg in ${EXTRA_DPKGS[@]}; do
		cd ..
		sudo cp "$dpkg" mnt/extra.deb
		cd mnt
		sudo bash -c "chroot . dpkg -i extra.deb" 2>&1| capture_and_log "install extra deb"
	done
	sudo rm -f *.deb
fi

# Clean up
sudo bash -c "chroot . apt-get -y autoremove --purge" 2>&1| capture_and_log "apt autoremove"
sudo bash -c "chroot . apt-get -y autoclean" 2>&1| capture_and_log "apt autoclean"
sudo bash -c "chroot . apt-get -y clean" 2>&1| capture_and_log "apt clean"

# Fix up fstab
info "Filling in fstab"
ROOTFS_UUID="$(sudo blkid -s UUID -o value "${LODEV}p2")"
sudo sed -i "s/POP_UUID/${ROOTFS_UUID}/" etc/fstab
EFI_UUID="$(sudo blkid -s UUID -o value "${LODEV}p1")"
sudo sed -i "s/EFI_UUID/${EFI_UUID}/" etc/fstab

# Install systemd-boot
info "Installing systemd-boot"
sudo bash -c "chroot . bootctl install --no-variables --esp-path=/boot/efi" 2>&1| capture_and_log "bootctl install"

# Create systemd-boot entry
info "Creating systemd-boot entry"
cat <<EOF >> ../pop.conf
title   Pop!_OS
linux   /vmlinuz
initrd  /initrd.img
options root=UUID=${ROOTFS_UUID} rw quiet splash
EOF
sudo cp ../pop.conf boot/efi/loader/entries/pop.conf
sudo rm ../pop.conf

info "Copying kernel and initrd to EFI"
ACTUAL_VMLINUZ="boot/$(readlink boot/vmlinuz)"
ACTUAL_INITRD="boot/$(readlink boot/initrd.img)"
sudo cp "$ACTUAL_VMLINUZ" boot/efi/vmlinuz
sudo cp "$ACTUAL_INITRD" boot/efi/initrd.img