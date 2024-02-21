#!/bin/bash

if [ "$1" == "" ]; then
    echo "No arguments provided. Usage: ./flash.sh /dev/sdX"
    echo "                              ./flash.sh 192.168.1.100"
    exit 1
fi

echo $1

if [[ "$1" == /dev/* ]]; then
	cowsay -f ghostbusters Flashing SD card! $1
	sudo dd if=buildroot/output/images/sdcard.img of=$1 bs=4M conv=fsync
	exit 1
fi

IP=$1

cowsay -f ghostbusters Flashing rootfs to $IP
OP="-q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
sshpass -p 'blackhat' scp $OP package/blackhat/src/blackhat.sh root@$IP:/usr/bin/bh 
sshpass -p 'blackhat' scp $OP package/blackhat/src/blackhat.conf root@$IP:/etc/blackhat.conf
sshpass -p 'blackhat' scp $OP rootfs_overlay/etc/dnsmasq.conf root@$IP:/etc/dnsmasq.conf
