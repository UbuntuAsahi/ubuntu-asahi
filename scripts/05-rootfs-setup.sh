#!/bin/bash
set -e

source $(dirname "$(readlink -f "$0")")/00-config.sh

# Go back to starting dir and clean up mounts on script exit
STARTING_DIR="$PWD"
function on_exit() {
	cd "$STARTING_DIR"
	sudo umount -Rf mnt || true
	sudo rm -rf mnt
}
trap on_exit EXIT

# Set up arguments
EXTRA_DPKGS=()
EXTRA_PKGS=()
EXTRA=""
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
			EXTRA="$2"
			shift 2
			;;
		--) shift ; break ;;
		*)
			echo "Unexpected option: $1"
			help
			;;
	esac
done

# Mount rootfs+efi partition
mkdir mnt || true
sudo mount -o loop,rw rootfs.img mnt 2>&1| capture_and_log "mount rootfs.img"
sudo mkdir -p mnt/boot/efi
sudo mount -o loop,rw efi.img mnt/boot/efi 2>&1| capture_and_log "mount efi.img"
sudo mount --rbind /dev mnt/dev 2>&1| capture_and_log "mount /dev"
sudo mount --rbind /proc mnt/proc 2>&1| capture_and_log "mount /proc"
sudo mount --rbind /sys mnt/sys 2>&1| capture_and_log "mount /sys"

# Sync extra files, if any, into rootfs
if [ ! -z "$EXTRA" ]
then
	info "Copying '$EXTRA' into rootfs"
	sudo rsync -arv "$EXTRA/" mnt/ 2>&1| capture_and_log "copy extra into rootfs"
fi

# Enter the rootfs
cd mnt

# Run `apt update` in rootfs
sudo bash -c "chroot . apt -y update" 2>&1| capture_and_log "apt update"

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

# Ensure actual Pi packages (and snapd) are never installed
sudo bash -c "chroot . apt-mark hold snapd pop-desktop-raspi linux-raspi rpi-eeprom u-boot-rpi" 2>&1| capture_and_log "hold packages"

# Update the packages in rootfs
sudo bash -c "chroot . apt -y full-upgrade --allow-downgrades" 2>&1| capture_and_log "upgrade packages"

# Install pop-desktop
sudo bash -c "chroot . apt -y install pop-desktop" 2>&1| capture_and_log "install pop-desktop"

# Install any extra packages
if [ ! ${#EXTRA_PKGS[@]} -eq 0 ];
then
	sudo bash -c "chroot . apt -y install ${EXTRA_PKGS[@]}" 2>&1| capture_and_log "install extra pkgs"
fi

# Clean up
sudo bash -c "chroot . apt -y autoremove" 2>&1| capture_and_log "apt autoremove"
sudo bash -c "chroot . apt -y clean" 2>&1| capture_and_log "apt clean"

# Get rootfs UUID
ROOTFS_UUID=$(blkid -s UUID -o value ../rootfs.img)
INITRD=$(ls -1 boot/ | grep initrd)
VMLINUZ=$(ls -1 boot/ | grep vmlinuz)

# Install GRUB2
info "Installing GRUB2"
sudo bash -c "chroot . grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=grub --recheck" 2>&1| capture_and_log "install grub"
cat > grub.cfg <<EOF
search.fs_uuid ${ROOTFS_UUID} root
linux (\$root)/boot/${VMLINUZ} root=UUID=${ROOTFS_UUID} rw
initrd (\$root)/boot/${INITRD}
boot
EOF
sudo mkdir -p boot/efi/EFI/ubuntu
sudo cp grub.cfg boot/efi/EFI/ubuntu/grub.cfg