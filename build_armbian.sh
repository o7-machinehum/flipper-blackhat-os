#!/bin/bash
set -e
cd "$(dirname "$0")"

kver="edge" # Edge or current

cd armbian
git reset --hard
git clean -fd
cd ..

# rm -rf armbian/userpatches/
rsync -av armbian_config/userpatches/ armbian/userpatches/
rsync -av armbian_config/config/ armbian/config/

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

# Install packages needed for bh scripts
install -D package/blackhat/src/blackhat.sh armbian/userpatches/overlay/usr/local/bin/bh
install -D package/blackhat/src/evil_portal.py armbian/userpatches/overlay/usr/local/bin/
install -D package/blackhat/src/telegram.py armbian/userpatches/overlay/usr/local/bin/
install -D -m 0644 package/blackhat/src/blackhat.conf armbian/userpatches/overlay/boot/bh/blackhat.conf

mkdir -p armbian/userpatches/overlay/boot/bh/scripts
cp -a package/blackhat/scripts/. armbian/userpatches/overlay/boot/bh/scripts/

# Install the init script
install -D rootfs_overlay/etc/init.d/S51bh_init armbian/userpatches/overlay/usr/local/bin/bh_init

# Add additional packages
PKG_CONF="armbian/config/cli/trixie/main/packages.additional"
echo usb-modeswitch >> $PKG_CONF

cd armbian

./compile.sh build \
    BOARD=flipper-blackhat \
    BRANCH=${kver} \
    BUILD_MINIMAL=no \
    KERNEL_CONFIGURE=no \
    ENABLE_EXTENSIONS="kali" \
    KEEP_ORIGINAL_OS_RELEASE=yes \
    RELEASE=forky

echo ************ Built Image ************
echo "sudo dd if=armbian/output/images/Armbian-unofficial_26.02.0-trunk_Flipper-blackhat_forky_edge_6.16.8-kali.img of=/dev/sdd bs=4M conv=fsync status=progress"
echo *************************************
