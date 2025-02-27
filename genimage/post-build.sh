#!/bin/sh

# this ... ???
cp $BINARIES_DIR/boot.scr $TARGET_DIR/boot/boot.scr

mkdir $BINARIES_DIR 2>/dev/null
cp $CONFIG_DIR/../genimage/readme.txt $BINARIES_DIR/
cp $CONFIG_DIR/../package/blackhat/src/blackhat.conf $BINARIES_DIR/

rm -f $TARGET_DIR/etc/init.d/S50dropbear
rm -f $TARGET_DIR/etc/init.d/S50apache
rm -f $TARGET_DIR/etc/init.d/S35iptables
rm -f $TARGET_DIR/etc/init.d/S40network
rm -f $TARGET_DIR/etc/init.d/S80dnsmasq
