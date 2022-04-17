# Pop!_OS for M1

This is a script for compiling a Pop!_OS image compatible with the Asahi Linux installer.

## Compiling

This script expects to be run on a fairly recent Ubuntu, and will require root at several points.

```sh
$ ./bootstrap.sh
```

This may take a while, as it will compile the Linux kernel, M1N1, and U-Boot, and then bootstrap a Pop!_OS rootfs and install the entire desktop.

If it succeeds, an `out` folder will be created, with an `installer_data.json` and an `os` folder. You can upload this to an HTTP server to serve your Pop! image, or install it locally on your M1 Mac like so:

```sh
# After copying it to your Mac
$ cd out
# Set up environmental variables so the installer knows where to find your OS build
$ export REPO_BASE="$PWD"
$ export INSTALLER_DATA="$PWD/installer_data.json"
# Download and extract the latest installer
$ INSTALLER_PKG="installer-$(curl -s -L https://cdn.asahilinux.org/installer/latest).tar.gz"
$ curl -s -L -o "$INSTALLER_PKG" "https://cdn.asahilinux.org/installer/${INSTALLER_PKG}"
$ tar xf "$INSTALLER_PKG"
# Run the installer
$ ./install.sh
```

## Caveats

Linux on M1 isn't exactly ready for daily use yet. Several major things lack full support, including...

 - GPU acceleration
 - USB 3
 - Speakers
 - HDMI
 - Headphone Jack (M1 Pro/Max)
 - DisplayPort
 - Thunderbolt
 - Bluetooth
 - Hardware video decode
 - Neural engine
 - CPU deep sleep/idle
 - Sleep mode
 - Camera
 - Touch bar

In addition, some programs such as Chromium don't work yet, even with their ARM64 builds.

However, if you understand these caveats, and just want to mess around, then feel free to set up an install :)

## Support Asahi Linux

This is *not* an official Asahi Linux project, nor is System76 affiliated with the project in any way.

However, if you wish to give support to the Asahi project, then please [support the main developer, marcan, on Github Sponsors](https://github.com/sponsors/marcan)!
