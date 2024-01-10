# Sipeed Lichee RV

## Build

Make sure submodules are initialized:

	git submodule update --init

Change to the top-level Buildroot directory:

	cd buildroot

Initialize the configuration, including the defconfig and this external directory:

	make BR2_EXTERNAL=$PWD/../ flipper_blackhat_defconfig

And compile:

	make

## Docker

Build the Images
	docker build -t buildroot-env --build-arg HOST_USERNAME=$(whoami) --build-arg HOST_UID=$(id -u) --build-arg HOST_GID=$(id -g) .

Rin it
	docker run -it -v $(pwd):/home/$(whoami)/buildroot buildroot-env
