#!/bin/bash
set -e

# GUI profile: i3 + X11 + SPICE integration
# Runs inside VM via serial console.
# Asset files live in /vms/profiles/gui/ (see sibling directory).
# Invoked by commands/create.sh as: /vms/profiles/gui.sh <username>

vm_user="${1:?username required}"
vm_home="/home/$vm_user"
[[ -d "$vm_home" ]] || { echo "Home directory $vm_home not found"; exit 1; }

marker=/etc/vms-profiles/gui
if [[ -f "$marker" ]]; then
    echo "=== gui profile already applied, skipping ==="
    exit 0
fi

echo "=== Installing GUI packages ==="
pacman -S --noconfirm --needed \
    xorg-server xorg-xinit xorg-xrandr xorg-xev \
    i3-wm i3status \
    alacritty \
    spice-vdagent

assets=/vms/profiles/gui
install -Dm644 "$assets/i3-config"          "$vm_home/.config/i3/config"
install -Dm755 "$assets/spice-autoresize.sh" "$vm_home/.config/i3/spice-autoresize.sh"
install -Dm644 "$assets/xinitrc"             "$vm_home/.xinitrc"
cat "$assets/bash_profile.append" >> "$vm_home/.bash_profile"

chown -R "$vm_user:$vm_user" "$vm_home/.config" "$vm_home/.xinitrc" "$vm_home/.bash_profile"

mkdir -p /etc/vms-profiles
touch "$marker"

echo "=== GUI profile applied ==="
