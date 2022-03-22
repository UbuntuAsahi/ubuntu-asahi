#!/bin/bash

# SPDX-License-Identifier: MIT

set -x
set -e

unset LC_CTYPE
unset LANG

export DEBOOTSTRAP=debootstrap

handle_crosscompile()
{
        if [ "`uname -m`" != 'aarch64' ]; then
                export ARCH=arm64
                export CROSS_COMPILE=aarch64-linux-gnu-
                export DEBOOTSTRAP=qemu-debootstrap
        fi
}

build_linux()
{
(
        handle_crosscompile
        test -d linux || git clone --depth 1 https://github.com/AsahiLinux/linux -b asahi
        cd linux
        git fetch
        git reset --hard origin/asahi; git clean -f -x -d &> /dev/null
        curl -s https://tg.st/u/40c9642c7569c52189f84621316fc9149979ee65.patch | git am -
        curl -s https://tg.st/u/0001-4k-iommu-patch-2022-03-11.patch | git am -
        curl -s https://tg.st/u/config-2022-03-17-distro-sven-jannau.txt > .config
        make olddefconfig
        make -j `nproc` V=0 bindeb-pkg
)
}

build_m1n1()
{
(
        test -d m1n1 || git clone --recursive https://github.com/AsahiLinux/m1n1.git
        cd m1n1
        git fetch
        git reset --hard origin/main; git clean -f -x -d &> /dev/null
        make -j `nproc`
)
}

build_uboot()
{
(
        handle_crosscompile
        test -d u-boot || git clone --depth 1 https://github.com/AsahiLinux/u-boot
        cd u-boot
        git fetch
        git reset --hard origin/asahi; git clean -f -x -d &> /dev/null
        make apple_m1_defconfig
        make -j `nproc`
)

        cat m1n1/build/m1n1.bin   `find linux/arch/arm64/boot/dts/apple/ -name \*.dtb` <(gzip -c u-boot/u-boot-nodtb.bin) > u-boot.bin
        cat m1n1/build/m1n1.macho `find linux/arch/arm64/boot/dts/apple/ -name \*.dtb` <(gzip -c u-boot/u-boot-nodtb.bin) > u-boot.macho
}

build_dummy()
{
(
        equivs-build ../pkg/linux-pop-m1-dummy
)
}

build_rootfs()
{
(
        handle_crosscompile
        sudo rm -rf testing
        mkdir -p cache
        sudo eatmydata qemu-debootstrap \
                --arch=arm64 \
                --cache-dir=`pwd`/cache \
                --include initramfs-tools,apt,grub-efi-arm64 \
                jammy \
                testing \
                http://ports.ubuntu.com/ubuntu-ports

        export KERNEL=`ls -1rt linux-image*.deb | grep -v dbg | tail -1`
        export DUMMY=`ls -1rt linux-pop-m1-dummy*.deb | tail -1`

        cd testing

        sudo mkdir -p boot/efi

        sudo rsync \
                --recursive \
                --verbose \
                "../../fs/etc/" \
                "etc/"

        sudo bash -c 'chroot . apt update'


        # Install kernel + linux-{system76,raspi} dummy packages
        sudo cp ../${KERNEL} .
        sudo cp ../${DUMMY} .
        sudo chroot . dpkg -i ${KERNEL} ${DUMMY}
        sudo rm ${KERNEL} ${DUMMY}

        # Ensure actual Pi packages are never installed
        sudo bash -c 'chroot . apt-mark hold snapd pop-desktop-raspi linux-raspi linux-firmware-raspi2 rpi-eeprom u-boot-rpi'
        sudo bash -c 'chroot . apt -y dist-upgrade'
        sudo bash -c 'chroot . apt -y install linux-firmware pop-desktop'
        sudo bash -c 'chroot . apt -y autoremove'
        sudo bash -c 'chroot . apt -y clean'

        sudo -- perl -p -i -e 's/root:x:/root::/' etc/passwd

        sudo -- ln -s lib/systemd/systemd init
)
}

build_dd()
{
(
        rm -f media
        dd if=/dev/zero of=media bs=1 count=0 seek=5G
        mkdir -p mnt
        mkfs.ext4 media
        tune2fs -O extents,uninit_bg,dir_index -m 0 -c 0 -i 0 media
        sudo mount -o loop media mnt
        sudo cp -a testing/* mnt/
        sudo rm mnt/init
        sudo umount mnt
        tar cf - media | pigz -9 > m1.tgz
)
}

build_efi()
{
(
        rm -rf EFI
        mkdir -p EFI/boot EFI/ubuntu
        cp testing/usr/lib/grub/arm64-efi/monolithic/grubaa64.efi EFI/boot/bootaa64.efi

        export INITRD=`ls -1 testing/boot/ | grep initrd`
        export VMLINUZ=`ls -1 testing/boot/ | grep vmlinuz`
        export UUID=`blkid media | awk -F\" '{print $2}'`
        cat > EFI/ubuntu/grub.cfg <<EOF
search.fs_uuid ${UUID} root
linux (\$root)/boot/${VMLINUZ} root=UUID=${UUID} rw
initrd (\$root)/boot/${INITRD}
boot
EOF
        tar czf efi.tgz EFI
)
}

build_asahi_installer_image()
{
(
        rm -rf aii
        mkdir -p aii/esp/m1n1
        cp -a EFI aii/esp/
        cp u-boot.bin aii/esp/m1n1/boot.bin
        ln media aii/media
        cd aii
        zip -r9 ../debian-base.zip esp media
)
}

mkdir -p build
cd build

#sudo apt-get install -y build-essential bash git locales gcc-aarch64-linux-gnu libc6-dev-arm64-cross device-tree-compiler imagemagick ccache eatmydata debootstrap pigz libncurses-dev qemu-user-static binfmt-support rsync git flex bison bc kmod cpio libncurses5-dev libelf-dev:native libssl-dev dwarves

#build_linux
#build_m1n1
#build_uboot
build_dummy
build_rootfs
build_dd
build_efi
build_asahi_installer_image
