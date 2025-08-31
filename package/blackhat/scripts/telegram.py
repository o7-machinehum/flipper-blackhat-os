#!/usr/bin/python

from telegram import Telegram
telegram = Telegram("/mnt/blackhat.conf")

if __name__ == '__main__':
    telegram.send("Hello From Telegram!")
