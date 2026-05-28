#!/bin/bash

set -e

if [ "$(id -u)" != "0" ] || [ -z "$SUDO_UID" ]; then
    echo "error: run with sudo"
    exit 1
fi

VARIANT="${1:-}"
if [ "$VARIANT" != "desktop" ] && [ "$VARIANT" != "server" ]; then
    echo "usage: sudo $0 [desktop|server]"
    exit 1
fi

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Build the rootfs tarball
ubuntu-image classic "${SCRIPT_DIR}/asahi-${VARIANT}.yaml"

# Pack into an Asahi zip
ROOTFS_TARBALL="${SCRIPT_DIR}/ubuntu-26.04-preinstalled-${VARIANT}-arm64+asahi.tar.gz"
cd "${SCRIPT_DIR}/build"
ROOTFS_TARBALL="${ROOTFS_TARBALL}" ../scripts/livefs-to-asahi.sh

echo "Done"
