#!/usr/bin/python

import time
import pywifi
import os
import re
from pywifi import const

NMAP_CMD = "nmap -p- -sS -sV -O -oN /mnt/nmap/<ap_ssid>.log <target>"

def wait_until_not(iface, status):
    while iface.status() == status:
        time.sleep(1)

def wait_until(iface, status):
    while iface.status() != status:
        time.sleep(1)

def bash(cmd):
    return os.popen(cmd).read()

def get_ip(dev):
    retries = 0

    while True:
        try:
            ip = bash("ip a")
            ip = re.search("inet(.*)brd", ip.split(f"{dev}:")[1]).group(1)
            ip = ip.strip(" ")
            break
        except:
            retries += 1
            time.sleep(1)
            if retries > 10:
                return None
            continue

    return ip

def run_nmap(ap_ssid):
    print("Running Nmap")

    ip = get_ip("wlan1")

    if ip is None:
        print("Not getting an IP address. Giving up.")
        return

    ip, subnet = ip.split("/")

    range_scan = False
    if subnet == "16":
        range_scan = True

    ip = ip.split(".")[0:3]
    ip.append("0")

    if range_scan:
        ip[2] = "<range>"

    ip = ".".join(ip) + "/24"

    cmd = NMAP_CMD.replace("<target>", ip)
    print(f"Scanning: {ip}")

    if range_scan:
        for i in range(0, 254):
            cmd_run = cmd.replace("<range>", str(i))
            cmd_run = cmd_run.replace("<ap_ssid>", ap_ssid + str(i))
            print(f"Logging to /mnt/{ap_ssid}.log")
            print(cmd_run)
            bash(cmd_run)
    else:
        cmd = cmd.replace("<ap_ssid>", ap_ssid)
        print(f"Logging to /mnt/{ap_ssid}.log")
        print(cmd)
        bash(cmd)

def run():
    wifi = pywifi.PyWiFi()
    iface = wifi.interfaces()[0] # Start with wlan0

    iface.disconnect()
    wait_until_not(iface, const.IFACE_CONNECTED)
    iface.scan()
    wait_until_not(iface, const.IFACE_SCANNING)

    aps = iface.scan_results()
    for ap in aps:
        # Check for security
        # Or AKM_TYPE_NONE
        if len(ap.akm) == 0:
            print(f"Connecting to {ap.ssid}")
            ap.akm.append(const.AKM_TYPE_NONE)
            iface.remove_all_network_profiles()
            tmp_profile = iface.add_network_profile(ap)
            iface.connect(tmp_profile)
            wait_until(iface, const.IFACE_CONNECTED)
            run_nmap(ap.ssid)
            iface.disconnect()

if __name__ == '__main__':
    # You need to run wpa_supplicant
    bash("mkdir /mnt/nmap 2>/dev/null")
    bash("ip link set lo up")

    while True:
        run()
        time.sleep(1)
