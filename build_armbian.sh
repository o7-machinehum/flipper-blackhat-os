#!/bin/bash
set -e
cd "$(dirname "$0")"

cd armbian
git reset --hard
git clean -fd
cd ..

rm -rf armbian/userpatches/overlay/
rsync -av armbian_config/userpatches/ armbian/userpatches/
rsync -av armbian_config/config/ armbian/config/

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
    BRANCH=current \
    BUILD_MINIMAL=no \
    KERNEL_CONFIGURE=no \
    RELEASE=trixie

# sudo dd if=output/images/Armbian-unofficial_26.02.0-trunk_Flipper-blackhat_trixie_current_6.12.58.img of=/dev/sda

echo ************ Built Image ************
echo sudo dd if=armbian/output/images/Armbian-unofficial_26.02.0-trunk_Flipper-blackhat_trixie_current_6.12.58.img of=/dev/sdX
echo *************************************
