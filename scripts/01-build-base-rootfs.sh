#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/00-config.sh"
source "${SCRIPTS_DIR}/00-arm64-cross-compile.sh"

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
trap "cd \"${STARTING_DIR}\"" EXIT

# Clean up old directories
rm -rf "${ROOTFS_BASE_DIR}"

# Bootstrap debian rootfs
info "Bootstrapping Pop!_OS with $DEBOOTSTRAP"
mkdir -p cache
eatmydata $DEBOOTSTRAP \
		--arch=arm64 \
		--cache-dir="${CACHE_DIR}" \
		--include apt,initramfs-tools,linux-image-generic \
		jammy \
		"${ROOTFS_BASE_DIR}" \
		http://ports.ubuntu.com/ubuntu-ports 2>&1| capture_and_log "bootstrap pop"

perl -p -i -e 's/root:x:/root::/' "${ROOTFS_BASE_DIR}/etc/passwd"

info "Linking systemd to init"
ln -s lib/systemd/systemd "${ROOTFS_BASE_DIR}/init"