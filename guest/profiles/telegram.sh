#!/bin/bash
set -e

# Telegram profile: GUI base + telegram-desktop auto-start.
# Runs inside VM via serial console.
# Invoked by commands/create.sh as: /vms/profiles/telegram.sh <username>

vm_user="${1:?username required}"
vm_home="/home/$vm_user"

# Apply GUI base (installs i3/X11/spice-vdagent and drops i3 config)
bash /vms/profiles/gui.sh "$vm_user"

echo "=== Installing Telegram ==="
pacman -S --noconfirm --needed telegram-desktop

# Replace the alacritty auto-start with Telegram.
# Arch's telegram-desktop package ships the binary as /usr/bin/Telegram (capital T),
# no telegram-desktop symlink — use the real binary name.
# Leaves $mod+Return → alacritty intact as a fallback terminal.
sed -i 's|^exec --no-startup-id alacritty$|exec --no-startup-id Telegram|' \
    "$vm_home/.config/i3/config"

echo "=== Telegram profile applied ==="
