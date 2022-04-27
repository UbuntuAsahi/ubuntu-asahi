#!/bin/bash
set -e

DISTRO_NAME=pop-os
DISTRO_VERSION=22.04
UBUNTU_CODE=jammy
DISTRO_VOLUME_LABEL="Pop!_OS ${DISTRO_VERSION} arm64"
GNOME_INITIAL_SETUP_STAMP=21.04

DISTRO_PKGS=(ubuntu-minimal ubuntu-standard pop-desktop)
#LIVE_PKGS=(casper distinst expect gparted pop-installer pop-installer-casper)
LIVE_PKGS=(casper expect gparted lldb-13)
HOLD_PKGS=(snapd pop-desktop-raspi linux-raspi rpi-eeprom u-boot-rpi)
RM_PKGS=(bus-mozc imagemagick-6.q16 irqbalance mozc-utils-gui pop-installer-session snapd ubuntu-session ubuntu-wallpapers unattended-upgrades xul-ext-ubufox yaru-theme-gnome-shell)
MAIN_POOL=(at dfu-programmer efibootmgr ethtool kernelstub libfl2 lm-sensors pm-utils postfix powermgmt-base python3-debian python3-distro python3-evdev python3-systemd system76-wallpapers xbacklight)
LANGUAGES=(ar de en es fr it ja pt ru zh zh-hans zh-hant)

SCRIPTS_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )" # Credit: https://stackoverflow.com/a/246128
BUILD_DIR="$(realpath "${SCRIPTS_DIR}/../build")"
CACHE_DIR="${BUILD_DIR}/cache"

FS_DIR="$(realpath "${SCRIPTS_DIR}/../fs")"
FS_COMMON_DIR="${FS_DIR}/common"
FS_LIVE_EFI_DIR="${FS_DIR}/live-efi"
FS_POOL_DIR="${FS_DIR}/pool"

ROOTFS_BASE_DIR="${BUILD_DIR}/rootfs.base"
ROOTFS_LIVE_DIR="${BUILD_DIR}/rootfs.live"

CHROOT_MANIFEST="${BUILD_DIR}/chroot.manifest"
LIVE_MANIFEST="${BUILD_DIR}/live.manifest"

IMG_FILE="${BUILD_DIR}/pop-os.img"

CASPER_NAME="casper_${DISTRO_NAME}_${DISTRO_VERSION}"
MNT_DIR="${BUILD_DIR}/mnt"
CASPER_DIR="${MNT_DIR}/${CASPER_NAME}"
FILESYSTEM_SIZE_TAG="${CASPER_DIR}/filesystem.size"
ROOTFS_SQUASHED="${CASPER_DIR}/filesystem.squashfs"
POOL_DIR="${MNT_DIR}/pool"
MAIN_POOL_DIR="${POOL_DIR}/main"
DISTS_DIR="${MNT_DIR}/dists"

SED_PATTERN="s|CASPER_PATH|${CASPER_NAME}|g; s|DISTRO_NAME|${DISTRO_NAME}|g; s|UBUNTU_CODE|${UBUNTU_CODE}|g; s|DISTRO_VERSION|${DISTRO_VERSION}|g"

_RED=$(tput setaf 1 || "")
_GREEN=$(tput setaf 2 || "")
_YELLOW=$(tput setaf 3 || "")
_RESET=$(tput sgr0 || "")
_BOLD=$(tput bold || "")
_DIM=$(tput dim || "")

function bold {
	echo "${_BOLD}$@${_RESET}"
}

function info {
	echo "[${_GREEN}${_BOLD}info${_RESET}] $@"
}

function error {
	echo "[${_RED}${_BOLD}error${_RESET}] $@"
}

function warn {
	echo "[${_YELLOW}${_BOLD}warning${_RESET}] $@"
}

function capture_and_log {
	PREFIX="[${_GREEN}${_BOLD}$1${_RESET}] ${_DIM}"
	SUFFIX="${_RESET}"
	while read IN
	do
		echo "${PREFIX}${IN}${SUFFIX}"
	done
}

if [[ "${EUID:-$(id -u)}" != 0 ]]; then
	error "This script must be run as root."
	exit 1
fi

# Source: https://stackoverflow.com/a/17841619
function join_by { local IFS="$1"; shift; echo "$*"; }

if [[ "$(uname -p)" -ne "aarch64" ]]; then
	update-binfmts --enable
fi