#!/usr/bin/python

import os
from flask import Flask, jsonify, request

app = Flask(__name__)

@app.route('/api/username', methods=['POST'])
def credz():
    data = request.get_json()
    print(data)

    print("Restarting dnsmasq")
    cmd = "kill -9 $(pidof dnsmasq)"
    os.system(cmd)

    with open("/run/inet_nic") as f:
        nic = f.read().strip("\n")

    cmd = f"nft add rule ip nat postrouting oifname {nic} masquerade"
    os.system(cmd)

    cmd = "dnsmasq -C /etc/dnsmasq-allow.conf"
    os.system(cmd)

    return jsonify(received=data)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
