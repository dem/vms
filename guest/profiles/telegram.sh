#!/bin/bash
set -e

# Telegram profile: GUI base + telegram-desktop auto-start.
# Runs inside VM via serial console.
# Invoked by commands/create.sh as: /vms/profiles/telegram.sh <username>

vm_user="${1:?username required}"
vm_home="/home/$vm_user"

marker=/etc/vms-profiles/telegram
if [[ -f "$marker" ]]; then
    echo "=== telegram profile already applied, skipping ==="
    exit 0
fi

# Apply GUI base (installs i3/X11/spice-vdagent and drops i3 config).
# gui.sh is idempotent — it self-skips if already applied.
bash /vms/profiles/gui.sh "$vm_user"

echo "=== Installing Telegram ==="
pacman -S --noconfirm --needed telegram-desktop

# Claim autostart slot only if no other non-gui profile claimed it first.
# Iterates /etc/vms-profiles and skips gui (the base) and telegram (self).
# If any other profile marker exists, another profile got here first and
# owns the autostart slot — leave it alone.
claim_autostart=1
if [[ -d /etc/vms-profiles ]]; then
    for m in /etc/vms-profiles/*; do
        [[ -f "$m" ]] || continue
        case "$(basename "$m")" in
            gui|telegram) ;;
            *) claim_autostart=0; break ;;
        esac
    done
fi

if [[ "$claim_autostart" == "1" ]]; then
    # Arch's telegram-desktop package ships the binary as /usr/bin/Telegram
    # (capital T), no telegram-desktop symlink — use the real binary name.
    # Leaves $mod+Return → alacritty intact as a fallback terminal.
    sed -i 's|^exec --no-startup-id alacritty$|exec --no-startup-id Telegram|' \
        "$vm_home/.config/i3/config"
fi

mkdir -p /etc/vms-profiles
touch "$marker"

echo "=== Telegram profile applied ==="
