#!/bin/bash

set -e

if [ -z "$1" ]; then
	echo "error: expecting build ID"
	exit 1
fi

# Fetch artifacts
./scripts/launchpad/get-livefs-build.py "$1" "build/build-$1"

# Pack image
cd build
ARTIFACT_DIR="build-$1" ../scripts/lp-disk/squashfs-to-disk-image.sh
 
echo "Done"
