#!/bin/bash

if [ "$1" == "" ]; then
    >&2 echo "No arguments provided. Usage: ./flash.sh /dev/sdX"
    exit 1
fi

cowsay -f ghostbusters Flashing SD card! $1
sudo dd if=buildroot/output/images/sdcard.img of=$1 bs=4M conv=fsync
