setenv finduuid "part uuid mmc 0:2 uuid"
run finduuid
setenv bootargs console=ttyS0,115200 root=PARTUUID=${uuid} rootwait panic=10 fbcon=rotate:1 ${extra}
ext4load mmc 0:2 0x49000000 /boot/${fdtfile}
ext4load mmc 0:2 0x46000000 /boot/zImage
env set fdt_high ffffffff
bootz 0x46000000 - 0x49000000
