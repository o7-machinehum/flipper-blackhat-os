#!/bin/bash
# This runs inside chroot during Armbian build

set -e

echo "Customizing image to skip Armbian first login..."

# Set root password (change 'root' to whatever you want)
echo "root:root" | chpasswd

mkdir /boot/bh/

# /tmp/overlay contains the tree from userpatches/overlay
if [ -d /tmp/overlay ]; then
    # Copy everything over the rootfs (preserving perms)
    cp -a /tmp/overlay/* /
fi

systemctl enable bh-boot

# Force Realtek dongles to _not_ come up as USB MSD
# https://linux.die.net/man/1/usb_modeswitch
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

# Detect a likely serial console. For most boards this is ttyS0 or ttyAMA0; adjust if needed.
SERIAL_TTY="ttyS0"

mkdir -p /etc/systemd/system/serial-getty@${SERIAL_TTY}.service.d
cat >/etc/systemd/system/serial-getty@${SERIAL_TTY}.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --keep-baud 115200,38400,9600 %I \$TERM
EOF

echo bh > /etc/hostname
echo 'FONT="Lat7-Terminus12x6.psf.gz"' >> /etc/default/console-setup

### Boot optimisation below
systemctl disable --now armbian-ramlog.service
systemctl disable --now keyboard-setup.service

## Remove network manager requirement from systemd-user-sessions
install -D -m 0644 /usr/lib/systemd/system/systemd-user-sessions.service \
  /etc/systemd/system/systemd-user-sessions.service

# Remove network.target from the After= line(s)
sed -i 's/[[:space:]]network\.target//g' /etc/systemd/system/systemd-user-sessions.service
sed -i 's/network\.target[[:space:]]//g' /etc/systemd/system/systemd-user-sessions.service

## Disable relationship between network manager and getty.
# 1) Write an explicit tty1 unit that does NOT reference rc-local
cat > /etc/systemd/system/getty@tty1.service <<'EOF'
[Unit]
Description=Getty on tty1
Documentation=man:agetty(8) man:systemd-getty-generator(8)
After=systemd-user-sessions.service getty-pre.target basic.target
Before=getty.target
IgnoreOnIsolate=yes
Conflicts=rescue.service
Before=rescue.service
ConditionPathExists=/dev/tty0

[Service]
ExecStart=-/usr/sbin/agetty --noreset --noclear --issue-file=/etc/issue:/etc/issue.d:/run/issue.d:/usr/lib/issue.d tty1 $TERM
Type=idle
Restart=always
RestartSec=0
UtmpIdentifier=tty1
StandardInput=tty
StandardOutput=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=no

[Install]
WantedBy=getty.target
EOF

echo "Customization complete."
