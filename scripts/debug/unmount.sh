#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/../00-config.sh"

info "Unmounting ${MNT_DIR}"
umount -Rf "${MNT_DIR}" || true

losetup --associated "${IMG_FILE}" | cut -d ':' -f1 | while read LODEV
do
	info "Detaching ${LODEV}"
	losetup --detach "${LODEV}"
done