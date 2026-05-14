#!/bin/bash
set -e
cd "$(dirname "$0")"

kver="${KVER:-edge}" # Edge or current
os_release="${UBUNTU_RELEASE:-noble}"

cd armbian
git reset --hard
git clean -fd
cd ..

# rm -rf armbian/userpatches/
rsync -av armbian_config/userpatches/ armbian/userpatches/
rsync -av armbian_config/config/ armbian/config/

# Copy over dotfiles
DOTFILES="armbian_config/dotfiles"
ROOTDIR="armbian/userpatches/overlay/root"
mkdir -p "$ROOTDIR"/.config/i3/
cp "$DOTFILES"/i3_config "$ROOTDIR"/.config/i3/config

mkdir -p "$ROOTDIR"/.config/i3status/
cp "$DOTFILES"/i3status_config "$ROOTDIR"/.config/i3status/config

cp "$DOTFILES"/xinitrc "$ROOTDIR"/.xinitrc

mkdir -p "$ROOTDIR"/.config/alacritty/
cp "$DOTFILES"/alacritty.toml "$ROOTDIR"/.config/alacritty/

cp armbian_config/kali.png "$ROOTDIR"/

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
mkdir -p "$armbian_rootfs"/root/bjorn
cp -r package/bjorn/bjorn/* "$armbian_rootfs"/root/bjorn/
install -D -m 0644 package/blackhat/src/blackhat.conf "$armbian_rootfs"/boot/bh/blackhat.conf

# Copy build files over for bhtui
cp -r package/bhtui "$armbian_rootfs"/root/

mkdir -p armbian/userpatches/overlay/boot/bh/scripts
cp -a package/blackhat/scripts/. "$armbian_rootfs"/boot/bh/scripts/

# Install the init script
install -D rootfs_overlay/etc/init.d/S51bh_init "$armbian_rootfs"/usr/local/bin/bh_init

mkdir -p "$armbian_rootfs"/etc/nginx/
cp rootfs_overlay/etc/nginx/nginx.conf "$armbian_rootfs"/etc/nginx/

mkdir -p "$armbian_rootfs"/etc/hostapd/
cp rootfs_overlay/etc/hostapd.conf "$armbian_rootfs"/etc/hostapd/
cp rootfs_overlay/etc/dnsmasq.conf "$armbian_rootfs"/etc/
cp rootfs_overlay/etc/ep-rules.nft "$armbian_rootfs"/etc/

mkdir -p "$armbian_rootfs"/var/www/
cp rootfs_overlay/var/www/index.html "$armbian_rootfs"/boot/bh/

cp package/blackhat/src/evil_portal.py "$armbian_rootfs"/usr/local/bin/evil_portal

# Add additional packages
mkdir -p "armbian/config/cli/${os_release}/main"
PKG_CONF="armbian/config/cli/${os_release}/main/packages.additional"
cat >> "$PKG_CONF" <<'EOF'
usb-modeswitch
xorg
i3
feh
vim
cmake
libicu-dev
python3-pip
EOF

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
    RELEASE=${os_release}

echo ************ Built Ubuntu Image ************
echo "sudo dd if=armbian/output/images/<built-image>.img of=/dev/sdd bs=4M conv=fsync status=progress"
echo ********************************************
