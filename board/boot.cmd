setenv bootargs console=ttyS0,115200 root=/dev/mmcblk1p2 rootwait panic=10 ${extra}
ext4load mmc 0:2 0x49000000 /boot/${fdtfile}
ext4load mmc 0:2 0x46000000 /boot/zImage
env set fdt_high ffffffff
bootz 0x46000000 - 0x49000000
