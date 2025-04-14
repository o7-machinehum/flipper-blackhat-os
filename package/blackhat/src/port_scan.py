#!/usr/bin/python

import os
import time
import re

SUDO = False
FLOC = "/mnt/loot/"

def bash(cmd, sudo=False):
    if sudo:
        cmd = f"sudo {cmd}"

    return os.popen(cmd).read()

def get_aps(dev):
    aps_d = {}
    awk_f = "../../../rootfs_overlay/root/iw.awk"
    aps = bash(f"iw dev {dev} scan | awk -f {awk_f}", SUDO)

    for ap in aps.split("\n")[1:]:
        try:
            ap = ap.split("\t")
            aps_d[ap[0]] = ap[1]
        except:
            continue

    return aps_d

def connect_to_wifi(dev, ssid):
    bash(f'iw dev {dev} connect "{ssid}"', SUDO)

def disconnect_from_wifi(dev):
    bash(f"iw dev {dev} disconnect", SUDO)

def get_ip(dev):
    ip = bash("ip a", False)
    ip = re.search("inet(.*)brd", ip.split(f"{dev}:")[1]).group(1)
    ip = ip.strip(" ").split("/")[0]
    return ip

def is_connected(dev, timeout=10):
    retries = 0
    while(retries < timeout):
        status = bash(f"iw dev {dev} link")
        if "Not connected." in status:
            time.sleep(1)
            retries += 1
            continue
        else:
            return True
            break

    return False

def port_scan(ip):
    base_ip = ip.split(".")
    base_ip[3] = "1"
    base_ip = ".".join(base_ip)

    return bash(f"nmap -sV {base_ip}-255", SUDO)

if __name__ == '__main__':
    dev = "wlan1"
    aps = get_aps(dev)
    bash(f"mkdir {FLOC} > /dev/null", False)

    for ap in aps:
        if aps[ap] == "Open":
            print(f"Conecting to: {ap}")
            connect_to_wifi(dev, ap)
            if(is_connected(dev)):
                ip = get_ip(dev)
                print(f"Port Scan on: {ip}")
                scan = port_scan(ip)
                with open(f"{FLOC}{ap}.nmap", "w") as f:
                    f.write(scan)
                disconnect_from_wifi(dev)

