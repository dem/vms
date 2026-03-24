# vms clone <source> <name>

source="${1:-}"
name="${2:-}"

[[ -z "$source" || -z "$name" ]] && die "usage: vms clone <source> <name>"
validate_name "$name"

source_disk="$VMS_IMAGES/$source.qcow2"
disk="$VMS_IMAGES/$name.qcow2"
pkg_dir="$VMS_FILESYSTEMS/pkg/$name"

# Check source exists
if ! virsh dominfo "$source" &>/dev/null; then
    die "Source VM $source does not exist"
fi

if [[ ! -f "$source_disk" ]]; then
    die "Source disk $source_disk not found"
fi

# Check target doesn't exist
if virsh dominfo "$name" &>/dev/null; then
    die "VM $name already exists"
fi

if [[ -f "$disk" ]]; then
    die "Disk $disk already exists"
fi

# Cleanup on failure
cleanup_on_failure() {
    virsh destroy "$name" 2>/dev/null || true
    virsh undefine "$name" --nvram 2>/dev/null || true
    rm -f "$disk"
    sudo rm -rf "$pkg_dir"
    rm -f "$VMS_ROOT/env/vv/$name.vv"
}
trap cleanup_on_failure EXIT

# Allocate static SPICE port
spice_port=$(allocate_spice_port)

info "Cloning $source to $name"

# Create package cache directory
sudo mkdir -p "$pkg_dir"

# Full copy of disk
step "Copying disk" \
    cp "$source_disk" "$disk"

# Clone VM definition
step "Cloning VM definition" \
    virt-clone \
    --original "$source" \
    --name "$name" \
    --preserve-data \
    --file "$disk"

# Set static SPICE port
step "Setting SPICE port $spice_port" \
    virt-xml "$name" --edit --graphics port="$spice_port"

# Create viewer config
mkdir -p "$VMS_ROOT/env/vv"
sed "s/{{PORT}}/$spice_port/" "$VMS_ROOT/templates/viewer.vv" > "$VMS_ROOT/env/vv/$name.vv"

# Set hostname inside the VM
source "$VMS_ROOT/lib/vm.sh"

step "Starting VM" virsh start "$name"
step "Waiting for boot" wait_for_boot "$name"

set_hostname() {
    "$VMS_ROOT/lib/console.sh" run "$name" \
        "echo '$name' > /etc/hostname && sed -i 's/127\\.0\\.1\\.1.*/127.0.1.1   $name.localdomain $name/' /etc/hosts"
}
step "Setting hostname" set_hostname

step "Stopping VM" stop_vm "$name"

trap - EXIT
info "VM $name ready"
