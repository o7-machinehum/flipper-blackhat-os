# @BotFather
# /newbot
# https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates

import os
import requests

class Telegram:
    def __init__(self, path):
        with open(path) as f:
            for line in f:
                if line.startswith("export"):
                    key_value = line.strip().split("export ")[1]
                    key, value = key_value.split("=", 1)
                    os.environ[key] = value.strip("'")

        try:
            self.bot_token = os.environ["TELEGRAM_BOT_TOKEN"]
            self.chat_id = os.environ["TELEGRAM_CHAT_ID"]
        except KeyError:
            self.bot_token = ""
            self.chat_id = ""

    def send(self, msg):
        if self.bot_token == "" or self.chat_id == "":
            print("Empty bot token or chat_id. Check /mnt/blackhat.conf")
            return

        url = f'https://api.telegram.org/bot{self.bot_token}/sendMessage'
        payload = {
            'chat_id': self.chat_id,
            'text': msg
        }
        requests.post(url, data=payload, timeout=5.0)

if __name__ == "__main__":
    telegram = Telegram("blackhat.conf")
    telegram.send("Hello")
