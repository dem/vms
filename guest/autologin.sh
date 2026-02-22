#!/bin/bash
set -e

# Manage autologin for serial console (root) and tty1 (user)
# Usage: autologin.sh on|off root|user

action="${1:?usage: autologin.sh on|off root|user}"
target="${2:?usage: autologin.sh on|off root|user}"
DESTDIR="${DESTDIR:-}"

case "$target" in
    root)
        unit="serial-getty@ttyS0.service"
        dropin_dir="$DESTDIR/etc/systemd/system/$unit.d"
        dropin="$dropin_dir/autologin.conf"
        login_user="root"
        ;;
    user)
        unit="getty@tty1.service"
        dropin_dir="$DESTDIR/etc/systemd/system/$unit.d"
        dropin="$dropin_dir/autologin.conf"
        login_user=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
        [[ -z "$login_user" ]] && { echo "No regular user found"; exit 1; }
        ;;
    *) echo "Unknown target: $target (use root or user)"; exit 1 ;;
esac

case "$action" in
    on)
        mkdir -p "$dropin_dir"
        cat > "$dropin" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin $login_user %I \$TERM
EOF
        ;;
    off)
        rm -f "$dropin"
        rmdir "$dropin_dir" 2>/dev/null || true
        ;;
    *) echo "Unknown action: $action (use on or off)"; exit 1 ;;
esac

systemctl daemon-reload
