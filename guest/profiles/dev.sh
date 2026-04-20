#!/bin/bash
set -e

# Dev profile: GUI base + console development tools.
# Runs inside VM via serial console.
# Invoked by commands/create.sh as: /vms/profiles/dev.sh <username>

vm_user="${1:?username required}"
vm_home="/home/$vm_user"
[[ -d "$vm_home" ]] || { echo "Home directory $vm_home not found"; exit 1; }

marker=/etc/vms-profiles/dev
if [[ -f "$marker" ]]; then
    echo "=== dev profile already applied, skipping ==="
    exit 0
fi

# Apply GUI base (i3/X11/spice-vdagent + alacritty auto-start).
# gui.sh is idempotent — it self-skips if already applied.
bash /vms/profiles/gui.sh "$vm_user"

echo "=== Installing dev packages ==="
pacman -S --noconfirm --needed \
    bash-completion man-db man-pages \
    openssh curl wget \
    git vim neovim meld tmux \
    docker \
    base-devel \
    ripgrep fd jq yq miller htop tree bat git-delta glow

usermod -aG docker "$vm_user"

echo "=== Installing Claude Code ==="
sudo -u "$vm_user" bash -c 'curl -fsSL https://claude.ai/install.sh | bash'

# Add ~/.local/bin to PATH (claude installs there)
cat >> "$vm_home/.bash_profile" <<'EOF'
export PATH="$HOME/.local/bin:$PATH"
EOF
chown "$vm_user:$vm_user" "$vm_home/.bash_profile"

mkdir -p /etc/vms-profiles
touch "$marker"

echo "=== Dev profile applied ==="
