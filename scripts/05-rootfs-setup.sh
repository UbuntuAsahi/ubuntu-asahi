#!/bin/bash
set -xe

source $(dirname "$(readlink -f "$0")")/00-config.sh

# Go back to starting dir and clean up mounts on script exit
STARTING_DIR="$PWD"
function on_exit() {
	sudo umount -r mnt || true
	sudo rm -rf mnt
	cd "$STARTING_DIR"
}
trap on_exit EXIT

# Set up arguments
EXTRA_DPKGS=()
EXTRA_PKGS=()
EXTRA=""
SHORT="d::,p::,e::"
LONG=dpkg::,pkg::,extra::
OPTS=$(getopt -a -n weather --options $SHORT --longoptions $LONG -- "$@")
eval set -- "$OPTS"
while :
do
	case "$1" in
		-d | --dpkg )
			EXTRA_DPKGS+=("$2")
			shift 2
			;;
		-p | --pkg )
			EXTRA_PKGS+=("$2")
			shift 2
			;;
		-e | --extra )
			EXTRA="$2"
			shift 2
			;;
		-h | --help)
			help
			;;
		*)
			echo "Unexpected option: $1"
			help
			;;
	esac
done

# Mount rootfs+efi partition
sudo mount -o loop rootfs.img mnt
sudo mkdir -p mnt/boot/efi
sudo mount -o loop efi.img mnt/boot/efi

# Sync extra files, if any, into rootfs
if [ ! -z "$EXTRA" ]
then
	echo "rsyncing extra files into rootfs"
	sudo rsync --recursive --verbose "$EXTRA/" mnt/
fi

# Enter the rootfs
cd mnt

# Run `apt update` in rootfs
sudo bash -c "chroot . apt -y update"

# Install any extra packages
if (( ${#EXTRA_DPKGS[@]} ));
then
	sudo cp -t . ${EXTRA_DPKGS[@]}
	sudo chroot . "dpkg -i *.deb"
	sudo rm -f *.deb
fi

# Ensure actual Pi packages (and snapd) are never installed
sudo bash -c "chroot . apt-mark hold snapd pop-desktop-raspi linux-raspi rpi-eeprom u-boot-rpi"

# Update the packages in rootfs
sudo bash -c "chroot . apt -y full-upgrade"

# Install pop-desktop
sudo bash -c "chroot . apt -y install pop-desktop"

# Install any extra packages
if (( ${#EXTRA_PKGS[@]} ));
then
	sudo bash -c "chroot . apt -y install ${EXTRA_PKGS[@]}"
fi

# Clean up
sudo bash -c "chroot . apt -y autoremove"
sudo bash -c "chroot . apt -y clean"

# Get rootfs UUID
ROOTFS_UUID=$(blkid -s UUID -o value rootfs.img)
INITRD=$(ls -1 boot/ | grep initrd)
VMLINUZ=$(ls -1 boot/ | grep vmlinuz)

# Install GRUB2
sudo bash -c "chroot . grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=grub --recheck"
cat > grub.cfg <<EOF
search.fs_uuid ${ROOTFS_UUID} root
linux (\$root)/boot/${VMLINUZ} root=UUID=${ROOTFS_UUID} rw
initrd (\$root)/boot/${INITRD}
boot
EOF
sudo mkdir -p boot/efi/EFI/ubuntu
sudo cp grub.cfg boot/efi/EFI/ubuntu/grub.cfg