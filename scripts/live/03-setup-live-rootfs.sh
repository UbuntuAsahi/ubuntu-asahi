#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/00-config.sh"

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
trap "cd \"${STARTING_DIR}\"" EXIT

info "Copying rootfs.base to rootfs.live"
rm -rf "${ROOTFS_LIVE_DIR}"
cp -a "${ROOTFS_BASE_DIR}" "${ROOTFS_LIVE_DIR}"

cp -f "${SCRIPTS_DIR}/00-config.sh" "${ROOTFS_LIVE_DIR}"
cp -f "${SCRIPTS_DIR}/live/chroot-live.sh" "${ROOTFS_LIVE_DIR}"

info "Spawning chroot via systemd-nspawn"
systemd-nspawn \
	--machine=pop-os \
	--resolv-conf=off \
	--directory="${ROOTFS_LIVE_DIR}" \
	bash /chroot-live.sh