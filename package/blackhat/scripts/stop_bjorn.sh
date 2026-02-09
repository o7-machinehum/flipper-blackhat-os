#!/bin/bash

kill $(pidof python Bjorn.py)
dd if=/dev/zero of=/dev/fb0 bs=1M
