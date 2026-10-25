#!/bin/sh
# Pick which session tty1 starts on the next boot: plasma (default) or gamescope.
# Going gamescope -> desktop live leaves the HDMI bridge black, so this takes effect
# after a reboot (re-run the jailbreak + Linux loader afterwards).
s=${1:-plasma}
case "$s" in plasma|gamescope) ;; *) echo "usage: $0 [plasma|gamescope]"; exit 1 ;; esac
mkdir -p "$HOME/.config"
echo "$s" > "$HOME/.config/ps5-next-session"
echo "next boot will start: $s  (reboot to apply)"
