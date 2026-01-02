# Flipper Blackhat OS
A WiFi and security testing OS built on Linux for penetration testing and network analysis. Designed to run on the [Flipper Blackhat](https://github.com/o7-machinehum/flipper-blackhat).

There are two possible builds in this repository...

## Buildroot

### Building
Make sure submodules are initialized:

	git submodule update --init

Change to the top-level Buildroot directory:

	cd buildroot

Initialize the configuration, including the defconfig and this external directory:

	make BR2_EXTERNAL=$PWD/../ flipper_blackhat_a33_defconfig

And compile:

	make

## Armbian

### Building
The armbian build is pretty simple...
    ./armbian_build.sh
