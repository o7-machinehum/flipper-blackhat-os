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
I couldn't really get docker working, if you have better luck, PR's welcome

Build the Images
	docker build -t buildroot-env --build-arg HOST_USERNAME=$(whoami) --build-arg HOST_UID=$(id -u) --build-arg HOST_GID=$(id -g) .

Rin it
	docker run -it -v $(pwd):/home/$(whoami)/buildroot buildroot-env


## Device
There are two WiFi cards, one SDIO (wlan0, rtw88_8723ds.ko) and one USB (wlan1, rtw88_8821cu.ko). It makes more sense to use wlan1 as the rtw88_8821cu is a 5Ghz/2.4Ghz WiFi chipset.


## Notes
```
iw dev wlan1 set monitor none
airmon-ng start wlan1
# I think these commands do the same thing.
airbase-ng -e Turnip-WiFi -c 11 wlan1
ifconfig at0 up
