#!/bin/bash
set -e

export LC=C.UTF-8

# If the below line errors; then run `sudo git config --global --add safe.directory '*'`.
# If you feel unsafe doing that, you can just replace `*` with the full path to this repository.
# Git doesn't like it when you run git commands in the dir of another user, but this should be safe as it's just a read-only command.
SOURCE_DATE_EPOCH="$(git --git-dir="$PWD/../.git" log -1 --format='%ct' 2> /dev/null || echo "42")"
DISTRO_NAME=ubuntu
DISTRO_VERSION=22.04
DISTRO_VOLUME_LABEL="Ubuntu ${DISTRO_VERSION} arm64"
DISTRO_EPOCH="${SOURCE_DATE_EPOCH}"
DISTRO_DATE="$(date --date=@"${SOURCE_DATE_EPOCH}" +%Y%m%d)"
UBUNTU_CODE=kinetic
UBUNTU_NAME="Kinetic Kudu"
GNOME_INITIAL_SETUP_STAMP=21.04

DISTRO_PKGS=(ubuntu-minimal ubuntu-standard ubuntu-desktop)
LIVE_PKGS=(casper gparted firefox ubiquity ubiquity-casper)
HOLD_PKGS=()
RM_PKGS=(bus-mozc imagemagick-6.q16 irqbalance mozc-utils-gui unattended-upgrades)
MAIN_POOL=(at dfu-programmer efibootmgr ethtool libfl2 lm-sensors pm-utils postfix powermgmt-base python3-debian python3-distro python3-evdev python3-systemd xbacklight linux-firmware)
# LANGUAGES=(ar de en es fr it ja pt ru zh zh-hans zh-hant)

SCRIPTS_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )" # Credit: https://stackoverflow.com/a/246128
BUILD_DIR="$(realpath "${SCRIPTS_DIR}/../build")"
CACHE_DIR="${BUILD_DIR}/cache"

FS_DIR="$(realpath "${SCRIPTS_DIR}/../fs")"
FS_COMMON_DIR="${FS_DIR}/common"
FS_LIVE_EFI_DIR="${FS_DIR}/live-efi"
FS_LIVE_DIR="${FS_DIR}/live"
FS_POOL_DIR="${FS_DIR}/pool"
FS_LIVE_DEBS_DIR="${FS_DIR}/live-debs"

ROOTFS_BASE_DIR="${BUILD_DIR}/rootfs.base"
ROOTFS_LIVE_DIR="${BUILD_DIR}/rootfs.live"

CHROOT_MANIFEST="${BUILD_DIR}/chroot.manifest"
LIVE_MANIFEST="${BUILD_DIR}/live.manifest"

BASE_IMG_FILE="${BUILD_DIR}/ubuntu.base.img"
LIVE_IMG_FILE="${BUILD_DIR}/ubuntu.live.img"

CASPER_NAME="casper"
MNT_DIR="${BUILD_DIR}/mnt"
DOT_DISK_INFO="${MNT_DIR}/.disk/info"
CASPER_DIR="${MNT_DIR}/${CASPER_NAME}"
FILESYSTEM_SIZE_TAG="${CASPER_DIR}/filesystem.size"
ROOTFS_SQUASHED="${CASPER_DIR}/filesystem.squashfs"
POOL_DIR="${MNT_DIR}/pool"
MAIN_POOL_DIR="${POOL_DIR}/main"
DISTS_DIR="${MNT_DIR}/dists"

SED_PATTERN="s|CASPER_PATH|${CASPER_NAME}|g; s|DISTRO_NAME|${DISTRO_NAME}|g; s|UBUNTU_CODE|${UBUNTU_CODE}|g; s|DISTRO_VERSION|${DISTRO_VERSION}|g; s|UBUNTU_NAME|${UBUNTU_NAME}|g; s|DISTRO_EPOCH|${DISTRO_EPOCH}|g; s|DISTRO_DATE|${DISTRO_DATE}|g"

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

# if [[ "${EUID:-$(id -u)}" != 0 ]]; then
# 	error "This script must be run as root."
# 	exit 1
# fi

# Source: https://stackoverflow.com/a/17841619
function join_by { local IFS="$1"; shift; echo "$*"; }

if [[ "$(uname -p)" -ne "aarch64" ]]; then
	update-binfmts --enable
fi
