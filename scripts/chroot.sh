#!/bin/bash

# Install grub
mkdir -p /boot/efi
grub-install --target=arm64-efi --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg

# Install m1n1 + u-boot
m1n1="/usr/lib/m1n1/m1n1.bin"
if [ -e "/usr/lib/u-boot-asahi/u-boot-nodtb.bin" ]; then
	uboot="/usr/lib/u-boot-asahi/u-boot-nodtb.bin"
elif [ -e "/usr/lib/u-boot/apple_m1/u-boot-nodtb.bin" ]; then
	uboot="/usr/lib/u-boot/apple_m1/u-boot-nodtb.bin"
else
	echo "error: u-boot-nodtb.bin not found"
	exit 1
fi
if [ ! -e "${m1n1}" ]; then
	echo "error: m1n1.bin not found at ${m1n1}"
	exit 1
fi
dtbs=( /lib/firmware/*/device-tree/apple/*.dtb )
if [ ${#dtbs[@]} -eq 0 ]; then
	echo "error: no DTB files found"
	exit 1
fi
mkdir -p /boot/efi/m1n1
target="/boot/efi/m1n1/boot.bin"
cat "${m1n1}" "${dtbs[@]}" \
    <(gzip -c "${uboot}") \
    >"${target}"

# Setup systemd-firstboot(1) on server where gnome-inital-setup isn't available
if [ ! -f /usr/lib/systemd/user/gnome-initial-setup.service ]; then
	rm /etc/{localtime,hostname,shadow,locale.conf}
	mkdir -p /etc/systemd/system/systemd-firstboot.service.d
	cat <<-EOF > /etc/systemd/system/systemd-firstboot.service.d/install.conf
		[Service]
		ExecStartPre=/usr/bin/plymouth quit --wait
		ExecStart=
		ExecStart=systemd-firstboot --prompt-keymap --prompt-locale --prompt-timezone --prompt-hostname --prompt-root-password

		[Install]
		WantedBy=sysinit.target
	EOF
	systemctl enable systemd-firstboot.service
fi

# Delete self
rm -- "$0"
