# Flipper Blackhat OS

## Releases
The best way to get your hands on all the most recent features is the [nightly build](https://github.com/o7-machinehum/flipper-blackhat-os/actions) here. Just click the most recent "Nightly" and you will find the OS artifacts at the bottom. These can then be flashed to an SD card using unix dd, or whatever Windows application you would use to flash a RPI SD card.

## Build
Make sure submodules are initialized:

	git submodule update --init

Change to the top-level Buildroot directory:

	cd buildroot

Initialize the configuration, including the defconfig and this external directory:

	make BR2_EXTERNAL=$PWD/../ flipper_blackhat_a33_defconfig

And compile:

	make

https://www.displaymodule.com/products/3-4480-x-480-transmissive-tft-lcd-mipi?srsltid=AfmBOopuBE7VW4B4JgDqSElYPpUfOnb6hvi7ahoVilX0Sr6CRt9YqKB_
