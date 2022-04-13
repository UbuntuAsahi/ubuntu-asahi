#!/bin/bash
set -xe

# Go back to starting dir on script exit
STARTING_DIR="$PWD"
trap "cd \"$STARTING_DIR\"" EXIT

# Bring in m1m1
test -d m1n1 || git clone --recursive https://github.com/AsahiLinux/m1n1.git
cd m1n1

# Ensure m1n1 commit is latest
git fetch
git reset --hard origin/main
git clean -f -x -d &> /dev/null