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

source $CONFIG_F 
rm $LOG_F 2>/dev/null

subcommand=$1; shift  
case "$subcommand" in
    dnsmasq)
        kill $(pidof dnsmasq) 2>/dev/null
        dnsmasq -C /etc/dnsmasq.conf -d 2>&1 > $LOG_F & 
        ;;
esac
