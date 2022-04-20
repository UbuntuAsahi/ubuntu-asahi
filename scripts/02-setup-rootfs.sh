#!/bin/bash
set -e

source $(dirname "$(readlink -f "$0")")/00-config.sh

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
trap "cd \"${STARTING_DIR}\"" EXIT

cp -f "${SCRIPTS_DIR}/00-config.sh" "${ROOTFS_BASE_DIR}"
cp -f "${SCRIPTS_DIR}/chroot-base.sh" "${ROOTFS_BASE_DIR}"

info "Spawning chroot via systemd-nspawn"
systemd-nspawn \
	--machine=pop-os \
	--resolv-conf=off \
	--directory="${ROOTFS_BASE_DIR}" \
	bash /chroot-base.sh