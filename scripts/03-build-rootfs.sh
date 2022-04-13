#!/bin/bash
set -xe

source 00-arm64-cross-compile.sh

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
trap "cd \"$STARTING_DIR\"" EXIT

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

# Clean up old directories
sudo rm -rf rootfs

# Bootstrap debian rootfs
mkdir -p cache
sudo update-binfmts --enable
sudo eatmydata qemu-debootstrap \
		--arch=arm64 \
		--cache-dir=`pwd`/cache \
		--include initramfs-tools,apt,grub-efi-arm64 \
		jammy \
		rootfs \
		http://ports.ubuntu.com/ubuntu-ports

# Sync extra files, if any, into rootfs
if [ ! -z "$EXTRA" ]
then
	echo "rsyncing extra files into rootfs!"
	sudo rsync --recursice --verbose "$EXTRA" rootfs
fi

cd rootfs

# Run `apt update` in rootfs
sudo bash -c "chroot . apt update"

# Install any extra packages
if (( ${#EXTRA_DPKGS[@]} ));
then
	sudo cp -t . ${EXTRA_DPKGS[@]}
	sudo chroot . "dpkg -i *.deb"
	sudo rm -f *.deb
fi

# Ensure actual Pi packages (and snapd) are never installed
sudo bash -c "chroot . apt-mark hold snapd pop-desktop-raspi linux-raspi rpi-eeprom u-boot-rpi"

# Upgrade and install Pop!_OS stuff
sudo bash -c "chroot . apt -y dist-upgrade"
sudo bash -c "chroot . apt -y install linux-firmware pop-desktop"

# Install extra packages
if (( ${#EXTRA_PKGS[@]} ));
then
	sudo bash -c "chroot . apt install ${EXTRA_PKGS[@]}"
fi

# Clean up after ourselves
sudo bash -c "chroot . apt -y autoremove"
sudo bash -c "chroot . apt -y clean"

sudo -- perl -p -i -e 's/root:x:/root::/' etc/passwd

# Link systemd to init.
sudo -- ln -s lib/systemd/systemd init