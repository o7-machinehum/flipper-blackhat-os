# Flipper Blackhat OS

## Build

Make sure submodules are initialized:

	git submodule update --init

Change to the top-level Buildroot directory:

	cd buildroot

Initialize the configuration, including the defconfig and this external directory:

	make BR2_EXTERNAL=$PWD/../ flipper_blackhat_a33_defconfig

And compile:

	make

## TODO
- [x] Linux autologin
- [x] Disable uboot option to cancel boot
- [ ] FAT32 partition should mount in /mnt/ (mount /dev/mmcblk1p1 /mnt/)
    - [ ] bh app should read blackhat.conf from this
- [ ] Rename all SIPEED stuff to blackhat
