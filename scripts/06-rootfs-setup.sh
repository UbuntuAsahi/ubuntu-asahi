#!/bin/bash
set -e

SCRIPTS_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPTS_DIR/00-config.sh"

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
EXTRA_DEBS=()
EXTRA_PKGS=()
EXTRAS=()
SHORT="d::,p::,e::"
LONG=deb::,pkg::,extra::
OPTS=$(getopt -a -n rootfs-setup --options $SHORT --longoptions $LONG -- "$@")
eval set -- "$OPTS"
while true;
do
	case "$1" in
		-d|--deb)
			EXTRA_DEBS+=("$2")
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

# Sync extra files, if any, into rootfs
if [ ! ${#EXTRAS[@]} -eq 0 ];
then
	for EXTRA in "${EXTRAS[@]}"; do
		info "Copying '$EXTRA' into rootfs"
		rsync -arv "$EXTRA/" mnt/ 2>&1| capture_and_log "copy extra into rootfs"
	done
fi

for pkg in "${EXTRA_DEBS[@]}"; do
	cp -f "$pkg" mnt
done
join_by "\n" "${EXTRA_PKGS[@]}" > mnt/packages
cp -f "$SCRIPTS_DIR/00-config.sh" mnt
cp -f "$SCRIPTS_DIR/chroot.sh" mnt
blkid -s UUID -o value "${LODEV}p2" > mnt/rootfs.uuid
blkid -s UUID -o value "${LODEV}p1" > mnt/efi.uuid

systemd-nspawn \
	--machine=pop-os \
	--resolv-conf=off \
	--directory=mnt \
	bash /chroot.sh