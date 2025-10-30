#!/bin/bash

cd /root/bjorn/
chmod +x kill_port_8000.sh
./kill_port_8000.sh
python Bjorn.py > /dev/null 2>&1 &
echo Bjorn Started!
