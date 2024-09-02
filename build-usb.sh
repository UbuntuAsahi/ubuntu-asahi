#!/bin/bash

set -e

if [ "$(id -u)" != "0" ] || [ -z "$SUDO_UID" ]; then
       echo "error: run with sudo"
       exit 1
fi

if [ -z "$1" ]; then
	echo "error: expecting build ID"
	exit 1
fi

# Fetch artifacts
if [ ! -d "build/build-$1" ]; then
	sudo -u "#$SUDO_UID" ./scripts/get-livefs-build.py "$1" "build/build-$1"
fi

# Pack image
cd build
ARTIFACT_DIR="build-$1" ../scripts/livefs-to-usb.sh
 
echo "Done"
