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

https://www.displaymodule.com/products/3-4480-x-480-transmissive-tft-lcd-mipi?srsltid=AfmBOopuBE7VW4B4JgDqSElYPpUfOnb6hvi7ahoVilX0Sr6CRt9YqKB_
