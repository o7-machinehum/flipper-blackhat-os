#!/bin/bash

rmmod panel_sitronix_st7701
modprobe panel_sitronix_st7701 \
    g_hsync_start=520 \
    g_hsync_end=580 \
    g_htotal=597 \
    g_vsync_start=520 \
    g_vsync_end=580 \
    g_vtotal=597

echo -e '\033c' > /dev/tty0
echo HHHH >/dev/tty0
