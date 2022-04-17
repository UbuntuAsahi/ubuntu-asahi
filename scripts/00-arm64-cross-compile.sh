#!/bin/bash
set -a
if [[ "$(uname -p)" -ne "aarch64" ]]; then
	ARCH=arm64
	CROSS_COMPILE=aarch64-linux-gnu-
	DEBOOTSTRAP=qemu-debootstrap
else
	DEBOOTSTRAP=debootstrap
fi