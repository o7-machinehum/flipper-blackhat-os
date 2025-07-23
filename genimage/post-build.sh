#!/bin/sh

# this ... ???
cp $BINARIES_DIR/boot.scr $TARGET_DIR/boot/boot.scr

mkdir $BINARIES_DIR 2>/dev/null
mkdir $BINARIES_DIR/scripts/ 2>/dev/null

cp $CONFIG_DIR/../genimage/readme.txt $BINARIES_DIR/
cp $CONFIG_DIR/../genimage/cmdline.txt $BINARIES_DIR/
cp $CONFIG_DIR/../rootfs_overlay/var/www/index.html $BINARIES_DIR/
cp $CONFIG_DIR/../package/blackhat/src/blackhat.conf $BINARIES_DIR/

# Loose hacking scripts
cp $CONFIG_DIR/../package/blackhat/scripts/hello.py $BINARIES_DIR/scripts/
cp $CONFIG_DIR/../package/blackhat/scripts/port_scan.py $BINARIES_DIR/scripts/
cp $CONFIG_DIR/../package/blackhat/scripts/data_thief.py $BINARIES_DIR/scripts/
cp $CONFIG_DIR/../package/blackhat/scripts/data_loader.py $BINARIES_DIR/scripts/

rm -f $TARGET_DIR/etc/init.d/S50dropbear
rm -f $TARGET_DIR/etc/init.d/S50nginx
rm -f $TARGET_DIR/etc/init.d/S35iptables
rm -f $TARGET_DIR/etc/init.d/S40network
rm -f $TARGET_DIR/etc/init.d/S80dnsmasq
