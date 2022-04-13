#!/bin/bash
set -xe

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
trap "cd \"$STARTING_DIR\"" EXIT

equivs-build ../pkg/linux-pop-arm64-dummy