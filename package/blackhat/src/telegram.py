# @BotFather
# /newbot
# https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates

import re
import requests

class Telegram:
    def __init__(self, path):
        with open(path, "r") as f:
            cfg = f.read()

        self.bot_token = ""
        self.chat_id = ""

        for line in cfg.split("\n"):
            if "TELEGRAM_BOT_TOKEN" in line:
                self.bot_token = re.search(r"'(.*?)'", line).group(1)
            if "TELEGRAM_CHAT_ID" in line:
                self.chat_id = re.search(r"'(.*?)'", line).group(1)

    def send(self, msg):
        if self.bot_token == "" or self.chat_id == "":
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
