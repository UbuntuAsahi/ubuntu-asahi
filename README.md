# Pop!_OS UEFI ARM64 Image

This is a repository that contains scripts for compiling an ARM64 UEFI image for Pop!_OS.


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
cd pop-arm64
# Build the entire live image
sudo ./build-generic.sh
```

The live GPT image file will be output to `build/pop-os.live.img`.

### Rebuild live image

**Note**: _you must have ran build-generic once already, or at least the non-live scripts!_

```sh
# Go to the build folder
cd pop-arm64/build
# Re-build the live parts of the image
sudo ../scripts/live/04-setup-live-rootfs.sh && \
	sudo ../scripts/live/05-setup-pool.sh && \
	sudo ../scripts/live/06-build-live-image.sh
```

Once again, the live GPT image file will be output to `build/pop-os.live.img`.

### Clean

The `clean.sh` script will do exactly what it says - it will clean up the `build` folder, except for the `cache` folder, which is used by debootstrap to cache debs.

```sh
cd pop-arm64
# Clean the build folder
./clean.sh
```
