#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/../00-config.sh"

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
trap "cd \"${STARTING_DIR}\"" EXIT

rm -rf "${ISO_DIR}"
mkdir -p "${ISO_CASPER_DIR}"

info "Calculating filesystem size"
du -sx --block-size=1 "${ROOTFS_LIVE_DIR}" | cut -f1 > "${ISO_FILESYSTEM_SIZE_TAG}"

info "Squashing rootfs"
mksquashfs "${ROOTFS_LIVE_DIR}" "${ISO_ROOTFS_SQUASHED}" -noappend -fstime "$(date +%s)"

info "Creating ISO"

cp -f "${EFI_IMG}" "${ISO_DIR}/efi.img"

xorriso \
	-as mkisofs \
	-J \
	-no-emul-boot \
	-boot-load-size 4 -boot-info-table \
	-eltorito-alt-boot -e "/efi.img" \
	-no-emul-boot -isohybrid-gpt-basdat \
	-r -V "${DISTRO_VOLUME_LABEL}" \
	-o "${ISO_OUT}" "${ISO_DIR}"
