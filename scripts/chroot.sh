#!/bin/bash

grub-install --target=arm64-efi --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg

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
