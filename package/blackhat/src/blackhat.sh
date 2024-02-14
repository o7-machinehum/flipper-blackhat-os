#!/bin/bash

CONFIG_F=blackhat.conf

if test -f $CONFIG_F; then
	CONFIG_F=$(pwd)/$CONFIG_F
	echo "Loaded Config From: $CONFIG_F"
elif test -f /etc/$CONFIG_F; then 
	CONFIG_F=/etc/blackhat.conf
	echo "Loaded Config From: $CONFIG_F"
else
	echo "Could not load conf file"
	exit
fi
source $CONFIG_F 

function print_help() {
	echo "Usage: bh [subcommand] [options]"
	echo "Subcommands:"
	echo "  list_wifi       List _2G_ WiFi Networks"
	echo "  connect_wifi    Connect to a WiFi network"
	echo "Options for connect_wifi:"
	echo "  -p    Specify the password for the WiFi network"
	echo "  -s    Specify the SSID for the WiFi network"
}

function list_wifi() {
	iw $RADIO_CLIENT scan | grep "SSID:"
}

function evil_twin() {
	iw dev wlan1 set monitor none
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

subcommand=$1; shift  
case "$subcommand" in
	set)
		set "$@"
		;;
	get)
		cat $CONFIG_F
		;;
	connect_wifi)
		wpa_supplicant -B -i $RADIO_CLIENT -c <(wpa_passphrase $SSID $PASS)
		;;
	help)
		print_help
		;;
	*)
		print_help
		;;
esac
