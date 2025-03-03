#!/usr/bin/python

from flask import Flask, jsonify, request
import os

ap_nic = None
inet_nic = None

app = Flask(__name__)

@app.route('/api/hello', methods=['GET'])
def hello():
    ip = request.headers.get('X-Forwarded-For', request.remote_addr)
    cmd = f"nft add rule ip nat postrouting oifname \"{inet_nic}\" ip saddr {ip} masquerade"
    print(cmd)
    os.system(cmd)
    return jsonify(message="Hello from Flask!")

@app.route('/api/echo', methods=['POST'])
def echo():
    data = request.get_json()
    return jsonify(received=data)

def fread(fname):
    with open(fname) as f:
        return f.read().strip("\n")

if __name__ == '__main__':
    ap_nic = fread("/run/ap_nic")
    inet_nic = fread("/run/inet_nic")
    app.run(host='0.0.0.0', port=8080)
