# Ubuntu Apple Silicon Image

This repository contains scripts to compile native Ubuntu images for
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

# FAQ

## Can I dual-boot macOS and Linux?

Yes! The installer can automatically resize your macos partition according to
your liking and install Ubuntu in the freed up space.
Removing macos is not even supported at the moment since it is required
to update the system firmware.

## Does Ubuntu Asahi support the same features/hardware as Fedora Asahi?

We try to quickly adapt features added by the reference Asahi distribution.
Since we always wait for an official release first, it might take us a few
weeks longer to roll out support for new hardware but we generally aim for
feature parity.

## What do I need to do to enable graphics acceleration/sound/webcam?

No additional steps are necessary, it should all work out of the box.
In the past there was an "linux-asahi-edge" kernel providing additional
features, nowadays everything is included by default.

## How can I boot macos or change the default boot entry?

Hold the power button on boot until you see "Loading starup options". You can
now choose which system you want to boot. You can change the default boot entry
by holding the `Option` key and selecting "Always Use".

## How can I remove Ubuntu Asahi?

There is no automated uninstaller, but you can uninstall Ubuntu Asahi by booting
into macos, removing all Ubuntu partitions and then resizing the macos APFS
container to the full size.
A detailed guide is provided in the
[Asahi Linux Wiki](https://github.com/AsahiLinux/docs/wiki/Partitioning-cheatsheet).

### Related Projects

- [Asahi Linux](https://asahilinux.org/)
- [Pop_OS! arm64](https://github.com/pop-os/pop-arm64/)
- [m1-debian](https://git.zerfleddert.de/cgi-bin/gitweb.cgi/m1-debian)
- [asahi-fedora-builder](https://github.com/leifliddy/asahi-fedora-builder)
