#!/bin/bash
set -e

# Disclaimer: I have no clue what any of this does.
#  Just copying it from pop-os/iso
#    - Lucy

source "$(dirname "$(readlink -f "$0")")/00-config.sh"

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
trap "cd \"${STARTING_DIR}\"" EXIT

mkdir -p "${GERMINATE_SEEDS_DIR}"

info "Creating distro seeds"
echo "# DISTRO_PKGS" > "${GERMINATE_SEEDS_DIR}/distro"
for package in ${DISTRO_PKGS[@]}; do
	echo " * ${package}" >> "${GERMINATE_SEEDS_DIR}/distro"
done

info "Creating live seeds"
echo "# LIVE_PKGS" > "${GERMINATE_SEEDS_DIR}/live"
for package in ${LIVE_PKGS[@]}; do
	echo " * ${package}" >> "${GERMINATE_SEEDS_DIR}/live"
done

info "Creating main pool seeds"
echo "# MAIN_POOL" > "${GERMINATE_SEEDS_DIR}/pool"
for package in ${MAIN_POOL[@]}; do
	echo " * ${package}" >> "${GERMINATE_SEEDS_DIR}/pool"
done

info "Creating structure file"
echo "distro:" > "${GERMINATE_SEEDS_DIR}/STRUCTURE"
echo "live: distro" >> "${GERMINATE_SEEDS_DIR}/STRUCTURE"
echo "pool: live" >> "${GERMINATE_SEEDS_DIR}/STRUCTURE"

cd "${GERMINATE_DIR}"
germinate \
	-S seeds \
	-s "ubuntu.${UBUNTU_CODE}" \
	-m http://ports.ubuntu.com/ubuntu-ports \
	-m http://apt.pop-os.org/release \
	-d "${UBUNTU_CODE},${UBUNTU_CODE}-updates" \
	-a arm64 \
	-c main,restricted,universe,multiverse \
	--no-rdepends

cd "${GERMINATE_DIR}"
missing=$(cut -d ' ' -f1 pool.depends | tail -n +3 | head -n -2)
if [ "${missing}" != "" ]; then
	error "ERROR: packages missing from pool:"
	error "${missing}"
	exit 1
fi