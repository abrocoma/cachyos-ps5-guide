#!/bin/sh
# Installs the fixes from this repo (see README).
# Always: black screen lock, DualSense reconnect, zram, boot-order fix, Chrome flags.
# Menu: fan + boost, Wi-Fi driver, DNS fix, boot to desktop (shows what's already installed).
# Does NOT touch the kernel or /boot/efi (section 11).
# Usage: sudo ./install.sh        (sudo ./install.sh -y installs every extra not yet installed)
set -e
[ "$(id -u)" = 0 ] || { echo "run as root (sudo ./install.sh)"; exit 1; }
REPO=$(cd "$(dirname "$0")" && pwd)
USR=${SUDO_USER:-steam}
UHOME=$(getent passwd "$USR" | cut -d: -f6)
YES=0; [ "$1" = "-y" ] && YES=1

online() { curl -fsS -m 5 -o /dev/null https://github.com; }
clone() {  # clone <url> -> prints the checkout dir
    d=$(mktemp -d)
    git clone -q --depth 1 "$1" "$d/src" && echo "$d/src"
}
put() {  # put <mode> <src> <dst> <label>
    if cmp -s "$2" "$3"; then echo "  $4: already installed"
    else install -Dm"$1" "$2" "$3"; echo "  $4: installed"; fi
}

# --- status of the extras
has_fan()     { systemctl is-enabled -q ps5fan 2>/dev/null && systemctl is-enabled -q ps5boost 2>/dev/null; }
has_wifi()    { modinfo -k "$(uname -r)" moal >/dev/null 2>&1; }
has_dns() {
    n=0
    for c in $(nmcli -t -f UUID,TYPE con show | grep -E ':(802-3-ethernet|802-11-wireless)$' | cut -d: -f1); do
        nmcli -g ipv4.dns con show "$c" | grep -q '1\.1\.1\.1' || return 1
        n=1
    done
    [ $n = 1 ]
}
has_desktop() { [ "$(cat "$UHOME/.config/ps5-next-session" 2>/dev/null)" = plasma ]; }

# --- pick the extras: menu, or yes/no questions without whiptail
EXTRAS="fan wifi dns desktop"
label() { case $1 in
    fan) echo "Fan + boost control" ;; wifi) echo "Wi-Fi driver" ;;
    dns) echo "Faster internet loading (Cloudflare DNS)" ;; desktop) echo "Skip Gamescope, boot to desktop" ;; esac; }
note() { case $1 in
    fan) echo "needs internet" ;; wifi) echo "needs internet, a few minutes" ;;
    dns) echo "sets 1.1.1.1 on wired + Wi-Fi" ;; desktop) echo "instead of Gaming Mode" ;; esac; }
status() { if "has_$1"; then echo "installed"; else note "$1"; fi; }

# --- status of the core fixes (always installed)
F=$REPO/files
core_dp()     { cmp -s "$F/usr/local/bin/dp-link-lock" /usr/local/bin/dp-link-lock &&
                cmp -s "$F/etc/systemd/system/dp-link-lock.service" /etc/systemd/system/dp-link-lock.service; }
core_ds()     { cmp -s "$F/etc/systemd/system/bt-connectable.service" /etc/systemd/system/bt-connectable.service &&
                cmp -s "$F/etc/modules-load.d/dualsense.conf" /etc/modules-load.d/dualsense.conf; }
core_zram()   { [ -e /etc/systemd/zram-generator.conf ]; }
core_boot()   { f=/etc/systemd/system/ps5-stage-firmware.service; [ ! -f "$f" ] || grep -q '^DefaultDependencies=no' "$f"; }
core_chrome() { [ -e "$UHOME/.config/chrome-flags.conf" ]; }
core_list() {  # core_list <done-text> -> one line per core fix
    for c in "dp:Black screen lock" "ds:DualSense reconnect" "zram:zram swap" \
             "boot:Boot-order fix" "chrome:Chrome video flags"; do
        if "core_${c%%:*}"; then st=$1; else st="will be installed"; fi
        printf '  %-38s %s\\n' "${c#*:}" "$st"
    done
}

HINT="Space: tick/untick   Enter: install   Esc: cancel"
GUIDE="https://github.com/abrocoma/cachyos-ps5-guide"
SEP=$(printf "%76s" "" | tr " " -)
summary() {  # one line under the core fixes
    for c in dp ds zram boot chrome; do "core_$c" || { echo "Missing core fixes will be installed."; return; }; done
    echo "Core fixes already installed."
}

