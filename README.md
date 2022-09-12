# Ubuntu UEFI Apple Silicon Image

This is a repository that contains scripts for compiling an ARM64 UEFI image for Ubuntu.


## Hosted Installer

To install the prebuilt disk image run:

```
curl -sL https://tobhe.de/ubuntu/install > install.sh	# Download
less install.sh						# Review
sh install.sh						# Run
```

OR if you like to live dangerously:

```
curl -sL https://tobhe.de/ubuntu/install | bash
```

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

### Rebuild live image

**Note**: _you must have ran build-generic once already, or at least the non-live scripts!_

```sh
# Go to the build folder
cd ubuntu-asahi/build
# Re-build the live parts of the image
sudo ../scripts/live/04-setup-live-rootfs.sh && \
	sudo ../scripts/live/05-setup-pool.sh && \
	sudo ../scripts/live/06-build-live-image.sh
```

Once again, the live GPT image file will be output to `build/ubuntu.live.img`.

### Clean

The `clean.sh` script will do exactly what it says - it will clean up the `build` folder, except for the `cache` folder, which is used by debootstrap to cache debs.

```sh
cd ubuntu-asahi
# Clean the build folder
./clean.sh
```

### Related Projects

- [Pop_OS! arm64](https://github.com/pop-os/pop-arm64/)
- [m1-debian](https://git.zerfleddert.de/cgi-bin/gitweb.cgi/m1-debian)
- [asahi-fedora-builder](https://github.com/leifliddy/asahi-fedora-builder)
