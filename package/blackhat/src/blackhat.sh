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

echo "Loaded Config: $CONFIG_F"

source $CONFIG_F 
rm $LOG_F 2>/dev/null

function print_help() {
	echo "Commands:"
    echo "useage: bh wifi connect wlan0"
	echo "  set"
	echo "    SSID            Set SSID of WiFi network to connect to"
	echo "    PASS            Set password for WiFi network: SSID"
	echo "    AP_SSID         Set SSID of WiFi network you're creating"
	echo "  wifi              Connect to a WiFi network"
    echo "    list            List WiFi APs"
    echo "    con <interface> Connect to WiFi AP"
    echo "    dev             List devices"
	echo "    ap <interface>  Enable Access Point"
    echo "    ip              Get IP Address"
	echo "  ssh               Enable SSH"
	echo "  evil_twin         Enable the evil twin AP"
	echo "  evil_portal       Enable the evil portal AP"
    echo "  rat_driver        Enable RAT Driving"
	echo "  get               Get currently set parameters"
}

function connect_wifi() {
	ip link set $1 up
	wpa_supplicant -B -i $1 -c <(wpa_passphrase $SSID $PASS)
}

function start_ap() {
    ap_nic=$1
	ip link set $ap_nic down
	ip addr add 192.168.2.1/24 dev $ap_nic

    sed -i "s/^ssid=.*/ssid=$AP_SSID/" /etc/hostapd.conf

	kill $(pidof hostapd)
	hostapd /etc/hostapd.conf -i $1 &

	kill $(pidof dnsmasq)
	dnsmasq -C /etc/dnsmasq.conf -d 2>&1 > $LOG_F & 

}

function evil_twin() {
	ip link set $RADIO_AP down
	ip addr add 192.168.2.1/24 dev $RADIO_AP

	iptables --table nat --append POSTROUTING --out-interface $RADIO_CLIENT -j MASQUERADE
	iptables --append FORWARD --in-interface $RADIO_AP -j ACCEPT
	echo 1 > /proc/sys/net/ipv4/ip_forward

	hostapd /etc/hostapd.conf &
	connect_wifi $RADIO_CLIENT

	kill $(pidof dnsmasq)
	dnsmasq -C /etc/dnsmasq.conf -d 2>&1 > $LOG_F & 
}


function evil_portal() {
    echo "Not Implemented yet!"
}

function set_param() {
	sed -i "/^$1=/c$1=\"$2\"" ${CONFIG_F}	
}

function check() {
    if [ -z $1 ]; then
        print_help
        exit
    fi
}

function wifi() {
	case "$1" in
		list)
            check $2            
			iw $2 scan | grep "SSID:"
			;;
		connect)
            check $2            
			connect_wifi $2
			;;
        ap)
            check $2            
            start_ap $2
            ;;
        dev)
            iw dev | grep -e phy -e wlan
            iw list | awk '/Wiphy/{if(phy) {if(b1 && b2) {print "phy" phy ": 2.4 GHz and 5 GHz"} else if(b1) {print "phy" phy ": 2.4 GHz"} else if(b2) {print "phy" phy ": 5 GHz"}; b1=0; b2=0} phy=$2} /Band 1/{b1=1} /Band 2/{b2=1} END{if(b1 && b2){print "phy" phy ": 2.4 GHz and 5 GHz"} else if(b1){print "phy" phy ": 2.4 GHz"} else if(b2){print "phy" phy ": 5 GHz"}}'
            ;;
        ip)
            ip addr | grep wlan | awk -F': <' '{print $1}' | awk -F'/24' '{print $1}'
            ;;
		*)
			print_help
	esac
}

subcommand=$1; shift  
case "$subcommand" in
	set)
		set_param "$@"
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
    pull)
        scp machinehum@192.168.1.103:/home/machinehum/projects/flipper-blackhat-os/package/blackhat/src/blackhat.sh /usr/bin/bh
        ;;
	*)
		print_help
		;;
esac