# dark themes (both tools default to light blue); a user's own DIALOGRC / NEWT_COLORS wins
if [ -z "$DIALOGRC" ]; then
    DIALOGRC=$(mktemp)
    cat > "$DIALOGRC" <<'EOF'
use_shadow = OFF
use_colors = ON
screen_color = (WHITE,BLACK,OFF)
shadow_color = (BLACK,BLACK,OFF)
dialog_color = (WHITE,BLACK,OFF)
title_color = (WHITE,BLACK,ON)
border_color = (WHITE,BLACK,OFF)
border2_color = (WHITE,BLACK,OFF)
button_active_color = (YELLOW,BLACK,ON)
button_inactive_color = (WHITE,BLACK,OFF)
button_key_active_color = (YELLOW,BLACK,ON)
button_key_inactive_color = (WHITE,BLACK,OFF)
button_label_active_color = (YELLOW,BLACK,ON)
button_label_inactive_color = (WHITE,BLACK,OFF)
menubox_color = (WHITE,BLACK,OFF)
menubox_border_color = (WHITE,BLACK,OFF)
menubox_border2_color = (WHITE,BLACK,OFF)
item_color = (WHITE,BLACK,OFF)
item_selected_color = (YELLOW,BLACK,ON)
tag_color = (WHITE,BLACK,OFF)
tag_selected_color = (YELLOW,BLACK,ON)
tag_key_color = (WHITE,BLACK,OFF)
tag_key_selected_color = (YELLOW,BLACK,ON)
check_color = (WHITE,BLACK,OFF)
check_selected_color = (YELLOW,BLACK,ON)
uarrow_color = (WHITE,BLACK,OFF)
darrow_color = (WHITE,BLACK,OFF)
itemhelp_color = (WHITE,BLACK,OFF)
position_indicator_color = (WHITE,BLACK,OFF)
EOF
fi
export DIALOGRC
: "${NEWT_COLORS:=root=lightgray,black window=lightgray,black border=gray,black shadow=,black title=white,black textbox=lightgray,black listbox=lightgray,black actlistbox=white,gray sellistbox=lightgray,black actsellistbox=white,gray checkbox=lightgray,black actcheckbox=white,gray button=lightgray,black actbutton=black,lightgray compactbutton=lightgray,black helpline=lightgray,black roottext=lightgray,black}"
export NEWT_COLORS

PICK=
if [ $YES = 1 ]; then
    for e in $EXTRAS; do "has_$e" || PICK="$PICK $e"; done
elif command -v dialog >/dev/null && [ -t 0 ]; then
    # dialog can colour words: "already installed" in green
    set --
    for e in $EXTRAS; do
        if "has_$e"; then on=off; st='\Z2\Zbinstalled\Zn'; else on=on; st=$(note "$e"); fi
        set -- "$@" "$e" "$(printf '%-42s' "$(label "$e")")($st)" "$on"
    done
    CORE=$(core_list '\Z2\Zbinstalled\Zn')
    printf '\033[?25l'  # hide the cursor, it sits on the first letter of OK
    PICK=$(dialog --colors --no-collapse --title " CachyOS on PS5 installer " --separate-output --checklist \
        "\n                \Zu$GUIDE\Zn\n\n\ZbCore fixes\Zn (included):\n$CORE\n\Z2\Zb$(summary)\Zn\n$SEP\n\ZbExtras\Zn (install or reinstall):\n\Z4\Zb$HINT\Zn" \
        24 80 4 "$@" 3>&1 1>&2 2>&3) || { printf '\033[?25h'; clear; echo "cancelled, nothing changed"; exit 0; }
    printf '\033[?25h'; clear
elif command -v whiptail >/dev/null && [ -t 0 ]; then
    set --
    for e in $EXTRAS; do
        if "has_$e"; then on=OFF; else on=ON; fi
        set -- "$@" "$e" "$(printf '%-42s(%s)' "$(label "$e")" "$(status "$e")")" "$on"
    done
    CORE=$(core_list "installed")
    PICK=$(whiptail --title "CachyOS on PS5 installer" --separate-output --checklist \
        "\n               $GUIDE\n\nCore fixes (included):\n$CORE\n$(summary)\n$SEP\nExtras (install or reinstall):\n$HINT" \
        29 78 4 "$@" 3>&1 1>&2 2>&3) || { echo "cancelled, nothing changed"; exit 0; }
