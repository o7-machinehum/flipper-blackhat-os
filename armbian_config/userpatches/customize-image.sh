#!/bin/bash
# This runs inside chroot during Armbian build

set -e

echo "Customizing image to skip Armbian first login..."

# Set root password (change 'root' to whatever you want)
echo "root:root" | chpasswd

mkdir -p /boot/bh/

# /tmp/overlay contains the tree from userpatches/overlay
if [ -d /tmp/overlay ]; then
    # Copy everything over the rootfs (preserving perms)
    cp -a /tmp/overlay/* /
fi

systemctl enable bh-boot

# These are started manually
systemctl disable nginx || true

systemctl disable hostapd || true
systemctl unmask hostapd || true

systemctl unmask dnsmasq || true
systemctl disable dnsmasq || true

systemctl unmask kismet || true
systemctl disable kismet || true

sudo systemctl enable chrony

# Force Realtek dongles to _not_ come up as USB MSD
# https://linux.die.net/man/1/usb_modeswitch
mkdir -p /etc/udev/rules.d
echo 'ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="1a2b", ATTR{bConfigurationValue}!="1", ATTR{bConfigurationValue}="1"' \
    >> /etc/udev/rules.d/50-usb-realtek-net.rules

# Disable Armbian first-login wizard (names differ by version, so we nuke all of them safely)
for svc in \
  armbian-firstlogin \
  armbian-config-firstboot \
  first-boot-setup \
  ; do
  if systemctl list-unit-files | grep -q "^${svc}.service"; then
    systemctl disable "${svc}.service" || true
    systemctl mask "${svc}.service" || true
  fi
done

# Also remove the "not logged in yet" flag if present
rm -f /root/.not_logged_in_yet || true

mkdir -p /etc/default
echo 'FONT="Lat7-Terminus12x6.psf.gz"' >> /etc/default/console-setup
setupcon --save-only

### Boot optimisation below
systemctl disable armbian-ramlog.service || true
systemctl disable keyboard-setup.service || true

## Remove network manager requirement from systemd-user-sessions
install -D -m 0644 /usr/lib/systemd/system/systemd-user-sessions.service \
  /etc/systemd/system/systemd-user-sessions.service

# Remove network.target from the After= line(s)
sed -i 's/[[:space:]]network\.target//g' /etc/systemd/system/systemd-user-sessions.service
sed -i 's/network\.target[[:space:]]//g' /etc/systemd/system/systemd-user-sessions.service

# Alias python -> python3
ln -sf /usr/bin/python3 /usr/bin/python

# This is something that makes the terminal more fancy (remove it)
rm -f /etc/profile.d/80-systemd-osc-context.sh

# Use old wlanX names
echo "extraargs=net.ifnames=0 biosdevname=0" >> /boot/armbianEnv.txt

# Bjorn requirements
python3 -m pip install smbprotocol --break-system-packages
python3 -m pip install pysmb --break-system-packages

cd /root/bhtui
make install

echo "Customization complete."
