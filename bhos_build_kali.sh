#!/bin/bash
set -e
cd "$(dirname "$0")"

kver="edge" # Edge or current
os_release="kali-rolling"
kali_suite="kali-rolling"

cd armbian
git reset --hard
git clean -fd
cd ..

# rm -rf armbian/userpatches/
rsync -av armbian_config/userpatches/ armbian/userpatches/
rsync -av armbian_config/config/ armbian/config/
(cd armbian && patch -p1 < ../armbian_config/patches/kali-base.patch)
(cd armbian && patch -p1 < ../armbian_config/patches/kali-disable-armbian-repo.patch)

# Copy over dotfiles
DOTFILES="armbian_config/dotfiles"
ROOTDIR="armbian/userpatches/overlay/root"
mkdir -p $ROOTDIR/.config/i3/
cp $DOTFILES/i3_config $ROOTDIR/.config/i3/config

mkdir -p $ROOTDIR/.config/i3status/
cp $DOTFILES/i3status_config $ROOTDIR/.config/i3status/config

cp $DOTFILES/xinitrc $ROOTDIR/.xinitrc

mkdir -p $ROOTDIR/.config/alacritty/
cp $DOTFILES/alacritty.toml $ROOTDIR/.config/alacritty/

cp armbian_config/kali.png $ROOTDIR/

# Add kernel patches
if [[ ${kver} == "edge" ]]; then
    cp patches/linux/0002-rtw88.patch armbian/userpatches/kernel/archive/sunxi-6.16/rtw88.patch
    cp patches/linux/0003-st7701.patch armbian/userpatches/kernel/archive/sunxi-6.16/st7701.patch
elif [[ ${kver} == "current" ]]; then
    cp patches/linux/0003-st7701.patch armbian/userpatches/kernel/archive/sunxi-6.12/st7701.patch
else
    echo "Incorrect Kernel Version"
    exit
fi

armbian_rootfs="armbian/userpatches/overlay/"

# Install packages needed for bh scripts
install -D package/blackhat/src/blackhat.sh "$armbian_rootfs"/usr/local/bin/bh
install -D -m 0644 package/blackhat/src/telegram.py "$armbian_rootfs"/usr/lib/python3/dist-packages/telegram.py
mkdir -p "$armbian_rootfs"/root/bjorn
cp -r package/bjorn/bjorn/* "$armbian_rootfs"/root/bjorn/
install -D -m 0644 package/blackhat/src/blackhat.conf "$armbian_rootfs"/boot/bh/blackhat.conf

# Copy build files over for bhtui
cp -r package/bhtui "$armbian_rootfs"/root/

mkdir -p armbian/userpatches/overlay/boot/bh/scripts
cp -a package/blackhat/scripts/. "$armbian_rootfs"/boot/bh/scripts/

# Install the init script
install -D rootfs_overlay/etc/init.d/S51bh_init "$armbian_rootfs"/usr/local/bin/bh_init

mkdir -p $armbian_rootfs/etc/nginx/
cp rootfs_overlay/etc/nginx/nginx.conf "$armbian_rootfs"/etc/nginx/

mkdir -p $armbian_rootfs/etc/hostapd/
cp rootfs_overlay/etc/hostapd.conf "$armbian_rootfs"/etc/hostapd/
cp rootfs_overlay/etc/dnsmasq.conf "$armbian_rootfs"/etc/
cp rootfs_overlay/etc/ep-rules.nft "$armbian_rootfs"/etc/

mkdir -p "$armbian_rootfs"/var/www/
cp rootfs_overlay/var/www/index.html "$armbian_rootfs"/boot/bh/

cp package/blackhat/src/evil_portal.py "$armbian_rootfs"/usr/local/bin/evil_portal

# Add additional packages
mkdir -p "armbian/config/cli/${os_release}/main"
PKG_CONF="armbian/config/cli/${os_release}/main/packages.additional"
echo usb-modeswitch >> $PKG_CONF
echo xorg >> $PKG_CONF
echo i3 >> $PKG_CONF
echo feh >> $PKG_CONF
echo vim >> $PKG_CONF
echo alacritty >> $PKG_CONF
echo picom >> $PKG_CONF
echo dmenu >> $PKG_CONF
echo nano >> $PKG_CONF
echo nmap >> $PKG_CONF
echo unclutter >> $PKG_CONF
echo brightnessctl >> $PKG_CONF

echo nginx >> $PKG_CONF
echo python3-flask >> $PKG_CONF
echo python3-requests >> $PKG_CONF
echo hostapd >> $PKG_CONF
echo dnsmasq >> $PKG_CONF
echo nftables >> $PKG_CONF
echo chocolate-doom >> $PKG_CONF
echo doom-wad-shareware >> $PKG_CONF
echo cmake >> $PKG_CONF
echo libicu-dev >> $PKG_CONF
echo libicu-dev >> $PKG_CONF
echo aircrack-ng >> $PKG_CONF

echo network-manager-tui >> $PKG_CONF

# Bjorn requirements
echo python3-pandas >> $PKG_CONF
echo python3-pil >> $PKG_CONF
echo python3-numpy >> $PKG_CONF
echo python3-rich >> $PKG_CONF
echo python3-netifaces >> $PKG_CONF
echo python3-ping3 >> $PKG_CONF
echo python3-getmac >> $PKG_CONF
echo python3-paramiko >> $PKG_CONF
echo python3-pymysql >> $PKG_CONF
echo python3-sqlalchemy >> $PKG_CONF
echo python3-nmap >> $PKG_CONF
echo python3-pip >> $PKG_CONF
echo python3-legacy-cgi >> $PKG_CONF
echo mgba-sdl >> $PKG_CONF

cd armbian

# CLEAN_LEVEL=all \
# CLEAN_LEVEL=images,cache \
# ./compile.sh docker-purge # <- This might be required
# ./compile.sh docker-shell # <- Get a shell

./compile.sh build \
    BOARD=flipper-blackhat \
    BRANCH=${kver} \
    BUILD_MINIMAL=no \
    KERNEL_CONFIGURE=no \
    KEEP_ORIGINAL_OS_RELEASE=yes \
    KALI_SUITE=${kali_suite} \
    RELEASE=${os_release}

echo ************ Built Image ************
echo "sudo dd if=armbian/output/images/<built-image>.img of=/dev/sdd bs=4M conv=fsync status=progress"
echo *************************************
