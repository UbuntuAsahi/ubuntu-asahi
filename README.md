# Ubuntu UEFI Apple Silicon Image

This is a repository that contains scripts for compiling an ARM64 UEFI image for Ubuntu.


## Building


### Install dependencies

```sh
# Install dependencies
sudo apt-get install debootstrap mtools parted gnupg systemd-container eatmydata rsync git squashfs-tools
# Install dependencies, if your builder system is NOT arm64
sudo apt-get install binfmt-support qemu qemu-user-static
```

### Build everything

```sh
cd ubuntu-asahi
# Build the entire live image
sudo ./build-generic.sh
```

The live GPT image file will be output to `build/ubuntu.live.img`.

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
