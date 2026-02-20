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
    echo -n "Enter root password (default: vm): "
    read -s root_pass
    echo
    root_pass="${root_pass:-vm}"
    openssl passwd -6 "$root_pass" > "$root_passwd"
    chmod 600 "$root_passwd"
    info "env/root_passwd created"
fi

if [[ ! -f "$user_passwd" ]]; then
    echo -n "Enter user password (default: vm): "
    read -s user_pass
    echo
    user_pass="${user_pass:-vm}"
    openssl passwd -6 "$user_pass" > "$user_passwd"
    chmod 600 "$user_passwd"
    info "env/user_passwd created"
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
if ! grep -q 'LIBVIRT_DEFAULT_URI' "$HOME/.bashrc" 2>/dev/null; then
    step "Adding LIBVIRT_DEFAULT_URI to ~/.bashrc" setup_libvirt_uri
fi

info "Bootstrap complete."
echo ""
echo "NOTE: Log out and back in for group changes to take effect."
echo ""
echo "Next: vms create <name>"
