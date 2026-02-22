# vms bootstrap [-v]

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose) VMS_VERBOSE=1; shift ;;
        -*) die "unknown option: $1" ;;
        *) die "unexpected argument: $1" ;;
    esac
done

step "Installing host dependencies" \
    sudo pacman -S --needed --noconfirm \
    qemu-desktop \
    libvirt \
    virt-install \
    virt-viewer \
    dnsmasq \
    edk2-ovmf \
    expect

step "Enabling libvirtd" \
    sudo systemctl enable --now libvirtd

setup_network() {
    # Find a free 192.168.x.0/24 subnet (avoid conflicts with host networks)
    used_subnets=$(ip -4 addr show | grep -oP '192\.168\.\K[0-9]+' | sort -u)
    libvirt_subnet=""
    for i in $(seq 122 254); do
        if ! echo "$used_subnets" | grep -qx "$i"; then
            libvirt_subnet="$i"
            break
        fi
    done
    [[ -z "$libvirt_subnet" ]] && die "Could not find free 192.168.x.0/24 subnet"

    cat <<EOF | sudo tee /tmp/vms-default-net.xml >/dev/null
<network>
  <name>default</name>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.$libvirt_subnet.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.$libvirt_subnet.2' end='192.168.$libvirt_subnet.254'/>
    </dhcp>
  </ip>
</network>
EOF
    sudo virsh net-define /tmp/vms-default-net.xml
    sudo virsh net-start default
    sudo virsh net-autostart default
    sudo rm -f /tmp/vms-default-net.xml
}
if sudo virsh net-info default &>/dev/null; then
    info "Default network already exists, skipping"
else
    step "Setting up default network" setup_network
fi

step "Adding user to libvirt group" \
    sudo usermod -aG libvirt "$USER"

setup_directories() {
    sudo mkdir -p "$VMS_IMAGES"
    sudo mkdir -p "$VMS_ISO"
    sudo mkdir -p "$VMS_FILESYSTEMS/pkg/shared"
    sudo chown root:libvirt "$VMS_IMAGES"
    sudo chmod 775 "$VMS_IMAGES"
    sudo chown root:libvirt "$VMS_ISO"
    sudo chmod 775 "$VMS_ISO"
    sudo chown root:libvirt "$VMS_FILESYSTEMS"
    sudo chmod 775 "$VMS_FILESYSTEMS"
}
step "Creating directories" setup_directories

# Download Arch ISO if not present
if [[ ! -f "$VMS_ARCH_ISO" ]]; then
    step "Downloading Arch Linux ISO" \
        sudo curl -L -o "$VMS_ARCH_ISO" \
        https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso
fi

# Create passwd files if not exist
mkdir -p "$VMS_ROOT/env"
root_passwd="$VMS_ROOT/env/root_passwd"
user_passwd="$VMS_ROOT/env/user_passwd"

if [[ ! -f "$root_passwd" ]]; then
    echo -n "Enter VM root password: "
    read -s root_pass
    echo
    [[ -z "$root_pass" ]] && die "root password required"
    echo "$root_pass" | openssl passwd -6 -stdin > "$root_passwd"
    chmod 600 "$root_passwd"
    info "env/root_passwd created"
fi

if [[ ! -f "$user_passwd" ]]; then
    echo -n "Enter VM user password: "
    read -s user_pass
    echo
    [[ -z "$user_pass" ]] && die "user password required"
    echo "$user_pass" | openssl passwd -6 -stdin > "$user_passwd"
    chmod 600 "$user_passwd"
    info "env/user_passwd created"
fi

user_file="$VMS_ROOT/env/user"
uid_file="$VMS_ROOT/env/uid"
gid_file="$VMS_ROOT/env/gid"

if [[ ! -f "$user_file" ]]; then
    echo -n "Enter VM username (default: $USER): "
    read vm_user
    vm_user="${vm_user:-$USER}"
    echo "$vm_user" > "$user_file"
    info "env/user created ($vm_user)"
fi

vm_user="$(cat "$user_file")"
if [[ ! -f "$uid_file" ]] && id -u "$vm_user" &>/dev/null; then
    id -u "$vm_user" > "$uid_file"
    info "env/uid created ($(cat "$uid_file"))"
fi

if [[ ! -f "$gid_file" ]] && id -g "$vm_user" &>/dev/null; then
    id -g "$vm_user" > "$gid_file"
    info "env/gid created ($(cat "$gid_file"))"
fi

# Symlink vms to ~/.local/bin
install_symlink() {
    mkdir -p "$HOME/.local/bin"
    ln -s "$VMS_ROOT/vms" "$HOME/.local/bin/vms"
}
if [[ ! -L "$HOME/.local/bin/vms" ]]; then
    step "Symlinking vms to ~/.local/bin" install_symlink
fi

# Set LIBVIRT_DEFAULT_URI in ~/.bashrc
setup_libvirt_uri() {
    echo 'export LIBVIRT_DEFAULT_URI=qemu:///system' >> "$HOME/.bashrc"
}
bashrc_changed=0
if ! grep -q 'LIBVIRT_DEFAULT_URI' "$HOME/.bashrc" 2>/dev/null; then
    step "Adding LIBVIRT_DEFAULT_URI to ~/.bashrc" setup_libvirt_uri
    bashrc_changed=1
fi

info "Bootstrap complete."

needs_relogin=0
if ! id -nG "$USER" | grep -qw libvirt; then
    needs_relogin=1
fi
if [[ -z "${LIBVIRT_DEFAULT_URI:-}" ]]; then
    needs_relogin=1
fi

if [[ "$needs_relogin" == "1" ]]; then
    echo ""
    echo "NOTE: Log out and back in for group/env changes to take effect."
    if [[ -z "${LIBVIRT_DEFAULT_URI:-}" ]]; then
        echo "      Or run: export LIBVIRT_DEFAULT_URI=qemu:///system"
    fi
fi

echo ""
echo "Next: vms create <name>"
