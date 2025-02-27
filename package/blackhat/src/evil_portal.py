#!/usr/bin/python

from flask import Flask, jsonify, request

app = Flask(__name__)

@app.route('/api/hello', methods=['GET'])
def hello():
    return jsonify(message="Hello from Flask!")

@app.route('/api/echo', methods=['POST'])
def echo():
    data = request.get_json()
    return jsonify(received=data)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
