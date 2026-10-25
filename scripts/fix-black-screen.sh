#!/bin/sh
# Bring the picture back after a black screen, without rebooting.
# Run over SSH (or from a TTY): sudo ./fix-black-screen.sh
D=/sys/kernel/debug/dri/0/DP-1
[ "$(id -u)" = 0 ] || { echo "run as root (sudo)"; exit 1; }
mountpoint -q /sys/kernel/debug || mount -t debugfs none /sys/kernel/debug

echo "1/3 switching TTY away and back (forces a mode set)"
chvt 2; sleep 3; chvt 1; sleep 3

echo "2/3 re-locking DP-1 to 4 lanes HBR3"
echo "4 0x1e" > "$D/link_settings"

echo "3/3 forcing a hotplug (twice, the first one is often not enough)"
echo 1 > "$D/trigger_hotplug"; sleep 8
echo 1 > "$D/trigger_hotplug"

echo "done. If it's still black, switch the TV input away and back."
