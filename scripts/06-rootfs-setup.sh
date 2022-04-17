#!/bin/bash
set -e

source $(dirname "$(readlink -f "$0")")/00-config.sh

# Go back to starting dir and clean up mounts on script exit
STARTING_DIR="$PWD"
function on_exit() {
	cd "$STARTING_DIR"
	sync
	umount -Rf mnt
	rm -rf mnt
	losetup --associated pop-os.img | cut -d ':' -f1 | while read LODEV
	do
		losetup --detach "$LODEV"
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
LODEV="$(losetup --find --show --partscan pop-os.img)"

# Mount rootfs+efi partition
mkdir -p mnt
mount -o rw "${LODEV}p2" mnt 2>&1| capture_and_log "mount rootfs"
mkdir -p mnt/boot/efi
mount -o rw "${LODEV}p1" mnt/boot/efi 2>&1| capture_and_log "mount efi"
mount --rbind --make-rslave /tmp mnt/tmp 2>&1| capture_and_log "mount /tmp"
mount --rbind --make-rslave /dev mnt/dev 2>&1| capture_and_log "mount /dev"
mount --rbind --make-rslave /proc mnt/proc 2>&1| capture_and_log "mount /proc"
mount --rbind --make-rslave /sys mnt/sys 2>&1| capture_and_log "mount /sys"

# Sync extra files, if any, into rootfs
if [ ! ${#EXTRAS[@]} -eq 0 ];
then
	for EXTRA in "${EXTRAS[@]}"; do
		info "Copying '$EXTRA' into rootfs"
		rsync -arv "$EXTRA/" mnt/ 2>&1| capture_and_log "copy extra into rootfs"
	done
fi

# Enter the rootfs
cd mnt

# Fix up fstab
info "Filling in fstab"
ROOTFS_UUID="$(blkid -s UUID -o value "${LODEV}p2")"
sed -i "s/POP_UUID/${ROOTFS_UUID}/" etc/fstab
EFI_UUID="$(blkid -s UUID -o value "${LODEV}p1")"
sed -i "s/EFI_UUID/${EFI_UUID}/" etc/fstab

# Run `apt update` in rootfs
bash -c "chroot . apt-get -y update" 2>&1| capture_and_log "apt update"

# Ensure actual Pi packages (and snapd) are never installed
bash -c "chroot . apt-mark hold snapd pop-desktop-raspi linux-raspi rpi-eeprom u-boot-rpi" 2>&1| capture_and_log "hold packages"

# Install any extra packages
if [ ! ${#EXTRA_PKGS[@]} -eq 0 ];
then
	for pkg in ${EXTRA_PKGS[@]}; do
		bash -c "chroot . apt-get -y install $pkg" 2>&1| capture_and_log "install $pkg"
	done
fi

# Install any extra debs
if [ ! ${#EXTRA_DPKGS[@]} -eq 0 ];
then
	for deb in ${EXTRA_DPKGS[@]}; do
		cd ..
		cp "$deb" mnt/extra.deb
		cd mnt
		bash -c "chroot . dpkg -i extra.deb" 2>&1| capture_and_log "install extra deb"
	done
	rm -f *.deb
fi

# Fix annoying bug
mkdir -p usr/share/icons/Pop

# Update the packages in rootfs
bash -c "chroot . apt-get -y dist-upgrade --allow-downgrades" 2>&1| capture_and_log "upgrade packages"

# Install pop-desktop
bash -c "chroot . apt-get -y install pop-desktop" 2>&1| capture_and_log "install pop-desktop"

# Clean up
bash -c "chroot . apt-get -y autoremove --purge" 2>&1| capture_and_log "apt autoremove"
bash -c "chroot . apt-get -y autoclean" 2>&1| capture_and_log "apt autoclean"
bash -c "chroot . apt-get -y clean" 2>&1| capture_and_log "apt clean"

# Install systemd-boot
info "Installing systemd-boot"
bash -c "chroot . bootctl install --no-variables --esp-path=/boot/efi" 2>&1| capture_and_log "bootctl install"

# Create systemd-boot entry
info "Creating systemd-boot entry"
cat <<EOF >> ../pop.conf
title   Pop!_OS
linux   /vmlinuz
initrd  /initrd.img
options root=UUID=${ROOTFS_UUID} rw quiet splash
EOF
cp ../pop.conf boot/efi/loader/entries/Pop_OS-current.conf
rm ../pop.conf

info "Copying kernel and initrd to EFI"
ACTUAL_VMLINUZ="boot/$(readlink boot/vmlinuz)"
ACTUAL_INITRD="boot/$(readlink boot/initrd.img)"
cp "$ACTUAL_VMLINUZ" boot/efi/vmlinuz.gz
gzip -d boot/efi/vmlinuz.gz
cp "$ACTUAL_INITRD" boot/efi/initrd.img

# Enable first-boot service
info "Enabling first-boot service"
bash -c "chroot . systemctl enable first-boot" 2>&1| capture_and_log "systemctl enable first-boot"