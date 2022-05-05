#!/bin/bash
set -e

source "$(dirname "$(readlink -f "$0")")/../00-config.sh"

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
function cleanup {
	cd "${STARTING_DIR}"
	sync
	umount -Rf "${MNT_DIR}"
	losetup --associated "${LIVE_IMG_FILE}" | cut -d ':' -f1 | while read LODEV
	do
		sudo losetup --detach "$LODEV"
	done
}
trap cleanup EXIT

rm -rf "${MNT_DIR}"
mkdir -p "${MNT_DIR}"

info "Mounting image"
LOOP_DEV=$(losetup --find --show --partscan "${LIVE_IMG_FILE}")
mount "${LOOP_DEV}p1" "${MNT_DIR}"

mkdir -p "${DISTS_DIR}/${UBUNTU_CODE}"
for pool in $(ls -1 "${POOL_DIR}"); do
	info "Generating package index for pool ${pool}"
    mkdir -p "${DISTS_DIR}/${UBUNTU_CODE}/${pool}/binary-arm64"
    apt-ftparchive packages "${POOL_DIR}/${pool}" > "${DISTS_DIR}/${UBUNTU_CODE}/${pool}/binary-arm64/Packages"
    gzip -f -k "${DISTS_DIR}/${UBUNTU_CODE}/${pool}/binary-arm64/Packages"
    sed "s|COMPONENT|${pool}|g; ${SED_PATTERN}" "${FS_POOL_DIR}/Release" > "${DISTS_DIR}/${UBUNTU_CODE}/${pool}/binary-arm64/Release";
done;

info "Generating release file for pools"
apt-ftparchive \
		-o "APT::FTPArchive::Release::Acquire-By-Hash=yes" \
		-o "APT::FTPArchive::Release::Architectures=arm64" \
		-o "APT::FTPArchive::Release::Codename=${UBUNTU_CODE}" \
		-o "APT::FTPArchive::Release::Components=$(ls -1 "${POOL_DIR}" | tr '\n' ' ')" \
		-o "APT::FTPArchive::Release::Description=${DISTRO_NAME} ${DISTRO_VERSION}" \
		-o "APT::FTPArchive::Release::Label=Ubuntu" \
		-o "APT::FTPArchive::Release::Origin=Ubuntu" \
		-o "APT::FTPArchive::Release::Suite=${UBUNTU_CODE}" \
		-o "APT::FTPArchive::Release::Version=${DISTRO_VERSION}" \
		release "${DISTS_DIR}/${UBUNTU_CODE}" \
		> "${DISTS_DIR}/${UBUNTU_CODE}/Release" 

info "Signing Release with gpg key"
if [[ "${RELEASE_SIGN_KEY}" == "5D59E46F74BC1810" ]]; then
	warn "Using the default release signing key. This is not recommended in production!!"
fi
gpg --batch --yes --digest-algo sha512 --sign --detach-sign --armor --local-user "${RELEASE_SIGN_KEY}" --output "${DISTS_DIR}/${UBUNTU_CODE}/Release.gpg" "${DISTS_DIR}/${UBUNTU_CODE}/Release" 2>&1| capture_and_log "gpg signing Release"