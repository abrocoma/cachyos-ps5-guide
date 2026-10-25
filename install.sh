#!/bin/sh
# Installs the display, Bluetooth, DualSense and zram fixes from this repo.
# Does NOT touch the kernel, the Wi-Fi driver or /boot/efi (see README).
# Usage: sudo ./install.sh
set -e
[ "$(id -u)" = 0 ] || { echo "run as root (sudo ./install.sh)"; exit 1; }
cd "$(dirname "$0")/files"

install -Dm755 usr/local/bin/dp-link-lock           /usr/local/bin/dp-link-lock
install -Dm644 etc/systemd/system/dp-link-lock.service   /etc/systemd/system/dp-link-lock.service
install -Dm644 etc/systemd/system/bt-connectable.service /etc/systemd/system/bt-connectable.service
install -Dm644 etc/modules-load.d/dualsense.conf    /etc/modules-load.d/dualsense.conf
if [ -e /etc/systemd/zram-generator.conf ]; then
    echo "skipping zram-generator.conf (already exists)"
else
    install -Dm644 etc/systemd/zram-generator.conf  /etc/systemd/zram-generator.conf
fi

# Boot ordering cycle fix (Step 3 in the README)
f=/etc/systemd/system/ps5-stage-firmware.service
if [ -f "$f" ] && ! grep -q '^DefaultDependencies=no' "$f"; then
    cp "$f" "$f.bak"
    sed -i '/^\[Unit\]/a DefaultDependencies=no' "$f"
    echo "patched $f (backup at $f.bak)"
fi

systemctl daemon-reload
systemctl enable dp-link-lock.service bluetooth.service bt-connectable.service
echo "done. Changes apply on the next boot."
