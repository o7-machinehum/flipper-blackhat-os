#!/usr/bin/python

import os
from flask import Flask, jsonify, request

app = Flask(__name__)

@app.route('/api/username', methods=['POST'])
def credz():
    data = request.get_json()
    client_ip = request.headers.get('X-Real-IP', request.remote_addr)

    print(f"{data}: {client_ip}")

    print("Restarting dnsmasq")
    cmd = "kill -9 $(pidof dnsmasq)"
    os.system(cmd)

    cmd = "nft add element ip nat allowed_ips { "
    cmd += client_ip
    cmd += " }"

    os.system(cmd)

    return jsonify(received=data)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
