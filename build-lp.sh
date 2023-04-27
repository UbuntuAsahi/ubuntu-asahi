#!/bin/bash

set -e

mkdir -p build
cd build

../scripts/lp-disk/squashfs-to-disk-image.sh

echo "Done"
