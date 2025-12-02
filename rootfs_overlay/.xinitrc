#!/bin/bash

rm -rf /.screen/*
kill -9 $(pidof screen) 2>/dev/null
xrandr -o inverted
source /.profile
exec xterm -maximized -e "screen -S gui"
