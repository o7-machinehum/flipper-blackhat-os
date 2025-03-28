#!/bin/bash

CONFIG_F=blackhat.conf

if test -f $CONFIG_F; then
    CONFIG_F=$(pwd)/$CONFIG_F
    LOG_F=blackhat.log
elif test -f /mnt/$CONFIG_F; then
    CONFIG_F=/mnt/$CONFIG_F
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
    echo "        bh set PASS 'my_wifi_password'"
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
    echo "  kismet            Enable Kismet"
    echo "  rat_driver        Enable RAT Driving"
    echo "  get               Get currently set parameters"
}

function connect_wifi() {
    echo $1> /run/inet_nic
    INET_NIC=$(cat /run/inet_nic)

    ip link set $INET_NIC up
    wpa_supplicant -B -i $INET_NIC -c <(wpa_passphrase $SSID $PASS)
}

function start_ap() {
    echo $1 > /run/ap_nic
    AP_NIC=$(cat /run/ap_nic)

    ip link set $AP_NIC down
    ip addr add $AP_IP/24 dev $AP_NIC

    sed -i "s/^ssid=.*/ssid=$AP_SSID/" /etc/hostapd.conf
    sed -i "s/^interface=.*/interface=$AP_NIC/" /etc/dnsmasq.conf

    kill $(pidof hostapd) 2>/dev/null
    hostapd /etc/hostapd.conf -i $AP_NIC &

    kill $(pidof dnsmasq) 2>/dev/null
    dnsmasq -C /etc/dnsmasq.conf -d 2>&1 > $LOG_F &
}

function evil_twin() {
    INET_NIC=$(cat /run/inet_nic 2>/dev/null) || { echo "Connect to WiFi first"; exit 1; }
    AP_NIC=$(cat /run/ap_nic 2>/dev/null) || { echo "Create AP first"; exit 1; }

    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward

    nft delete rule ip nat postrouting oifname "$INET_NIC" masquerade 2>/dev/null
    nft delete rule ip filter forward iifname "$AP_NIC" accept 2>/dev/null

    nft add table ip nat
    nft add chain ip nat postrouting '{ type nat hook postrouting priority 100 ; }'
    nft add rule ip nat postrouting oifname "$INET_NIC" masquerade

    nft add table ip filter
    nft add chain ip filter forward '{ type nat hook postrouting priority 100 ; }'
    nft add rule ip filter forward iifname "$AP_NIC" accept
}

function evil_portal() {
    INET_NIC=$(cat /run/inet_nic 2>/dev/null) || { echo "Connect to WiFi first"; exit 1; }
    AP_NIC=$(cat /run/ap_nic 2>/dev/null) || { echo "Create AP first"; exit 1; }

    echo 1 > /proc/sys/net/ipv4/ip_forward

    nft flush ruleset
    nft add table ip nat
    nft add chain ip nat prerouting '{ type nat hook prerouting priority 0; }'

    ip addr add 192.168.2.2/24 dev $AP_NIC

    kill -9 $(pidof dnsmasq) 2>/dev/null
    dnsmasq -C /etc/dnsmasq.conf -d 2>&1 > $LOG_F &

    kill -9 $(pidof nginx) 2>/dev/null
    mkdir /var/log/nginx 2>/dev/null
    nginx &

    kill -9 $(pidof evil_portal) 2>/dev/null
    ip link set lo up
    /usr/bin/evil_portal &
}

function set_param() {
    sed -i "/^$1=/c$1=\'$2\'" ${CONFIG_F}
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
            s=$(iw dev | grep -e phy -e wlan)
            s=$(echo $s | sed 's/Interface//g')
            s=$(echo $s | sed 's/#//g')

            for word in $s; do
                if [[ $word == phy* ]]; then
                    phy=$word
                elif [[ $word == wlan* ]]; then
                    eval "$word=$phy"
                fi
            done

            # Manually loop through the wlanX variables
            i=0
            while true; do
                var="wlan$i"
                # Check if the variable exists by testing its value
                eval "value=\$$var"  # Dereference the variable using eval
                if [ -n "$value" ]; then
                    if iw $value info | grep -qE "5180 MHz|5200 MHz|5220 MHz|5240 MHz|5260 MHz"; then
                        echo "$var -> 2.4GHz / 5GHz"
                    else
                        echo "$var -> 2.4GHz"
                    fi
                else
                    break
                fi
                i=$((i+1))
            done
            ;;
        ip)
            ip addr | grep wlan | awk -F': <' '{print $1}' | awk -F'/24' '{print $1}'
            ;;
        *)
            print_help
    esac
}

function bh_kismet() {
    echo $1 > /run/kismet_nic
    KISMET_NIC=$(cat /run/kismet_nic 2>/dev/null)
    kismet -s \
        -c "$KISMET_NIC:channelhop=true,channels=\"36,40,44,48,149,153,157,161,165\"" \
        > /dev/null &
    echo "Kismet running on Port 2501"
}

function ssh() {
    mkdir /var/run/dropbear 2>/dev/null
    /usr/sbin/dropbear -R
    echo "SSH Server Started"
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
    ssh)
        ssh
        ;;
    evil_twin)
        evil_twin
        ;;
    evil_portal)
        evil_portal
        ;;
    kismet)
       bh_kismet "$@"
        ;;
    rat_driver)
        echo "Not Implemented Yet"
        ;;
    help)
        print_help
        ;;
    pull)
        scp machinehum@192.168.1.178:/home/machinehum/projects/flipper-blackhat-os/package/blackhat/src/blackhat.conf /mnt/
        scp machinehum@192.168.1.178:/home/machinehum/projects/flipper-blackhat-os/package/blackhat/src/blackhat.sh /tmp/bh
        echo "run: mv /tmp/bh /usr/bin/bh"
        ;;
    *)
        print_help
        ;;
esac
