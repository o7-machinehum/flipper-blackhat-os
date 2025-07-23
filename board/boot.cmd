setenv finduuid "part uuid mmc 0:2 uuid"
run finduuid

ext4load mmc 0:2 0x46000000 /boot/zImage
ext4load mmc 0:2 0x49000000 /boot/${fdtfile}

fatload mmc 0:1 ${loadaddr} cmdline.txt
env import -t ${loadaddr} ${filesize}
env set bootargs ${bootargs} root=PARTUUID=${uuid}

env set fdt_high ffffffff
bootz 0x46000000 - 0x49000000
