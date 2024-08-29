# Ubuntu for Apple Silicon

<p align="center">
  <img src="https://github.com/UbuntuAsahi/media/blob/main/logo/logo-128.png" alt="Ubuntu Asahi Logo" />
</p>

This repository contains scripts to build native Ubuntu images for Apple
silicon hardware such as the Apple M1 and M2.

Most of our code has moved to
packages nowadays which are available under our
[Ubuntu Asahi launchpad team](https://launchpad.net/~ubuntu-asahi).
The scripts in this repository can be used to start launchpad
[livefs builds](https://dev.launchpad.net/Soyuz/LiveFilesystems) from
our Ubuntu Asahi PPA and convert their output into a zip archive suitable
for the [Asahi Installer](https://github.com/AsahiLinux/asahi-installer).

## Hosted Installer

If you are interested in running Ubuntu Asahi on your machine, here is how you
can install one of our pre-built images. In your macos terminal run:

```
curl -sL https://ubuntuasahi.org/install > install.sh	# Download
less install.sh						# Review
sh install.sh						# Run
```

or if you like to live dangerously:

```
curl -sL https://ubuntuasahi.org/install | bash
```

The installer is interactive and offers a choice of different Ubuntu releases and
build configurations.

Currently supported are:

- Ubuntu Desktop 24.04
- Ubuntu Desktop 23.10

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

Hold the power button on boot until you see "Loading startup options". You can
now choose which system you want to boot. You can change the default boot entry
by holding the `Option` key and selecting "Always Use".

## How can I remove Ubuntu Asahi?

There is no automated uninstaller, but you can uninstall Ubuntu Asahi by booting
into macos, removing all Ubuntu partitions and then resizing the macos APFS
container to the full size.
A detailed guide is provided in the
[Asahi Linux Wiki](https://github.com/AsahiLinux/docs/wiki/Partitioning-cheatsheet).

## More questions?

Join us on IRC or Matrix!
`#ubuntu-asahi` on [OFTC](https://www.oftc.net/) or `#_oftc_#ubuntu-asahi:matrix.org`.

For more infos you can also check our website [ubuntuasahi.org](https://ubuntuasahi.org)
and follow us on Mastodon at
[@ubuntuasahi@treehouse.systems](https://social.treehouse.systems/@ubuntuasahi).

### Related Projects

- [Asahi Linux](https://asahilinux.org/)
- [Fedora Asahi Remix](https://fedora-asahi-remix.org/)
- [Debian Bananas Team](https://wiki.debian.org/Teams/Bananas)
