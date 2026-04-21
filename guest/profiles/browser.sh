#!/bin/bash
set -e

# Browser profile: GUI base + chromium + firefox.
# Runs inside VM via serial console.
# Invoked as: /vms/profiles/browser.sh <username>

vm_user="${1:?username required}"
vm_home="/home/$vm_user"

marker=/etc/vms-profiles/browser
if [[ -f "$marker" ]]; then
    echo "=== browser profile already applied, skipping ==="
    exit 0
fi

# Apply GUI base (idempotent — self-skips if already applied).
bash /vms/profiles/gui.sh "$vm_user"

echo "=== Installing browsers ==="
pacman -S --noconfirm --needed chromium firefox

# Claim autostart slot only if no other non-gui profile claimed it first.
claim_autostart=1
if [[ -d /etc/vms-profiles ]]; then
    for m in /etc/vms-profiles/*; do
        [[ -f "$m" ]] || continue
        case "$(basename "$m")" in
            gui|browser) ;;
            *) claim_autostart=0; break ;;
        esac
    done
fi

if [[ "$claim_autostart" == "1" ]]; then
    sed -i 's|^exec --no-startup-id alacritty$|exec --no-startup-id chromium|' \
        "$vm_home/.config/i3/config"
fi

mkdir -p /etc/vms-profiles
touch "$marker"

echo "=== Browser profile applied ==="
