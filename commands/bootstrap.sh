# vms bootstrap

info "Installing host dependencies..."
echo "[TODO] sudo pacman -S --needed qemu-desktop libvirt virt-install virt-viewer dnsmasq edk2-ovmf"

info "Enabling libvirtd..."
echo "[TODO] sudo systemctl enable --now libvirtd"

info "Adding user to libvirt group..."
echo "[TODO] sudo usermod -aG libvirt $USER"

info "Creating directories..."
echo "[TODO] sudo mkdir -p /var/lib/libvirt/{images,iso,filesystems/pkg/shared}"

info "Bootstrap complete."
