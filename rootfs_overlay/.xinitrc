#!/bin/bash

rm -rf /.screen/*
kill -9 $(pidof screen) 2>/dev/null
xrandr -o right
source /.profile
exec xterm -maximized -e "screen -S gui"
