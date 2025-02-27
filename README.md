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

## Notes

dhcpcd
```
listen-address=192.168.2.1
no-hosts
# log-queries
log-facility=/var/log/dnsmasq.log
dhcp-range=192.168.2.2,192.168.2.254,72h
dhcp-option=option:router,192.168.2.1
dhcp-authoritative
dhcp-option=114,http://go.rogueportal/index.html

# Resolve everything to the portal's IP address.
address=/#/192.168.2.1

```

```
# cat nftables.sh
#!/bin/sh

echo 1 > /proc/sys/net/ipv4/ip_forward

nft add table inet filter
nft add chain inet filter input { type filter hook input priority 0 \; policy accept \; }
nft add rule inet filter input iif "wlan0" ct state established,related accept
nft add rule inet filter input iif "wlan0" ip protocol udp udp dport 53 accept
nft add rule inet filter input iif "wlan0" ip protocol udp udp dport 67 accept
nft add rule inet filter input iif "wlan0" ip protocol tcp tcp dport 80 accept
nft add rule inet filter input iif "wlan0" reject

```