else
    echo; echo "$GUIDE"; echo
    echo "Core fixes (included):"; printf "%b" "$(core_list "installed")"; echo; summary; echo "$SEP"; echo "Extras (install or reinstall):"
    for e in $EXTRAS; do
        printf '%s (%s)? [Y/n] ' "$(label "$e")" "$(status "$e")"
        read -r a </dev/tty || a=
        case "$a" in [nN]*) ;; *) PICK="$PICK $e" ;; esac
    done
fi
picked() { echo " $PICK " | tr '\n' ' ' | grep -q " $1 "; }

echo "== Core fixes"
cd "$REPO/files"
put 755 usr/local/bin/dp-link-lock /usr/local/bin/dp-link-lock "black screen lock (script)"
put 644 etc/systemd/system/dp-link-lock.service /etc/systemd/system/dp-link-lock.service "black screen lock (service)"
put 644 etc/systemd/system/bt-connectable.service /etc/systemd/system/bt-connectable.service "DualSense reconnect"
put 644 etc/modules-load.d/dualsense.conf /etc/modules-load.d/dualsense.conf "DualSense modules"
if [ -e /etc/systemd/zram-generator.conf ]; then
    echo "  zram: already installed"
else
    install -Dm644 etc/systemd/zram-generator.conf /etc/systemd/zram-generator.conf; echo "  zram: installed"
fi

# Boot ordering cycle fix (section 12)
f=/etc/systemd/system/ps5-stage-firmware.service
if [ ! -f "$f" ]; then
    echo "  boot-order fix: not needed (no ps5-stage-firmware.service)"
elif grep -q '^DefaultDependencies=no' "$f"; then
    echo "  boot-order fix: already installed"
else
    cp "$f" "$f.bak"
    sed -i '/^\[Unit\]/a DefaultDependencies=no' "$f"
    echo "  boot-order fix: installed (backup at $f.bak)"
fi

systemctl daemon-reload
systemctl enable -q dp-link-lock.service bluetooth.service bt-connectable.service

# Chrome hardware video decode (section 10)
f=$UHOME/.config/chrome-flags.conf
if [ -e "$f" ]; then
    echo "  Chrome video flags: already installed"
else
    install -Dm644 -o "$USR" -g "$USR" home/steam/.config/chrome-flags.conf "$f"; echo "  Chrome video flags: installed"
fi

[ -n "$(echo $PICK)" ] && echo "== Extras"

if picked fan; then
    if online; then
        d=$(clone https://github.com/ps5-linux/ps5-linux-tools)
        (cd "$d" && ./install.sh)
        systemctl enable --now ps5fan ps5boost
        echo "  fan + boost: installed"
    else
        echo "  fan + boost: no internet, skipped. See section 9."
    fi
fi

if picked wifi; then
    if online; then
        d=$(clone https://github.com/ps5-linux/ps5-linux-mwifiex)
        # freeze fix (patches/0004); skipped with a warning if upstream changed too much
        fix=$REPO/patches/0004-mwifiex-txpower-bounded-wait.patch
        if git -C "$d" apply --check "$fix" 2>/dev/null; then
            git -C "$d" apply "$fix"; echo "  Wi-Fi driver: freeze fix applied"
        else
            echo "  Wi-Fi driver: freeze fix doesn't apply to this driver version, installing without it"
        fi
        (cd "$d" && ./install.sh)
        nmcli radio wifi on
        echo "  Wi-Fi driver: installed. Re-run this after every kernel update."
    else
        echo "  Wi-Fi driver: no internet, skipped. See section 6."
    fi
fi

if picked dns; then
    nmcli -t -f UUID,TYPE,NAME con show | grep -E '^[^:]+:(802-3-ethernet|802-11-wireless):' |
    while IFS=: read -r uuid type name; do
        nmcli con mod "$uuid" ipv4.dns "1.1.1.1 1.0.0.1" ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes
        echo "  DNS: set on $name"
    done
    nmcli -t -f DEVICE,TYPE,STATE device | while IFS=: read -r dev type state; do
        case "$type:$state" in ethernet:connected|wifi:connected) nmcli device reapply "$dev" >/dev/null ;; esac
    done
fi

if picked desktop; then
    install -d -o "$USR" -g "$USR" "$UHOME/.config"
    echo plasma > "$UHOME/.config/ps5-next-session"
    chown "$USR:$USR" "$UHOME/.config/ps5-next-session"
    echo "  boot to desktop: set"
fi

echo "done. Reboot (and run the exploit + loader again) to apply everything."
