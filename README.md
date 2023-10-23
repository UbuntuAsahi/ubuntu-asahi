# Ubuntu Apple Silicon Image

This is repository contains scripts for compiling native Ubuntu images for
Apple silicon hardware such as the Apple M1 and M2.

## Hosted Installer

To install a prebuilt image run:

```
curl -sL https://ubuntuasahi.org/install > install.sh	# Download
less install.sh						# Review
sh install.sh						# Run
```

or if you like to live dangerously:

```
curl -sL https://ubuntuasahi.org/install | bash
```

The installer offers a choice of different Ubuntu releases and build configurations.

Currently supported are:

- Ubuntu Desktop 23.10
- Ubuntu Desktop 22.04 LTS

The default username and password are both **ubuntu**. Root access can be achieved via `sudo`.

### Can I dual-boot macOS and Linux?

Yes! The installer can automatically resize your macos partition according to your liking and install
Ubuntu in the freed up space. Removing macos is not even supported at the moment since it is required
to update the system firmware.

## Building

If you do not want to use the prebuilt disk image, you can build one yourself with the instructions below.

### Install dependencies

```sh
# Install dependencies
sudo apt-get install arch-install-scripts debootstrap mtools parted gnupg eatmydata rsync git squashfs-tools zip
# Install dependencies, if your builder system is NOT arm64
sudo apt-get install binfmt-support qemu qemu-user-static
```

### Build everything

```sh
cd ubuntu-asahi
# Build the entire live image
sudo ./build-generic.sh
```

The live GPT image file will be output to `build/ubuntu.live.img`, the zip archive for the Asahi Linux installer
will be output to `build/ubuntu.live.img.zip`.

### Related Projects

- [Asahi Linux](https://asahilinux.org/)
- [Pop_OS! arm64](https://github.com/pop-os/pop-arm64/)
- [m1-debian](https://git.zerfleddert.de/cgi-bin/gitweb.cgi/m1-debian)
- [asahi-fedora-builder](https://github.com/leifliddy/asahi-fedora-builder)
